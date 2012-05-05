#!/bin/bash

#  gsatctl - gsatellite controller (user interface to gsatellite)

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

#  include path config
. /opt/gsatellite/etc/path.conf

#. "$_LIB"/ipc.bashlib
#. "$_LIB"/ipc/file.bashlib
. "$_LIB"/ipc/file/sigfwd.bashlib

. "$_LIB"/utils.bashlib

. "$_LIB"/gsatlc.bashlib

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
       gsatctl --qwait jobId

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
allows for job submission and manipulation like stopping or pausing a job. It
can also show information about all gsatellite jobs.

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
        local _job="$1"

        #  add absolute path if needed
        if [[ ${_job:0:1} != "/" ]]; then
                _job="$PWD/$_job"
        elif [[ ${_job:0:2} == "./" ]]; then
                _job="${PWD}${_job#.}"
        fi

        local _tempMsgBox=$( ipc/file/createTempMsgBox )

        #  send qsub command to gsatlc
        local _message="QSUB $_job;$_tempMsgBox"

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

gsatctl/qdel() {
        #  remove a job from gsatellite
        #
        #  usage:
        #+ gsatctl/qdel jobId
        local _jobId="$1"

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
                                echo "($$) DEBUG: _receivedMessage=\"$_receivedMessage\""
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

        return

}

gsatctl/listJobsInState() {
        #  list gsatellite jobs in specified state
        #
        #  usage:
        #+ gsatlc/listJobsInState jobState

        local _jobState="$1"

        #  right-bound text ouptut (default!)
        printf "%12s\t%12s\t%12s\t%12s\n" "jobState" "jobId" "jobHost" "jobName"
        echo -e "------------\t------------\t------------\t------------"

        for _jobDir in $( ls -1 "$_gscheduleBaseDir/$_jobState" ); do

                #echo "($$) DEBUG: _jobDir=\"$_jobDir\""

                local _jobId=$( basename "$_gscheduleBaseDir/$_jobState/$_jobDir" )
                _jobId=${_jobId%.d}
                local _jobHost=$( cat "$_gscheduleBaseDir/jobs/$_jobDir/host" 2>/dev/null )
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
        printf "%12s\t%12s\t%12s\t%12s\n" "jobState" "jobId" "jobHost" "jobName"
        echo -e "------------\t------------\t------------\t------------"

        for _jobDir in $( ls -1 "$_gscheduleBaseDir/jobs" ); do

                #echo "($$) DEBUG: _jobDir=\"$_jobDir\""

                local _jobId=$( basename "$_gscheduleBaseDir/jobs/$_jobDir" )
                _jobId=${_jobId%.d}
                local _jobState=$( cat "$_gscheduleBaseDir/jobs/$_jobDir/state" 2>/dev/null )
                local _jobHost=$( cat "$_gscheduleBaseDir/jobs/$_jobDir/host" 2>/dev/null )
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
	                echo "ERROR: The parameter \"--qsub|-s\" cannot be used multiple times!"
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
	                echo "ERROR: The parameter \"--qdel|-d\" cannot be used multiple times!"
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
                        echo "ERROR: The parameter \"--qstat|-l\" cannot be used multiple times!"
                        exit 1
                fi

        fi

done

exit

