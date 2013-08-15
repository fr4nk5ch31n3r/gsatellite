#!/bin/bash

# sigfwd - simple signal forwarder
#
# Forwards signals to remote processes as long as all remote machines share a
# common filesystem.

:<<COPYRIGHT

Copyright (C) 2012 Frank Scheiner
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

################################################################################
#  DEFINES
################################################################################

readonly _true=1
readonly _false=0

readonly __GLOBAL__programName=$( basename "$0" )

readonly __GLOBAL__version="0.3.0"

# time to sleep between each check for new messages
readonly __GLOBAL__sleepInterval="0.5"

################################################################################
#  CONFIGURATION
################################################################################

umask 0077

if [[ -z "$_DEBUG" ]]; then
	_DEBUG=$_false
fi

_gsatBaseDir=$HOME/.gsatellite

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
	echo "[$_program] E: Paths configuration file couldn't be read or is corrupted." 1>&2
	exit $_exit_software
fi

################################################################################
#  INCLUDES
################################################################################

#. $_LIB/ipc.bashlib
#. $_LIB/ipc/file.bashlib
#. "$_LIB"/ipc/file/sigfwd.bashlib
#. "$_LIB"/ipc/file/msgproc.bashlib
#. "$_LIB"/utils.bashlib

#  include needed libaries
_neededLibraries=( "ipc/file/sigfwd.bashlib"
		   "ipc/file/msgproc.bashlib"
		   "utils.bashlib" )

for _library in "${_neededLibraries[@]}"; do

	if ! . "$_LIB"/"$_library"; then
		echo "[$_program] E: Library \""$_LIB"/"$_library"\" couldn't be read or is corrupted." 1>&2
		exit $_exit_software
	fi
done

################################################################################
#  VARIABLES
################################################################################

_initialActionId=0
declare -a _actionPids

################################################################################
#  FUNCTIONS
################################################################################

processMsg()
{
	local _message="$1"
	local _inbox="$2"

	local _command=""
	local _answerBox=""

	_command=$( echo "$_message" | cut -d ';' -f 1 )
	_answerBox=$( echo "$_message" | cut -d ';' -f 2 )

	[[ $_DEBUG -eq $_true ]] && echo "($$) [$__GLOBAL__programName] DEBUG: in processMsg() _command=\"$_command\", _answerBox=\"$_answerBox\"" 1>&2

	#  special functionality
	if [[ "$_command" =~ ^SIG.* ]]; then
		#  Determine signal and PID from command
		_signal=$( echo "$_command" | cut -d ' ' -f 1 )
		_pid=$( echo "$_command" | cut -d ' ' -f 2 )

		#  Forward signal to "local" process
		[[ $_DEBUG -eq $_true ]] && echo "($$) [$__GLOBAL__programName] DEBUG: in processMsg(SIG*) before \"/bin/kill -"$_signal" \"$_pid\" &>/dev/null\"." 1>&2
		/bin/kill -"$_signal" "$_pid" &>/dev/null
		_killRetVal="$?"

		[[ $_DEBUG -eq $_true ]] && echo "($$) [$__GLOBAL__programName] DEBUG: in processMsg(SIG*) before sendMsg." 1>&2
		ipc/file/sendMsg "$_answerBox" "$_killRetVal;$_inbox"

		[[ $_DEBUG -eq $_true ]] && echo "($$) [$__GLOBAL__programName] DEBUG: in processMsg(SIG*) after sendMsg \"$_answerBox\" \"$_killRetVal;$_inbox\"." 1>&2

	elif [[ "$_command" =~ ^DELEGATE_ACTION* ]]; then
		# Determine action
		local _action=$( echo "$_command" | cut -d ' ' -f 2 )
		[[ $_DEBUG -eq $_true ]] && echo "($$) [$__GLOBAL__programName] DEBUG: _action=\"$_action\"" 1>&2
		if [[ "$_action" == "" ]]; then
			return 1
		else
			local _actionId=$_currentActionId
			chmod +x "$_action"
			"$_action" &>/dev/null &
			_actionPids[$_actionId]="$!"
			[[ $_DEBUG -eq $_true ]] && echo "($$) [$__GLOBAL__programName] DEBUG: _actionPid=\"${_actionPids[$_actionId]}\"" 1>&2
			_currentActionId=$(( $_currentActionId + 1 ))

			ipc/file/sendMsg "$_answerBox" "$_actionId;$_inbox"

		fi

	elif [[ "$_command" =~ ^UNDELEGATE_ACTION* ]]; then
		# Determine action
		local _actionId=$( echo "$_command" | cut -d ' ' -f 2 )
		if [[ "$_actionId" == "" ]]; then
			return 1
		else
			local _actionPid=${_actionPids[$_actionId]}
			if [[ "$_actionPid" != "empty" ]]; then
				if kill -0 "$_actionPid" &>/dev/null; then
					kill "$_actionPid" &>/dev/null
				fi
				_actionPids[$_actionId]="empty"
			fi

			ipc/file/sendMsg "$_answerBox" "OK;$_inbox"
		fi
	else
		#  standard functionality for message processing
		ipc/file/msgproc/processMsg "$_message" "$_inbox"
	fi

	return

}


#  onExit() - perform cleanup on exit.
sigfwd/onExit()
{
	#  remove all message boxes
	ipc/file/removeMsgBox "$_inbox"
	ipc/file/removeMsgBox "$_aliasInbox"

	rm -f "$_selfPidFile"

	return
}

################################################################################
#  MAIN
################################################################################

trap 'sigfwd/onExit' EXIT

_self="$$"
_inboxName="$_self.inbox"

#  create inbox
_inbox=$( ipc/file/createMsgBox "$_inboxName" )

#  create alias inbox
_aliasInboxName="$_ipc_file_sigfwdInboxName"
_aliasInbox=$( ipc/file/createAliasMsgBox "$_inbox" "$_aliasInboxName" )

#  save PID
_hostName=$( utils/getHostName )
if [[ ! -e "$_gsatBaseDir/var/run/$_hostName" ]]; then
        mkdir -p "$_gsatBaseDir/var/run/$_hostName"
fi

_selfPidFile="$_gsatBaseDir/var/run/$_hostName/sigfwd.pid"

echo $_self > "$_selfPidFile"

_currentActionId=$_initialActionId

################################################################################

#  read and sleep if nothing to do
while [[ 1 ]]; do
        #  check real inbox for new messages, ...
        #  touch it first, so changes on other hosts are propagated
        #touch -c "$_inbox"
        #  => this is not needed!
        if ipc/file/messageAvailable "$_inbox"; then
                [[ $_DEBUG -eq $_true ]] && echo "($$) [$__GLOBAL__programName] DEBUG: in main() before receiveMsg." 1>&2
                _message=$( ipc/file/receiveMsg "$_inbox" )
                processMsg "$_message" "$_inbox"
        else
                #  sigfwd mustn't stop itself, as otherwise it wouldn't be
                #+ possible to wake it up from a remote host. Therefore if
                #+ nothing to do, it should sleep for some time.
                sleep "$__GLOBAL__sleepInterval"
        fi

done

exit

