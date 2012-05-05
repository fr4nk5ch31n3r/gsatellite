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
. "$_LIB/ipc/file/msgproc.bashlib"
. "$_LIB/utils.bashlib"
 
################################################################################

sputnik/runJob() {
        #  run the gsatellite job (in the foreground) and notify parent if job
        #+ when it terminates.
        #
        #  usage:
        #+ sputnik/runJob job parentPid parentInbox

        local _job="$1"
        local _parentPid="$2"
        local _parentInbox="$3"

        #  _jobDir is "[...]/jobs/<JOB_ID>/jobtmp" 
        local _jobDir=$( dirname "$_job" )

        #  run job in the foreground
        cd "$_jobDir" && \
        bash $_job 1>"$_jobDir/../stdout" 2>"$_jobDir/../stderr"

        local _jobExitValue="$?"

        #  no answer from the parent needed, hence no inbox provided
        local _message="TERMINATED $_jobExitValue;"

        ipc/file/sendMsg "$_parentInbox" "$_message"

        #  wakeup parent
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
                #echo "sputnik: awake!"
                return
        elif [[ "$_command" =~ ^TERMINATED.* ]]; then
                #  command is "TERMINATED <EXIT_VALUE>"
                local _jobExitValue=$( echo "$_command" | cut -d ' ' -f 2 )

                local _gsatlcMessage="TERMINATED $_jobId $_jobExitValue;$_inbox"

                ipc/file/sendMsg "$_gsatlcMessageBox" "$_gsatlcMessage"
                #echo "$_gsatlcMessageBox" "$_gsatlcMessage"

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

#  wake up regularly every 10 seconds
utils/wakeUp "$_self" "10" &

#  child's PID
_wakeupChildPid="$!"

#  start job
sputnik/runJob "$_job" "$_self" "$_inbox" &

#  child's PID
#_jobChildPid="$!"

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
                #  pause execution
                #  If you need something, wake me up!
                /bin/kill -SIGSTOP "$_self"
        fi

        #echo "awake!"

done

exit

