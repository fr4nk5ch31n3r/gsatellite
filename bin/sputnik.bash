#!/bin/bash

#  sputnik.bash - gsatellite tool (runs and controls jobs)

:<<COPYRIGHT

Copyright (C) 2011, 2012, 2013 Frank Scheiner
Copyright (C) 2013, 2015, 2016, 2021 Frank Scheiner, HLRS, Universitaet Stuttgart

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

_sputnikVersion="0.4.0"

# see `/usr/include/sysexits.h`
readonly _exit_ok=0
readonly _exit_usage=64
readonly _exit_software=70

readonly _true=1
readonly _false=0

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
trap 'echo "($$) [sputnik] DEBUG: SIGINT received." >> "$__GLOBAL__sputnikLogFile"' SIGINT
trap 'echo "($$) [sputnik] DEBUG: SIGTERM received." >> "$__GLOBAL__sputnikLogFile"' SIGTERM

sputnik/signalJob()
{
	local _job="$1"
	local _signal="$2"

	echo "($$) [sputnik] DEBUG: /bin/kill -"$_signal" -"$_jobChildPid"" >> "$__GLOBAL__sputnikLogFile"

	#  NOTICE: There's a "-" in front of the PID. This results in signalling
	#+ the whole process group of sputnik. All sputnik processes should
	#+ ignore SIGINT and SIGTERM, but the children of the job child should react on
	#+ this.
        /bin/kill -"$_signal" -"$_jobChildPid" 1>> "$__GLOBAL__sputnikLogFile" 2>&1

	local _returnVal=$?

	echo "($$) [sputnik] DEBUG: _returnVal=\"$_returnVal\"" >> "$__GLOBAL__sputnikLogFile"

        if [[ "$_returnVal" == "0" ]]; then

                return 0
        else
                return 1
        fi
}


sputnik/holdJob() {
        #  Put a hold on a job
        #
        #  usage:
        #+ sputnik/holdJob job

        local _job="$1"

        local _jobTmpDir=$( dirname "$_job" )
        
        local _jobPid=$( cat "$_jobTmpDir/../job.pid" )

	#  this information is retrieved and stored in the job's directory by
	#+ the scheduler (gsatlc)
        #local _jobType=$( cat "$_jobTmpDir/../job.type" )

	local _holdSignal=$( jobTypes/getHoldSignal "$_job" )
	#local _holdSignal="SIGINT"
	
	echo "($$) [sputnik] DEBUG: /bin/kill -"$_holdSignal" -"$_jobChildPid"" >> "$__GLOBAL__sputnikLogFile"
	
	#  "hold" job
	#  NOTICE: There's a "-" in front of the PID. This results in signalling
	#+ the whole process group of sputnik. All sputnik processes should
	#+ ignore SIGINT, but the children of the job child should react on
	#+ this.
	#echo /bin/kill -"$_holdSignal" -"$$" >&2 #&>/dev/null
        /bin/kill -"$_holdSignal" -"$_jobChildPid" 1>> "$__GLOBAL__sputnikLogFile" 2>&1
        #/bin/kill -SIGINT -"$$"

	#wait

	local _returnVal=$?
	
	echo "($$) [sputnik] DEBUG: _returnVal=\"$_returnVal\"" >> "$__GLOBAL__sputnikLogFile"

        if [[ "$_returnVal" == "0" ]]; then
                return 0
        else
                return 1
        fi
}


#  reimplementation with if clauses, as this could allow to include
#+ functionality dynamically
processMsg() {
        local _message="$1"
        local _inbox="$2"

        local _command=""
        local _answerBox=""

        local _gsatlcHostName=$( cat "$_gsatBaseDir/gsatlcHostName" )
        local _gsatlcPid=$( cat "$_gsatBaseDir/gsatlcPid" )
        local _gsatlcMessageBox="$_MBOXES/$_gsatlcHostName/$_gsatlcPid.inbox"

        _command=$( echo "$_message" | cut -d ';' -f 1 )
        _answerBox=$( echo "$_message" | cut -d ';' -f 2 )

        #  special functionality
        if [[ "$_command" =~ '^WAKE UP$' ]]; then
                #echo "sputnik: awake!"
                return

	elif [[ "$_command" =~ ^JOB_CHILD_PID.* ]]; then

		echo "($$) [sputnik] DEBUG: _command=\"$_command\"" >> "$__GLOBAL__sputnikLogFile"
		# save PID of job child
		_jobChildPid=$( echo "$_command" | cut -d ' ' -f 2 )
		
		return

	elif [[ "$_command" =~ ^STARTED.* ]]; then

		#  command is "STARTED JOB"
	        local _gsatlcMessage="STARTED $__GLOBAL__jobId;$_inbox"

	        ipc/file/sendMsg "$_gsatlcMessageBox" "$_gsatlcMessage"

	        local _signal="SIGCONT"

	        #  wake gsatlc with signal forwarding
	        ipc/file/sigfwd/forwardSignal "$_gsatlcHostName" "$_gsatlcPid" "$_signal"

		local _returnValue="$?"

	        if [[ $_returnValue -eq 0 ]]; then
			return 0
		else
			return 1
	        fi

        elif [[ "$_command" =~ ^TERMINATED.* ]]; then
        	#  only do something if job is not held
                if [[ $_jobHeld -eq $_false ]]; then
                
                	#  command is "TERMINATED <EXIT_VALUE>"
                	local _jobExitValue=$( echo "$_command" | cut -d ' ' -f 2 )

		        local _gsatlcMessage="TERMINATED $__GLOBAL__jobId $_jobExitValue;$_inbox"

		        ipc/file/sendMsg "$_gsatlcMessageBox" "$_gsatlcMessage"
		        
		        local _signal="SIGCONT"

		        #  wake gsatlc with signal forwarding
		        ipc/file/sigfwd/forwardSignal "$_gsatlcHostName" "$_gsatlcPid" "$_signal"

			local _returnValue="$?"

		        if [[ $_returnValue -eq 0 ]]; then
		                exit 0
			else
		                exit 1
		        fi
		fi
		
		exit
		

        elif [[ "$_command" =~ ^HOLD$ ]]; then
                #  command is "HOLD"
                #  TODO:
                #+ Encapsulate "holding a job" in different libs depending on
                #+ the job type.

                #  Actually hold the job
                sputnik/holdJob "$_job"

                if [[ "$?" == "0" ]]; then
                        local _gsatlcMessage="OK;$_inbox"
                        _jobHeld=1
                else
                        local _gsatlcMessage="HOLD FAILED;$_inbox"
                fi

                ipc/file/sendMsg "$_answerBox" "$_gsatlcMessage"
                
                #  No wakeup needed, gsatlc is actively waiting for this answer
                #local _signal="SIGCONT"

                #  wake gsatlc with signal forwarding
                #ipc/file/sigfwd/forwardSignal "$_gsatlcHostName" "$_gsatlcPid" "$_signal"

                if [[ "$?" == "0" ]]; then
                        exit 0
                else
                        exit 1
                fi

	elif [[ "$_command" =~ ^SIGNAL.*$ ]]; then
                #  command is "SIGNAL <SIGNAL>"
		local _signal=$( echo "$_command" | cut -d ' ' -f 2 )

                #  Send signal to job
                sputnik/signalJob "$_job" "$_signal"

                if [[ "$?" == "0" ]]; then
                        local _gsatlcMessage="OK;$_inbox"
                else
                        local _gsatlcMessage="SIGNAL FAILED;$_inbox"
                fi

                ipc/file/sendMsg "$_answerBox" "$_gsatlcMessage"

                #  No wakeup needed, gsatlc is actively waiting for this answer
                #local _signal="SIGCONT"

                #  wake gsatlc with signal forwarding
                #ipc/file/sigfwd/forwardSignal "$_gsatlcHostName" "$_gsatlcPid" "$_signal"

                if [[ "$?" == "0" ]]; then
                        exit 0
                else
                        exit 1
                fi
        fi

        #  standard functionality for message processing
        ipc/file/msgproc/processMsg "$_message" "$_inbox"

        return
}

################################################################################

#  a gsatellite job is a shell script
_job="$1"
_jobDir="$2" #  e.g. "$_gscheduleJobsDir/$_jobId.d"
__GLOBAL__jobId="$3"

__GLOBAL__jobPidFile="$_jobDir/job.pid"

__GLOBAL__jobPid=""

__GLOBAL__sputnikLogFile="$_jobDir/sputnik.log"

touch "$__GLOBAL__sputnikLogFile"

_jobHeld=0

_wakeupChildPid=""
_jobChildPid=""

################################################################################

#if [[ ! -e "$_job" ]]; then
#	exit 1
#fi

_self="$$"

_inboxName="$_self.inbox"

_message=""

#  create inbox
_inbox=$( ipc/file/createMsgBox "$_inboxName" )

#  setup trap to stop children and remove inbox on exit
trap '/bin/kill "$_wakeupChildPid" &>/dev/null; ipc/file/removeLocalMsgBoxByName "$_inboxName"' EXIT

#  wake up regularly every 10 seconds
utils/wakeUp "$_self" "10" &

#  child's PID
_wakeupChildPid="$!"

#  start job (job child will send its PID in a message)
#sputnik/runJob "$_job" "$_self" "$_inbox" &

echo "($$) [sputnik] DEBUG: nohup setsid runJob "$_job" "$__GLOBAL__jobId" "$_self" "$_inbox" &"  >> "$__GLOBAL__sputnikLogFile"

# nohup needs a file/binary and does not work with funtions!
nohup setsid sputnikRunJob "$_job" "$__GLOBAL__jobId" "$_self" "$_inbox" &

echo "($$) [sputnik] DEBUG: Forked job child." >> "$__GLOBAL__sputnikLogFile"

#  child's PID
#_jobChildPid="$!"

#  save PID
echo "$_self" > "$_jobDir/sputnik.pid"

while [[ 1 ]]; do
        if ipc/file/messageAvailable "$_inbox"; then        
                _message=$( ipc/file/receiveMsg "$_inbox" )
                #  process message asynchronously (assumption was to speedup message
                #+ processing, but in reality the effect wasn't that impressive:
                #+ Processing 24 messages (from 24 concurrently running gsatlc, 12
                #+ gsatlc processes on each host) took about 1m30s for each host with
                #+ standard synchronous message processing and about 1m10s for each host
                #+ with asynchronous message processing.).
                #+
                #+ PROBLEM:
                #+ Stopping doesn't work anymore. It looks like the exit in processMsg()
                #+ is now done for the child and no longer for the father.
                #processMsg "$_message" &
                processMsg "$_message" "$_inbox"
        else
        	#  get job PID
        	if [[ "$__GLOBAL__jobPid" == "" ]]; then
			__GLOBAL__jobPid=$( cat "$__GLOBAL__jobPidFile" )
		fi
		
		if [[ "$__GLOBAL__jobPid" != "" ]]; then
			#  touch job PID file to indicate that job's still running
		        if kill -0 "$__GLOBAL__jobPid" &>/dev/null; then		        	
		        	touch -a "$__GLOBAL__jobPidFile"
		        fi
		fi
                
                #  pause execution
                #  If you need something, wake me up!
                /bin/kill -SIGSTOP "$_self"
        fi

done

exit

