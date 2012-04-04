#!/bin/bash

#  sputnik.bash - gsatellite tool (runs and controls jobs)

:<<COPYRIGHT

Copyright (C) 2011, 2012 Frank Scheiner

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

_gsatBaseDir=$HOME/.gsatellite
_gscheduleBaseDir="$_gsatBaseDir/gschedule"

################################################################################

#  child libs inherit parent lib functions
#. "$_LIB"/ipc.bashlib
#. "$_LIB"/ipc/file.bashlib
. "$_LIB"/ipc/file/msgproc.bashlib

################################################################################

sputnik/wakeUp() {
        #  wakes up the parent after X seconds and a variable time (depending
        #+ on message traffic). This is done regularly after startup.
        #
        #  usage:
        #+ wakeUp parentInbox parentPid seconds

        local _parentInbox="$1"
        local _parentPid="$2"
        local _seconds="$3"

        local _message="WAKE UP"

        trap 'exit' TERM

        while [[ 1 ]]; do

                #  this makes the sleep somewhat interruptable
                for _times in $( seq "$_seconds"); do
                        sleep 1
                done

                #echo "wakeup"

                ipc/file/sendMsg "$_parentInbox" "$_message"

                #  wakeup parent
                /bin/kill -SIGCONT $_parentPid &>/dev/null

        done

}

sputnik/runJob() {
        #  run the gsatellite job (in the foreground) and notify parent if job
        #+ when it terminates.
        #
        #  usage:
        #+ sputnik/runJob parentInbox parentPid job

        local _parentInbox="$1"
        local _parentPid="$2"
        local _job="$3"

        #  run job in the foreground
        $_job 1>$( dirname "$_job" )/../stdout 2>$( dirname "$_job" )/../stderr

        local _jobExitValue="$?"

        #  no answer from the parent needed, hence no inbox provided
        local _message="TERMINATED $_jobExitValue;"

        ipc/file/sendMsg "$_parentInbox" "$_message"

        #local _signal="SIGCONT"

        #  not needed, as the parent runs on the same host
        #ipc/file/sigfwd/forwardSignal "$( hostname --fqdn )" "$_parentPid" "$_signal"
        /bin/kill -SIGCONT $_parentPid &>/dev/null

        if [[ "$?" == "0" ]]; then
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
        if [[ "$_command" == "WAKE UP" ]]; then
                echo "sputnik: awake!"
                return
        elif [[ "$_command" =~ ^TERMINATED.* ]]; then
                #  command is "TERMINATED <EXIT_VALUE>"
                #local _jobExitValue=$( echo "$_command" | cut -d ' ' -f 2 )

                local _gsatlcMessage="$_command;$_inbox"

                ipc/file/sendMsg "$_gsatlcMessageBox" "$_gsatlcMessage"

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
#  old code
stopJob()
{
	#  usage:
	#+ stopJob _cpid

	local _cpid="$1"
	
	kill "$_cpid"

	return
}

pauseJob()
{
	:

	return
}

getJobStatus()
{
	#  usage:
	#+ getJobStatus _cpid

	local _cpid="$1"

	if /bin/kill -0 "$_cpid" &>/dev/null; then
		#  job still running
		return 0
	else
		#  job is dead
		return 1
	fi
}

################################################################################

#  a gsatellite job is a shell script
_job="$1"
_jobId="$2"

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

#  spawn signal forwarder if not already existing
#if messagebox doesn't exist
#  spawn sigfwd
#fi

#  contact local signal forwarder through default messagebox of signal forwarder
#  Check if it is "ALIVE?".
#  check aliveness with timed receiveMsg
#  If not, start a signal forwarder.

#  wake up regularly every 10 seconds
wakeUp "10" "$_inbox" "$_self" &

#  child's PID
_wakeupChildPid="$!"

#  start job
#runJob "$_job" "$_self" &

#  child's PID
#_jobChildPid="$!"

while [[ 1 ]]; do
        if [[ -s "$_inbox" ]]; then
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
                #  pause execution
                #  If you need something, wake me up!
                /bin/kill -SIGSTOP "$_self"
        fi    
done

exit

