#!/bin/bash

#  gsatctl - gsatellite controller (user interface for gsatellite)

:<<COPYRIGHT

Copyright (C) 2012 Frank Scheiner

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

################################################################################

#  path to configuration files (prefer system paths!)
#  For native OS packages:
if [[ -e "/etc/gsatellite" ]]; then
        _gsatConfigurationFilesPath="/etc/gsatellite"

#  For installation with "install.sh".
#sed#elif [[ -e "<PATH_TO_GSATELLITE>/etc" ]]; then
#sed#	_gsatConfigurationFilesPath="<PATH_TO_GSATELLITE>/etc"

#  According to FHS 2.3, configuration files for packages located in "/opt" have
#+ to be placed here (if you use a provider super dir below "/opt" for the
#+ gtransfer files, please also use the same provider super dir below
#+ "/etc/opt").
#elif [[ -e "/etc/opt/<PROVIDER>/gsatellite" ]]; then
#	_gsatConfigurationFilesPath="/etc/opt/<PROVIDER>/gsatellite"
elif [[ -e "/etc/opt/gsatellite" ]]; then
        _gsatConfigurationFilesPath="/etc/opt/gsatellite"

#  For user install in $HOME:
elif [[ -e "$HOME/.gsatellite" ]]; then
        _gsatConfigurationFilesPath="$HOME/.gsatellite"
fi

_gsatPathsConfigurationFile="$_gsatConfigurationFilesPath/paths.conf"

#  include path config or fail with EX_SOFTWARE = 70, internal software error
#+ not related to OS
if ! . "$_gsatPathsConfigurationFile"; then
	echo "($_program) E: Paths configuration file couldn't be read or is corrupted." 1>&2
	exit 70
fi

################################################################################

#  include needed libaries
#. "$_LIB"/ipc.bashlib
#. "$_LIB"/ipc/file.bashlib

_neededLibraries=(

"ipc/file/sigfwd.bashlib"
"utils.bashlib"
"gsatlc.bashlib"

)

for _library in ${_neededLibraries[@]}; do

	if ! . "$_LIB"/"$_library"; then
		echo "($_program) E: Library \""$_LIB"/"$_library"\" couldn't be read or is corrupted." 1>&2
		exit 70
	fi
done

#. "$_LIB"/ipc/file/sigfwd.bashlib

#. "$_LIB"/utils.bashlib

#. "$_LIB"/gsatlc.bashlib

#. "$_LIB"/gschedule.bashlib

################################################################################

_gsatBaseDir=$HOME/.gsatellite
_gscheduleBaseDir="$_gsatBaseDir/gschedule"
_gsatctlVersion="0.1.0"

################################################################################

gsatctl/usageMsg() {

    cat <<-USAGE

usage: gsatctl [--help]
       gsatctl --qsub jobFile
       gsatctl --qhold jobId
       gsatctl --qrls jobId
       gsatctl --qdel jobId
       gsatctl --qstat [jobState]

--help gives more information

USAGE

    return
}


gsatctl/helpMsg() {
    
    cat <<-HELP

$( gsatctl/versionMsg )

SYNOPSIS:

gsatctl [options]

DESCRIPTION:

gsatctl - the gsatellite controller - is the user interface to gsatellite. It
allows for job submission and manipulation. It can also show information about
all gsatellite jobs.

OPTIONS:

-s, --qsub jobFile      Submit a job to gsatellite.

-h, --qhold jobId       Hold a job identified by its job id.

-r, --qrls jobId        Release a hold from a job identified by its job id.

-d, --qdel jobId        Remove a job identified by its job id from gsatellite.
                        This only works for jobs that are not already in the
                        running state.

-l, --qstat [jobState]  List all jobs which are in the state jobState, or if
                        jobState is not provided, list all jobs.

-w, --qwait jobId       Wait for the job specified by its job id to exit and
                        return its exit value.

[--help]                Display this help and exit.

[-V, --version]         Display version information and exit.

SHORTHANDS

gqsub jobFile
qghold jobId
gqrls jobId
gqdel jobId
gqstat [jobState]
gqwait jobId

HELP

    return
}

gsatctl/versionMsg() {

        echo "gsatctl v$_gsatctlVersion"

        return
}


gsatctl/qsub() {
        #  submit a job to gsatellite
        #
        #  usage:
        #+ gsatctl/qsub job

        #  TODO:
        #+ Check if job is really existing.
        local _job="$1"

        #  add absolute path if needed
        if [[ ${_job:0:1} != "/" ]]; then
                _job="$PWD/$_job"
        elif [[ ${_job:0:2} == "./" ]]; then
                _job="${PWD}${_job#.}"
        fi

        #  If job's not existing, retreat.
        if [[ ! -e "$_job" ]]; then
                echo "E: Job not existing!" 1>&2
                return 1
        fi

        local _tempMsgBox=$( ipc/file/createTempMsgBox )

        #  send qsub command to gsatlc
        local _message="QSUB $_job;$_tempMsgBox"

        #  TODO:
        #+ Cover the case when gsatlc is not running! Also for other qx
        #+ functions!
        local _gsatlcHostName=$( cat "$_gsatBaseDir/gsatlcHostName" )
        local _gsatlcPid=$( cat "$_gsatBaseDir/gsatlcPid" )
        local _messageBox="$_MBOXES/$_gsatlcHostName/$_gsatlcPid.inbox"

        if ! ipc/file/sendMsg "$_messageBox" "$_message"; then
                echo "E: ipc/file/sendMsg() failed!" 1>&2
                return 1
        fi

        local _signal="SIGCONT"

        #  wake gsatlc with signal forwarding
        ipc/file/sigfwd/forwardSignal "$_gsatlcHostName" "$_gsatlcPid" "$_signal"
        if [[ "$?" != "0" ]]; then
                echo "E: ipc/file/sigfwd/forwardSignal() failed!" 1>&2
                return 1
        fi

        local _receivedMessage=""

        while [[ 1 ]]; do
                #  touch it first, so changes on other hosts are propagated
                touch --no-create "$_tempMsgBox"
                if ipc/file/messageAvailable "$_tempMsgBox"; then
                        #  This does not work!
                        #local _receivedMessage=$( ipc/file/receiveMsg "$_tempMsgBox" )
                        #  without "local" keyword, it works
                        _receivedMessage=$( ipc/file/receiveMsg "$_tempMsgBox" )

                        if [[ $? -eq 0 ]]; then
                                #echo "($$) DEBUG: _receivedMessage=\"$_receivedMessage\""
                                break
                        fi
                else
                        sleep 0.5
                fi
        done

        local _receivedCommand=${_receivedMessage%%;*}

        #echo "($$) DEBUG: _receivedMessage=\"$_receivedMessage\""
        #echo "($$) DEBUG: _receivedCommand=\"$_receivedCommand\""

        if [[ "$_receivedCommand" == "qsub failed" ]]; then
                echo "E: qsub failed!" 1>&2
                ipc/file/removeMsgBox "$_tempMsgBox"
                return 1
        else
                echo "$_receivedCommand"
                ipc/file/removeMsgBox "$_tempMsgBox"
                return 0
        fi

}


gsatctl/qhold() {
        #  hold a job
        #
        #  usage:
        #+ gsatctl/qhold jobId
        local _jobId="$1"

        #  TODO:
        #+ Only hold jobs that are in state "queued" or "running". And also
        #+ introduce second path that avoids message communication.

        local _tempMsgBox=$( ipc/file/createTempMsgBox )

        #  send qhold command to gsatlc
        local _message="QHOLD $_jobId;$_tempMsgBox"

        local _gsatlcHostName=$( cat "$_gsatBaseDir/gsatlcHostName" )
        local _gsatlcPid=$( cat "$_gsatBaseDir/gsatlcPid" )
        local _messageBox="$_MBOXES/$_gsatlcHostName/$_gsatlcPid.inbox"

        if ! ipc/file/sendMsg "$_messageBox" "$_message"; then
                echo "E: ipc/file/sendMsg() failed!" 1>&2
                return 1
        fi

        local _signal="SIGCONT"

        #  wake gsatlc with signal forwarding
        ipc/file/sigfwd/forwardSignal "$_gsatlcHostName" "$_gsatlcPid" "$_signal" || \
        (echo "E: ipc/file/sigfwd/forwardSignal() failed!" 1>&2 && return 1)

        local _receivedMessage=""

        while [[ 1 ]]; do
                #  touch it first, so changes on other hosts are propagated
                touch --no-create "$_tempMsgBox"
                if ipc/file/messageAvailable "$_tempMsgBox"; then
                        #  This does not work!
                        #local _receivedMessage=$( ipc/file/receiveMsg "$_tempMsgBox" )
                        #  without "local" keyword, it works
                        _receivedMessage=$( ipc/file/receiveMsg "$_tempMsgBox" )

                        if [[ $? -eq 0 ]]; then
                                #echo "($$) DEBUG: _receivedMessage=\"$_receivedMessage\""
                                break
                        fi
                else
                        sleep 0.5
                fi
        done

        local _receivedCommand=${_receivedMessage%%;*}

        #echo "($$) DEBUG: _receivedMessage=\"$_receivedMessage\""
        #echo "($$) DEBUG: _receivedCommand=\"$_receivedCommand\""

        if [[ "$_receivedCommand" != "OK" ]]; then
                echo "E: qhold failed!" 1>&2
                ipc/file/removeMsgBox "$_tempMsgBox"
                return 1
        else
                ipc/file/removeMsgBox "$_tempMsgBox"
                return 0
        fi

}


gsatctl/qrls() {
        #  release a hold on a job
        #
        #  usage:
        #+ gsatctl/qrls jobId
        local _jobId="$1"

        #  Integrated second possible path which checks directly if a job is
        #+ running without interacting with gsatlc. This saves some cycles.
        if [[ $( gschedule/getJobState "$_jobId" ) != "held" ]]; then
                #  retreat
                echo "E: qrls failed! Job \"$_jobId\" not in held state!" 1>&2
                return 1
        else

                local _tempMsgBox=$( ipc/file/createTempMsgBox )

                #  send qhold command to gsatlc
                local _message="QRLS $_jobId;$_tempMsgBox"

                local _gsatlcHostName=$( cat "$_gsatBaseDir/gsatlcHostName" )
                local _gsatlcPid=$( cat "$_gsatBaseDir/gsatlcPid" )
                local _messageBox="$_MBOXES/$_gsatlcHostName/$_gsatlcPid.inbox"

                if ! ipc/file/sendMsg "$_messageBox" "$_message"; then
                        echo "E: ipc/file/sendMsg() failed!" 1>&2
                        return 1
                fi

                local _signal="SIGCONT"

                #  wake gsatlc with signal forwarding
                ipc/file/sigfwd/forwardSignal "$_gsatlcHostName" "$_gsatlcPid" "$_signal" || \
                (echo "E: ipc/file/sigfwd/forwardSignal() failed!" 1>&2 && return 1)

                local _receivedMessage=""

                while [[ 1 ]]; do
                        #  touch it first, so changes on other hosts are propagated
                        touch --no-create "$_tempMsgBox"
                        if ipc/file/messageAvailable "$_tempMsgBox"; then
                                #  This does not work!
                                #local _receivedMessage=$( ipc/file/receiveMsg "$_tempMsgBox" )
                                #  without "local" keyword, it works
                                _receivedMessage=$( ipc/file/receiveMsg "$_tempMsgBox" )

                                if [[ $? -eq 0 ]]; then
                                        #echo "($$) DEBUG: _receivedMessage=\"$_receivedMessage\""
                                        break
                                fi
                        else
                                sleep 0.5
                        fi
                done

                local _receivedCommand=${_receivedMessage%%;*}

                #echo "($$) DEBUG: _receivedMessage=\"$_receivedMessage\""
                #echo "($$) DEBUG: _receivedCommand=\"$_receivedCommand\""

                if [[ "$_receivedCommand" != "OK" ]]; then
                        echo "E: qrls failed!" 1>&2
                        ipc/file/removeMsgBox "$_tempMsgBox"
                        return 1
                else
                        ipc/file/removeMsgBox "$_tempMsgBox"
                        return 0
                fi
        fi
}


gsatctl/qdel() {
        #  remove a job from gsatellite
        #
        #  usage:
        #+ gsatctl/qdel jobId
        local _jobId="$1"

        #  Integrated second possible path which checks directly if a job is
        #+ running or has a valid job id without interacting with gsatlc. This
        #+ saves some cycles.
        if ! gschedule/isValidJobId "$_jobId" || gschedule/isRunningJob "$_jobId"; then
                #  retreat
                echo "E: qdel failed!" 1>&2
                return 1
        else

                local _tempMsgBox=$( ipc/file/createTempMsgBox )

                #  send qdel command to gsatlc
                local _message="QDEL $_jobId;$_tempMsgBox"

                local _gsatlcHostName=$( cat "$_gsatBaseDir/gsatlcHostName" )
                local _gsatlcPid=$( cat "$_gsatBaseDir/gsatlcPid" )
                local _messageBox="$_MBOXES/$_gsatlcHostName/$_gsatlcPid.inbox" 

                if ! ipc/file/sendMsg "$_messageBox" "$_message"; then
                        echo "E: ipc/file/sendMsg failed!" 1>&2
                        return 1
                fi

                local _signal="SIGCONT"

                #  wake qsatlc with signal forwarding
                ipc/file/sigfwd/forwardSignal "$_gsatlcHostName" "$_gsatlcPid" "$_signal" || \
                (echo "E: ipc/file/sigfwd/forwardSignal() failed!" 1>&2 && return 1)

                local _receivedMessage=""

                while [[ 1 ]]; do
                        #  touch it first, so changes on other hosts are propagated
                        touch --no-create "$_tempMsgBox"
                        if ipc/file/messageAvailable "$_tempMsgBox"; then
                                #  This does not work!
                                #local _receivedMessage=$( ipc/file/receiveMsg "$_tempMsgBox" )
                                #  without "local" keyword, it works
                                _receivedMessage=$( ipc/file/receiveMsg "$_tempMsgBox" )

                                if [[ $? -eq 0 ]]; then
                                        #echo "($$) DEBUG: _receivedMessage=\"$_receivedMessage\""
                                        break
                                fi
                        else
                                sleep 0.5
                        fi
                done

                local _receivedCommand=${_receivedMessage%%;*}

                if [[ "$_receivedCommand" != "OK" ]]; then
                        echo "E: qdel failed!" 1>&2
                        ipc/file/removeMsgBox "$_tempMsgBox"
                        return 1
                else
                        ipc/file/removeMsgBox "$_tempMsgBox"
                        return 0
                fi
        fi

        return

}


gsatctl/listJobsInState() {
        #  list gsatellite jobs in specified state
        #
        #  usage:
        #+ gsatlc/listJobsInState jobState

        local _jobState="$1"

        #  right-bound text ouptut (default!)
        printf "%12s\t%12s\t%12s\t%12s\n" "job.state" "job.id" "job.execHost" "job.name"
        echo -e "------------\t------------\t------------\t------------"

        for _jobDir in $( ls -1 "$_gscheduleBaseDir/$_jobState" ); do

                #echo "($$) DEBUG: _jobDir=\"$_jobDir\""

                local _jobId=$( basename "$_gscheduleBaseDir/$_jobState/$_jobDir" )
                _jobId=${_jobId%.d}
                local _jobHost=$( cat "$_gscheduleBaseDir/jobs/$_jobDir/job.execHost" 2>/dev/null )
                local _jobName=$( basename $( readlink "$_gscheduleBaseDir/$_jobState/$_jobDir/$_jobId" ) )

                #  left-bound text output ("-"!)
                printf '%-12s\t%-12s\t%-12s\t%-12s\n' "$_jobState" "$_jobId" "$_jobHost" "$_jobName" #>> tmpfile

        done

        if [[ -e tmpfile ]]; then
                cat tmpfile && rm tmpfile
        fi

        return
}


gsatctl/listAllJobs() {
        #  list all gsatellite jobs
        #
        #  usage:
        #+ gsatlc/listAllJobs

        #  perhaps locking needed before listing?

        #  right-bound text ouptut (default!)
        printf "%12s\t%12s\t%12s\t%12s\n" "job.state" "job.id" "job.execHost" "job.name"
        echo -e "------------\t------------\t------------\t------------"

        for _jobDir in $( ls -1 "$_gscheduleBaseDir/jobs" ); do

                #echo "($$) DEBUG: _jobDir=\"$_jobDir\""

                local _jobId=$( basename "$_gscheduleBaseDir/jobs/$_jobDir" )
                _jobId=${_jobId%.d}
                local _jobState=$( cat "$_gscheduleBaseDir/jobs/$_jobDir/job.state" 2>/dev/null )
                local _jobHost=$( cat "$_gscheduleBaseDir/jobs/$_jobDir/job.execHost" 2>/dev/null )
                local _jobName=$( basename $( readlink "$_gscheduleBaseDir/jobs/$_jobDir/$_jobId" ) )

                #  left-bound text output ("-"!)
                printf '%-12s\t%-12s\t%-12s\t%-12s\n' "$_jobState" "$_jobId" "$_jobHost" "$_jobName" #>> tmpfile

        done

        if [[ -e tmpfile ]]; then
                cat tmpfile && rm tmpfile
        fi

        return
}


gsatctl/qstat() {
        #  show info about jobs
        #
        #  usage:
        #+ gsatctl/qstat [jobState]
        local _jobState="$1"

        if [[ "$_jobState" == "all" ]]; then
                gsatctl/listAllJobs
        elif [[ "$_jobState" == "ready" || \
                "$_jobState" == "running" || \
                "$_jobState" == "finished" || \
                "$_jobState" == "failed" ]]; then
                gsatctl/listJobsInState "$_jobState"
        else
                return 1
        fi

        return    

}

################################################################################

case $( basename "$0" ) in
        "gqstat")
                exec gsatctl --qstat "$@"
                ;;

        "gqhold")
                exec gsatctl --qhold "$@"
                ;;

        "gqrls")
                exec gsatctl --qrls "$@"
                ;;

        "gqsub")
                exec gsatctl --qsub "$@"
                ;;

        "gqdel")
                exec gsatctl --qdel "$@"
                ;;

        "gqwait")
                exec gsatctl --qwait "$@"
                ;;
        *)
                :
                ;;
esac

#  correct number of params?
if [[ "$#" -lt "1" ]]; then
   # no, so output a usage message
   gsatctl/usageMsg
   exit 1
fi

# read in all parameters
while [[ "$1" != "" ]]; do

	#  only valid params used?
	#
	#  NOTICE:
	#  This was added to prevent high speed loops
	#+ if parameters are mispositioned.
	if [[   "$1" != "--help" && \
                "$1" != "--version" && "$1" != "-V" && \
                "$1" != "--qsub" && "$1" != "-s" && \
                "$1" != "--qhold" && "$1" != "-h" && \
                "$1" != "--qrls" && "$1" != "-r" && \
                "$1" != "--qdel" && "$1" != "-d" && \
                "$1" != "--qstat" && "$1" != "-l" && \
                "$1" != "--qwait" && "$1" != "-w" \
        ]]; then
		#  no, so output a usage message
		gsatctl/usageMsg
		exit 1   
	fi

	#  "--help"
	if [[ "$1" == "--help" ]]; then
		gsatctl/helpMsg
		exit 0

	#  "--version|-V"
	elif [[ "$1" == "--version" || "$1" == "-V" ]]; then
		gsatctl/versionMsg
		exit 0

	#  "--qsub|-s job"
	elif [[ "$1" == "--qsub" || "$1" == "-s" ]]; then
                _option="$1"
                if [[ "$_jobSet" != "0" ]]; then
	                shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _job="$1"
                                _jobSet="0"
                                shift 1
                        else
                                echo "E: missing option parameter for \"$_option\"!"
                                exit 1
                        fi

                        gsatctl/qsub "$_job"
                        exit
                else
	                #  duplicate usage of this parameter
	                echo "ERROR: The option \"$_option\" cannot be used multiple times!"
	                exit 1
                fi

        #  "--qdel|-d jobId"
        elif [[ "$1" == "--qdel" || "$1" == "-d" ]]; then
                _option="$1"
                if [[ "$_jobIdSet" != "0" ]]; then
	                shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobId="$1"
                                _jobIdSet="0"
                                shift 1
                        else
                                echo "E: missing option parameter for \"$_option\"!"
                                exit 1
                        fi

                        gsatctl/qdel "$_jobId"
                        exit
                else
	                #  duplicate usage of this parameter
	                echo "ERROR: The option \"$_option\" cannot be used multiple times!"
	                exit 1
                fi

        #  "--qstat|-l [jobState]"
        elif [[ "$1" == "--qstat" || "$1" == "-l" ]]; then
                _option="$1"
                if [[ "$_jobStateSet" != "0" ]]; then
                        shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobState="$1"
                                _jobStateSet="0"
                                shift 1
                        else
                                _jobState="all"
                                _jobStateSet="0"
                        fi

                        gsatctl/qstat "$_jobState"
                        exit
                else
                        #  duplicate usage of this parameter
                        echo "ERROR: The option \"$_option\" cannot be used multiple times!"
                        exit 1
                fi

        #  "--qhold|-h jobId"
        elif [[ "$1" == "--qhold" || "$1" == "-h" ]]; then
                _option="$1"
                if [[ "$_jobIdSet" != "0" ]]; then
                        shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobId="$1"
                                _jobIdSet="0"
                                shift 1
                        else
                                echo "E: missing option parameter for \"$_option\"!"
                                exit 1
                        fi

                        #echo "Sorry, function is not available yet!"
                        gsatctl/qhold "$_jobId"
                        exit
                else
                        #  duplicate usage of this parameter
                        echo "ERROR: The option \"$_option\" cannot be used multiple times!"
                        exit 1
                fi

        #  "--qrls|-r jobId"
        elif [[ "$1" == "--qrls" || "$1" == "-r" ]]; then
                _option="$1"
                if [[ "$_jobIdSet" != "0" ]]; then
                        shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobId="$1"
                                _jobIdSet="0"
                                shift 1
                        else
                                echo "E: missing option parameter for \"$_option\"!"
                                exit 1
                        fi

                        #echo "Sorry, function is not available yet!"
                        gsatctl/qrls "$_jobId"
                        exit
                else
                        #  duplicate usage of this parameter
                        echo "ERROR: The option \"$_option\" cannot be used multiple times!"
                        exit 1
                fi

        #  "--qwait|-w jobId"
        elif [[ "$1" == "--qwait" || "$1" == "-w" ]]; then
                _option="$1"
                if [[ "$_jobIdSet" != "0" ]]; then
                        shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobId="$1"
                                _jobIdSet="0"
                                shift 1
                        else
                                echo "E: missing option parameter for \"$_option\"!"
                                exit 1
                        fi

                        echo "Sorry, function is not available yet!"
                        #gsatctl/qwait "$_jobId"
                        exit
                else
                        #  duplicate usage of this parameter
                        echo "ERROR: The option \"$_option\" cannot be used multiple times!"
                        exit 1
                fi

        fi

done

exit

