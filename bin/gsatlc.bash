#!/bin/bash

#  gsatlc.bash - gsatellite launch control
#
#  controls satellites

:<<COPYRIGHT

Copyright (C) 2011, 2012 Frank Scheiner
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

readonly __GLOBAL__version="0.2.0"

_gsatlcInboxName="gsatlc.inbox"
_gsatBaseDir=$HOME/.gsatellite

_scheduler="fifo"

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
	echo "($_program) E: Paths configuration file couldn't be read or is corrupted." 1>&2
	exit 70
fi

#. "$_LIB"/ipc.bashlib
#. "$_LIB"/ipc/file.bashlib
. "$_LIB"/ipc/file/sigfwd.bashlib
. "$_LIB"/ipc/file/msgproc.bashlib
. "$_LIB"/gsatlc.bashlib
. "$_LIB"/utils.bashlib

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

#  onExit() - perform cleanup on exit.
gsatlc/onExit()
{
	#gsatlc/stopAllJobs

	#  remove all message boxes
	ipc/file/removeMsgBox "$_inbox"

	if [[ ! -z $_actionId ]]; then
		ipc/file/sigfwd/undelegateAction "$_actionId"
	fi

	# remove state files if still existing
	rm -f "$_gsatBaseDir/gsatlcHostName" "$_gsatBaseDir/gsatlcPid"

	sigfwdd --stop && echo "($$) [gsatlc] Signal forwarding stopped."
	echo "($$) [gsatlc] Shutting down."

	return
}


gsatlc/prepareAction()
{
	local _actionTemplate="$1"
	local _pidFile="$2"
	local _period="$3"

	mkdir -p "$_gsatBaseDir/tmp"

	local _action="$_gsatBaseDir/tmp/gsatlc_action_$$"

	sed -e "s|<PID_FILE>|$_pidFile|" -e "s|<PERIOD_IN_SECONDS>|$_period|" "$_actionTemplate" > "$_action"

	if [[ $? == 0 ]]; then
		echo "$_action"
		return 0
	else
		return 1
	fi
}
################################################################################

_actionTemplate="${_GSAT_LIBEXECPATH}/actions/templates/periodicPidFileUpdate.bash"
# run action every 4 seconds
_actionPeriod=4

#  TODO:
#+ On exit, stop (all) running job(s). On start, start jobs depending on the
#+ scheduler.

#  setup trap to remove inbox on exit
#trap 'ipc/file/removeLocalMsgBoxByName "$_inboxName"; ipc/file/sigfwd/stopSigfwd' EXIT
#trap 'ipc/file/removeLocalMsgBoxByName "$_inboxName"; sigfwdd --stop && echo "($$) Signal forwarding stopped."; echo "($$) Shutting down."' EXIT
trap 'gsatlc/onExit' EXIT

#  Startup
_self="$$"

_inboxName="$_self.inbox"

#  create inbox
_inbox=$( ipc/file/createMsgBox "$_inboxName" )

#  save hostname, pid, etc.
_hostName=$( utils/getHostName )
mkdir -p "$_gsatBaseDir/var/run/$_hostName"
echo "$_hostName" > "$_gsatBaseDir/gsatlcHostName"
echo $_self > "$_gsatBaseDir/gsatlcPid"

#  start signal forwarder
sigfwdd --start && echo "($$) [gsatlc] Signal forwarding started."

# Delegate periodic update of PID file with sigfwd.
#
# This could work as follows, a process can provide a script file that is made
# available to sigfwd. Sigfwd will then execute the script file in the
# background and give back an ID identifying the specific action. By using this
# ID, an action can later be unregistered.

_action=$( gsatlc/prepareAction "$_actionTemplate" "$_gsatBaseDir/gsatlcPid" "$_actionPeriod" )

if [[ $? != 0 ]]; then

	echo "($$) [gsatlc] Periodic PID file update could not be pepared. Exiting."
	exit 1
else
	echo "($$) [gsatlc] Periodic PID file update pepared."

	sleep 1

	_actionId=$( ipc/file/sigfwd/delegateAction "$_hostName" "$_action" )

	if [[ $? != 0 ]]; then

		echo "($$) [gsatlc] Periodic PID file update could not be delegated. Exiting."
		exit 1
	else
		echo "($$) [gsatlc] Periodic PID file update delegated."
	fi
fi

echo "($$) [gsatlc] Started up."

#gsatlc/startAllJobs

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

