#!/bin/bash

#  send_command.bash - send message test program

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

_DEBUG="1"

#  include path config
. /opt/gsatellite/etc/path.conf

#. "$_LIB"/ipc.bashlib
#. "$_LIB"/ipc/file.bashlib
. "$_LIB"/ipc/file/sigfwd.bashlib
. "$_LIB"/gsatlc.bashlib

processMsg() {
    local _message="$1"

    local _answer=""
    local _answerBox=""

    _answer=$( echo "$_message" | cut -d ';' -f 1 )
    _answerBox=$( echo "$_message" | cut -d ';' -f 2 )

    echo "I: answer \"$_answer\" from box \"$_answerBox\"."
    
    return
}

################################################################################

#  setup trap to remove inbox on exit
trap 'ipc/file/removeLocalMsgBoxByName "$_inboxName"' EXIT

if [[ "$1" == "" ]]; then
        echo ""
        echo "usage: send_command command targetMessageBox"
        echo ""
        echo "with command in:"
        echo "* \"ALIVE?\""
        echo "* \"PID?\""
        echo "* \"HOST?\""
        echo "* \"STOP\""
        echo "* ..."
        echo ""
        exit 1
fi


_self="$$"

_inboxName="$_self.inbox"

#  create inbox
_inbox=$( ipc/file/createMsgBox "$_inboxName" )

_command="$1"
_messageBox="$2"

_contactHostName="$( ipc/file/getHostNameForMsgBox $_messageBox )"
_contactPid="$( ipc/file/getPidForMsgBox $_messageBox )"


while [[ 1 ]]; do
    #  TODO:
    #+ Improve message format to also include an id, that could be used to
    #+ identify answers to specific messages. This could be needed if answers
    #+ come in asynchronously.
    #+
    #+ new format:
    #+ "$_message;$_inbox;$_id"
    ipc/file/sendMsg "$_messageBox" "$_command;$_inbox"
    _retVal="$?"
    if [[ "$_retVal" == "0" ]]; then
        [[ "$_DEBUG" == "1" ]] && echo "($$) DEBUG: sendMsg($_command;$_inbox) successful."
        #  send SIGCONT to stop&go process (sputnik)
        [[ "$_DEBUG" == "1" ]] && echo "($$) DEBUG: before forwardSignal()." 1>&2
        ipc/file/sigfwd/forwardSignal "$_contactHostName" "$_contactPid" "SIGCONT"
        if [[ "$?" != "0" ]]; then
            #  signal couldn't be delivered, perhaps contact is dead
            echo "E: Signal forwarding to contact \"$_contactPid\" on host \"$_contactHostName\" failed. Exiting." 1>&2
            exit 1
        fi
        break
    elif [[ "$_retVal" == "1" ]]; then
        [[ "$_DEBUG" == "1" ]] && echo "($$) DEBUG: sendMsg($_message;$_inbox) failed."
        sleep 1
        continue
    elif [[ "$_retVal" == "2" ]]; then
        echo "E: Message box \"$_messageBox\" not existing." 1>&2
        exit 1
    fi
done

while [[ 1 ]]; do
    _answer=$( ipc/file/receiveMsg "$_inbox" )
    _retVal="$?"
    if [[ "$_retVal" == "0" ]]; then
        [[ "$_DEBUG" == "1" ]] && echo "($$) DEBUG: receiveMsg($_inbox) successful."
        break
    else
        [[ "$_DEBUG" == "1" ]] && echo "($$) DEBUG: receiveMsg($_inbox) failed."
        sleep 1
    fi
done

processMsg "$_answer"

exit

