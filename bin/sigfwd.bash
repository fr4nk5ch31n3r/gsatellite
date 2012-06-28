#!/bin/bash

#  sigfwd - simple signal forwarder
#
#  Forwards signals to remote processes given the fact that all remote machines
#+ share a common filesystem.

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

_DEBUG="1"

_gsatBaseDir=$HOME/.gsatellite

#  path to path configuration file (prefer system paths!)
if [[ -e "/opt/gsatellite/etc/paths.conf" ]]; then
        _pathsConfigurationFile="/opt/gsatellite/etc/paths.conf"
#sed#elif [[ -e "<PATH_TO_GSATELLITE>/etc/paths.conf" ]]; then
#sed#    _pathsConfigurationFile="<PATH_TO_GSATELLITE>/etc/paths.conf"
elif [[ -e "/etc/opt/gsatellite/etc/paths.conf" ]]; then
        _pathsConfigurationFile="/etc/opt/gsatellite/etc/paths.conf"
elif [[ -e "$HOME/.gsatellite/paths.conf" ]]; then
        _pathsConfigurationFile="$HOME/.gsatellite/paths.conf"
fi

#  include path config
. "$_pathsConfigurationFile"

#. $_LIB/ipc.bashlib
#. $_LIB/ipc/file.bashlib
. "$_LIB"/ipc/file/sigfwd.bashlib
. "$_LIB"/ipc/file/msgproc.bashlib
. "$_LIB"/utils.bashlib


processMsg() {
    local _message="$1"
    local _inbox="$2"

    local _command=""
    local _answerBox=""

    _command=$( echo "$_message" | cut -d ';' -f 1 )
    _answerBox=$( echo "$_message" | cut -d ';' -f 2 )

    [[ "$_DEBUG" == "1" ]] && echo "($$) DEBUG: in processMsg() _command=\"$_command\", _answerBox=\"$_answerBox\"" 1>&2

    #  garbage in inbox?
    #if [[ "$_command" == "" && "$_answerBox" == "" ]]; then
    #    return 1
    #fi

    #  special functionality
    if [[ "$_command" =~ ^SIG.* ]]; then
        #  Determine signal and PID from command
        _signal=$( echo "$_command" | cut -d ' ' -f 1 )
        _pid=$( echo "$_command" | cut -d ' ' -f 2 )

        #  Forward signal to "local" process
        [[ "$_DEBUG" == "1" ]] && echo "($$) DEBUG: in processMsg(SIG*) before \"/bin/kill -"$_signal" "$_pid" &>/dev/null\"." 1>&2
        /bin/kill -"$_signal" "$_pid" &>/dev/null
        _killRetVal="$?"

        [[ "$_DEBUG" == "1" ]] && echo "($$) DEBUG: in processMsg(SIG*) before sendMsg()." 1>&2
        ipc/file/sendMsg "$_answerBox" "$_killRetVal;$_inbox"

        [[ "$_DEBUG" == "1" ]] && echo "($$) DEBUG: in processMsg(SIG*) after sendMsg(\"$_killRetVal;$_inbox\")." 1>&2

        return
    fi

    #  standard functionality for message processing
    ipc/file/msgproc/processMsg "$_message" "$_inbox"

    return

}

################################################################################

trap 'ipc/file/removeMsgBox "$_inbox" && ipc/file/removeMsgBox "$_aliasInbox"' EXIT

_self="$$"
_inboxName="$_self.inbox"

#  create or truncate inbox
_inbox=$( ipc/file/createMsgBox "$_inboxName" )

#  create alias link
_aliasInboxName="$_ipc_file_sigfwdInboxName"
#ln -s "$( basename $_inbox )" "$( dirname $_inbox )/$_inboxAliasName"
#_aliasInbox="$( dirname $_inbox )/$_inboxAliasName"
_aliasInbox=$( ipc/file/createAliasMsgBox "$_inbox" "$_aliasInboxName" )

#  save pid
_hostName=$( utils/getHostName )
if [[ ! -e "$_gsatBaseDir/var/run/$_hostName" ]]; then
        mkdir -p "$_gsatBaseDir/var/run/$_hostName"
fi
echo $_self > "$_gsatBaseDir/var/run/$_hostName/sigfwdPid"

################################################################################

#  read and sleep if nothing to do
while [[ 1 ]]; do
        #  check real inbox for new messages, ...
        #  touch it first, so changes on other hosts are propagated
        #touch -c "$_inbox"
        if ipc/file/messageAvailable "$_inbox"; then
                [[ "$_DEBUG" == "1" ]] && echo "($$) DEBUG: in main() before receiveMsg()." 1>&2
                _message=$( ipc/file/receiveMsg "$_inbox" )
                processMsg "$_message" "$_inbox"
        else
                #  sigfwd mustn't stop itself, as otherwise it wouldn't be possible to
                #+ wake it up from a remote host. Therefore if nothing to do it should
                #+ sleep for some time.
                sleep 0.5
        fi

done

exit

