#!/bin/bash

#  sputnikRunJob - gsatellite tool (runs jobs)

:<<COPYRIGHT

Copyright (C) 2011, 2012, 2013 Frank Scheiner
Copyright (C) 2013 Frank Scheiner, HLRS, Universitaet Stuttgart

The program is distributed under the terms of the GNU General Public License

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

COPYRIGHT

umask 0077

_DEBUG="0"

_program=$( basename "$0" )

_version="0.1.0"

readonly _exit_usage=64
readonly _exit_ok=0
readonly _exit_software=70

################################################################################

#  path to configuration files (prefer system paths!)
#  For native OS packages:
if [[ -e "/etc/gsatellite" ]]; then
        _configurationFilesPath="/etc/gsatellite"

#  For installation with "install.sh".
#sed#elif [[ -e "<PATH_TO_GSATELLITE>/etc" ]]; then
#sed#	_configurationFilesPath="<PATH_TO_GSATELLITE>/etc"

#  According to FHS 2.3, configuration files for packages located in "/opt" have
#+ to be placed here (if you use a provider super dir below "/opt" for the
#+ gtransfer files, please also use the same provider super dir below
#+ "/etc/opt").
#elif [[ -e "/etc/opt/<PROVIDER>/gsatellite" ]]; then
#	_configurationFilesPath="/etc/opt/<PROVIDER>/gsatellite"
elif [[ -e "/etc/opt/gsatellite" ]]; then
        _configurationFilesPath="/etc/opt/gsatellite"

# For git deploy, use $BASH_SOURCE
elif [[ -e "$( dirname $BASH_SOURCE )/../etc" ]]; then
	_configurationFilesPath="$( dirname $BASH_SOURCE )/../etc"

#  For user install in $HOME:
elif [[ -e "$HOME/.gsatellite" ]]; then
	_configurationFilesPath="$HOME/.gsatellite"
fi

_pathsConfigurationFile="$_configurationFilesPath/paths.conf"

#  include path config or fail with EX_SOFTWARE = 70, internal software error
#+ not related to OS
if ! . "$_pathsConfigurationFile"; then
	echo "($$) [$_program] E: Paths configuration file couldn't be read or is corrupted." 1>&2
	exit $_exit_software
fi

_gsatBaseDir=$HOME/.gsatellite
_gscheduleBaseDir="$_gsatBaseDir/gschedule"

################################################################################

#  child libs inherit parent lib functions
#. "$_LIB"/ipc.bashlib
#. "$_LIB"/ipc/file.bashlib
#. "$_LIB/ipc/file/sigfwd.bashlib"
#. "$_LIB/ipc/file/msgproc.bashlib"
#. "$_LIB/utils.bashlib"
#. "$_LIB/gschedule.bashlib"

#  include needed libaries
_neededLibraries=( "ipc/file/sigfwd.bashlib"
		   "ipc/file/msgproc.bashlib"
		   "utils.bashlib"
		   "gschedule.bashlib" )

for _library in "${_neededLibraries[@]}"; do

	if ! . "$_LIB"/"$_library"; then
		echo "($$) [$_program] E: Library \""$_LIB"/"$_library"\" couldn't be read or is corrupted." 1>&2
		exit $_exit_software
	fi
done


################################################################################

#  ignore SIGINT and SIGTERM
#trap 'echo "($$) [sputnik] DEBUG: SIGINT received." >> "$__GLOBAL__sputnikLogFile"' SIGINT
#trap 'echo "($$) [sputnik] DEBUG: SIGTERM received." >> "$__GLOBAL__sputnikLogFile"' SIGTERM

# It is important that the trap really does something (even if it's only a NOP),
# as otherwise this script does not reliably kill its job child.
trap ':' SIGINT
trap ':' SIGTERM


runJob() {
        #  run the gsatellite job and notify parent when it terminates.
        #
        #  usage:
        #+ sputnik/runJob job parentPid parentInbox

        local _job="$1"
        local _jobId="$2"
        local _parentPid="$3"
        local _parentInbox="$4"
        local _message=""

	########################################################################
	# notify parent of own PID (as runJob is started with `setsid` the
	# parent looses track of the child)
	local _self="$$"
	
	_message="JOB_CHILD_PID $_self;"

	ipc/file/sendMsg "$_parentInbox" "$_message"

        #  wakeup parent
        /bin/kill -SIGCONT $_parentPid &>/dev/null
	########################################################################

        local _jobTmpDir=$( dirname "$_job" )
        
        #  determine values for add. environment
	#local _jobId="$_jobId"
	local _jobDir=$( gschedule/getJobDir "$_jobId" )
	local _jobName=$( basename "$_job" )
	local _jobWorkDir="$_jobDir/jobtmp"
	local _home="$HOME"
	local _user="$USER"
	local _execHost=$( utils/getHostName )
	local _path="$PATH"

	########################################################################
	# Add per job type env variables
	local _perJobTypeEnvFile="${_jobDir}/perJobType.env"
	local _jobType=$( jobTypes/getJobType "$_job" )

	case $_jobType in

	# Use default GSI proxy credential
	gtransfer|tgftp)
		cat > "$_perJobTypeEnvFile" <<-EOF
		export X509_USER_PROXY="$HOME/.gsatellite/tmp/defaultGsiProxyCredential"
		EOF
		;;
	*)
		:
		;;
	esac
	########################################################################

	#echo "($$) [runJob] DEBUG: " 1>&2

        #  create additional environment
	local _environmentFile="${_jobDir}/${_gschedule_jobEnvFileName}"

	cat > "$_environmentFile" <<-EOF
	export GSAT_JOBNAME="$_jobName"
	export GSAT_O_WORKDIR="$_jobWorkDir"
	export GSAT_O_HOME="$_home"
	export GSAT_O_LOGNAME="$_user"
	export GSAT_O_JOBID="$_jobId"
	export GSAT_O_HOST="$_execHost"
	export GSAT_O_PATH="$_path"
	EOF

	# Add per job type environment
	if [[ -e "$_perJobTypeEnvFile" ]]; then
		cat "$_perJobTypeEnvFile" >> "$_environmentFile"
		rm "$_perJobTypeEnvFile"
	fi

	. "$_environmentFile"

	chmod +x "$_job"

        #  run job in the background to get its PID. We need its PID to be able
        #+ to interact with it with signals later.
        cd "$_jobTmpDir" && \
	$_job 1>"$_jobDir/job.stdout" 2>"$_jobDir/job.stderr" &

        local _jobPid="$!"

	#  record job start timestamp
	date +%s >> "$_jobDir/job.start"

        #  save job's PID
        echo "$_jobPid" > "$_jobDir/job.pid"

	_message="STARTED;"

	ipc/file/sendMsg "$_parentInbox" "$_message"

        #  wakeup parent
        /bin/kill -SIGCONT $_parentPid &>/dev/null

	# return false if `kill` failed?
        #if [[ "$?" != "0" ]]; then
	#	return 1
        #fi

        #  wait for the job to terminate
        wait "$_jobPid"

        local _jobExitValue="$?"

	#  record job stop timestamp
	date +%s >> "$_jobDir/job.stop"

	#  save job's exit value
	echo "$_jobExitValue" > "$_jobDir/job.exit"

        #  no answer from the parent needed, hence no inbox provided
        _message="TERMINATED $_jobExitValue;"

        ipc/file/sendMsg "$_parentInbox" "$_message"

        #  wakeup parent
        /bin/kill -SIGCONT $_parentPid &>/dev/null

        if [[ "$?" == "0" ]]; then
                return 0
        else
                return 1
        fi
}


runJob "$@"

