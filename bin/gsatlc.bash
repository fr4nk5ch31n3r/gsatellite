#!/bin/bash

#  gsatlc.bash - gsatellite launch control
#
#  controls satellites

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

_gsatlcInboxName="gsatlc.inbox"
_gsatBaseDir=$HOME/.gsatellite

_scheduler="fifo"

#  include path config
. /opt/gsatellite/etc/path.conf

#. "$_LIB"/ipc.bashlib
#. "$_LIB"/ipc/file.bashlib
. "$_LIB"/ipc/file/sigfwd.bashlib
. "$_LIB"/ipc/file/msgproc.bashlib
. "$_LIB"/gsatlc.bashlib

#  reimplementation with if clauses, as this could allow to include
#+ functionality dynamically
processMsg() {
        #  process a received message
        #
        #  usage:
        #+ processMsg message inbox

        local _message="$1"
        local _inbox="$2"

        #  gsatlc special functionality for message processing
        gsatlc/processMsg "$_message" "$_inbox"

        #  unknown event or command?
        if [[ "$?" == "2" ]]; then

                #  try standard functionality for message processing
                ipc/file/msgproc/processMsg "$_message" "$_inbox"

        else
                return 2

        fi

        return
}

################################################################################

#  TODO:
#+ On exit stop (all) running job(s). On start start jobs depending on the
#+ scheduler.
#  setup trap to remove inbox on exit
trap 'ipc/file/removeLocalMsgBoxByName "$_inboxName"; ipc/file/sigfwd/stopSigfwd; echo "($$) Signal forwarding stopped."; echo "($$) Shutting down."' EXIT
#trap 'ipc/file/removeLocalMsgBoxByName "$_inboxName"; ipc/file/sigfwd/stopSigfwd' EXIT

#  Startup
_self="$$"

_inboxName="$_self.inbox"

#  create inbox
_inbox=$( ipc/file/createMsgBox "$_inboxName" )

#  save hostname, pid, etc.
echo $( hostname --fqdn ) > "$_gsatBaseDir/gsatlcHostName"
echo $_self > "$_gsatBaseDir/gsatlcPid"

#  start signal forwarder
ipc/file/sigfwd/startSigfwd &>/dev/null

echo "($$) Signal forwarding started."
echo "($$) Started up."

while [[ 1 ]]; do
        if ipc/file/messageAvailable "$_inbox"; then
                _message=$( ipc/file/receiveMsg "$_inbox" )
                processMsg "$_message" "$_inbox"
        else
                #  pause execution
                #  If you need something, wake me up!
                /bin/kill -SIGSTOP "$_self"
        fi
done

exit

