#!/bin/bash

#  sendcmd.bash - send command test program

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

_sendcmdVersion="0.3.0"

readonly _exit_usage=64
readonly _exit_ok=0
readonly _exit_software=70

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
	echo "[$_program] E: Paths configuration file couldn't be read or is corrupted." 1>&2
	exit $_exit_software
fi

################################################################################

#. "$_LIB"/ipc.bashlib
#. "$_LIB"/ipc/file.bashlib
#. "$_LIB"/ipc/file/sigfwd.bashlib
#. "$_LIB"/gsatlc.bashlib

#  include needed libaries
_neededLibraries=( "ipc/file/sigfwd.bashlib"
		   "gsatlc.bashlib" )

for _library in "${_neededLibraries[@]}"; do

	if ! . "$_LIB"/"$_library"; then
		echo "[$_program] E: Library \""$_LIB"/"$_library"\" couldn't be read or is corrupted." 1>&2
		exit $_exit_software
	fi
done


################################################################################

sendcmd/processMsg() {
        local _message="$1"

        local _answer=$( echo "$_message" | cut -d ';' -f 1 )
        local _answerBox=$( echo "$_message" | cut -d ';' -f 2 )

        if [[ $_DEBUG -eq 1 ]]; then
        	echo "[$_program] I: answer \"$_answer\" from box \"$_answerBox\"."
        else
        	echo "$_answer"
        fi

        return
}


sendcmd/usageMsg() {

        cat <<-USAGE

usage: sendcmd [--help]
       sendcmd --command command --message-box messageBox [--no-sigfwd] [--no-wait-for-answer]

--help gives more information

USAGE

        return
}

sendcmd/helpMsg() {
    
        cat <<-HELP

$( sendcmd/versionMsg )

SYNOPSIS:

sendcmd [options]

DESCRIPTION:

sendcmd is a small tool for testing message passing functionality. It receives a
possible answer via a temporary message box.

OPTIONS:

-c, --command command   Specifiy the command to send. Commands depend on the
                        specific receiver process, but the standard commands
                        are:

                        "ALIVE?"        Is the contacted process still alive?

                        "PID?"          Contacted process should return its PID.

                        "HOST?"         Contacted process should return the host
                                        it is running on.

                        "STOP"          Stop the contacted process.

-m, --message-box messageBox
                        Specify the message box to send the command to.

[--no-sigfwd]           Disable signal forwarding during send.

[--no-wait-for-answer]  Don't wait for an answer after sending a command.

[--debug]               Enable debug mode.

[--help]                Display this help and exit.

[-V, --version]         Display version information and exit.

HELP

        return
}

sendcmd/versionMsg() {

        echo "sendcmd v$_sendcmdVersion"

        return
}


#  onExit() - perform cleanup on exit.
sendcmd/onExit()
{
	#  remove message boxes
	ipc/file/removeMsgBox "$_inbox"

	return
}

################################################################################

#  setup trap to remove inbox on exit
trap 'sendcmd/onExit' EXIT

################################################################################

_noSignalForwarding=0
_noWaitForAnswer=0

#  correct number of params?
if [[ "$#" -lt "1" ]]; then
   # no, so output a usage message
   sendcmd/usageMsg
   exit 1
fi

_noWaitForAnswerSet=1
_DEBUGSet=1

# read in all parameters
while [[ "$1" != "" ]]; do

	#  only valid params used?
	#
	#  NOTICE:
	#  This was added to prevent high speed loops
	#+ if parameters are mispositioned.
	if [[   "$1" != "--help" && \
                "$1" != "--version" && "$1" != "-V" && \
                "$1" != "--command" && "$1" != "-c" && \
                "$1" != "--message-box" && "$1" != "-m" && \
                "$1" != "--no-sigfwd" && \
                "$1" != "--no-wait-for-answer" && \
                "$1" != "--debug" \
        ]]; then
		#  no, so output a usage message
		sendcmd/usageMsg
		exit $_exit_usage
	fi

	#  "--help"
	if [[ "$1" == "--help" ]]; then
		sendcmd/helpMsg
		exit $_exit_ok

	#  "--version|-V"
	elif [[ "$1" == "--version" || "$1" == "-V" ]]; then
		sendcmd/versionMsg
		exit $_exit_ok

	#  "--command|-c command"
	elif [[ "$1" == "--command" || "$1" == "-c" ]]; then
                _option="$1"
                if [[ "$_commandSet" != "0" ]]; then
	                shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _command="$1"
                                _commandSet="0"
                                shift 1
                        else
                                echo "[$_program] E: missing option parameter for \"$_option\"!" 1>&2
                                exit $_exit_usage
                        fi
                else
	                #  duplicate usage of this parameter
	                echo "[$_program] E: The parameter \"--command|-c\" cannot be used multiple times!" 1>&2
	                exit $_exit_usage
                fi

        #  "--message-box|-m messageBox"
	elif [[ "$1" == "--message-box" || "$1" == "-m" ]]; then
                _option="$1"
                if [[ "$_messageBoxSet" != "0" ]]; then
	                shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _messageBox="$1"
                                _messageBoxSet="0"
                                shift 1
                        else
                                echo "[$_program] E: missing option parameter for \"$_option\"!" 1>&2
                                exit $_exit_usage
                        fi
                else
	                #  duplicate usage of this parameter
	                echo "[$_program] E: The parameter \"--message-box|-m\" cannot be used multiple times!" 1>&2
	                exit $_exit_usage
                fi

        #  "--no-sigfwd"
	elif [[ "$1" == "--no-sigfwd" ]]; then
                _option="$1"
                if [[ "$_noSignalForwardingSet" != "0" ]]; then
                        shift 1
	                _noSignalForwarding="1"
                        _noSignalForwardingSet="0"
                else
	                #  duplicate usage of this parameter
	                echo "[$_program] E: The parameter \"--no-sigfwd\" cannot be used multiple times!" 1>&2
	                exit $_exit_usage
                fi

        #  "--no-wait-for-answer"
	elif [[ "$1" == "--no-wait-for-answer" ]]; then
                _option="$1"
                if [[ "$_noWaitForAnswerSet" != "0" ]]; then
                        shift 1
	                _noWaitForAnswer="1"
                        _noWaitForAnswerSet="0"
                else
	                #  duplicate usage of this parameter
	                echo "[$_program] E: The parameter \"--no-wait-for-answer\" cannot be used multiple times!" 1>&2
	                exit $_exit_usage
                fi

        #  "--debug"
	elif [[ "$1" == "--debug" ]]; then
                _option="$1"
                if [[ "$_DEBUGSet" != "0" ]]; then
                        shift 1
	                _DEBUG="1"
                        _DEBUGSet="0"
                else
	                #  duplicate usage of this parameter
	                echo "[$_program] E: The parameter \"--debug\" cannot be used multiple times!" 1>&2
	                exit $_exit_usage
                fi

        fi

done

#  check that all mandatory options are set
if [[ $_commandSet -eq 0 && \
      $_messageBoxSet -eq 0 \
]]; then
        #  continue to "main()"
        :
else
        sendcmd/usageMsg
        exit $_exit_usage
fi

################################################################################
#  main()
################################################################################

_self="$$"

_inboxName="$_self.inbox"

#  create inbox
_inbox=$( ipc/file/createMsgBox "$_inboxName" )

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
        [[ "$_DEBUG" == "1" ]] && echo "($$) [$_program] DEBUG: sendMsg($_command;$_inbox) successful." 1>&2
        touch -mc "$_messageBox"
        if [[ $_noSignalForwarding -eq 0 ]]; then
                #  send SIGCONT to stop&go process (sputnik)
                [[ "$_DEBUG" == "1" ]] && echo "($$) [$_program] DEBUG: before forwardSignal()." 1>&2
                ipc/file/sigfwd/forwardSignal "$_contactHostName" "$_contactPid" "SIGCONT"
                if [[ "$?" != "0" ]]; then
                    #  signal couldn't be delivered, perhaps contact is dead
                    echo "[$_program] E: Signal forwarding to contact \"$_contactPid\" on host \"$_contactHostName\" failed. Exiting." 1>&2
                    exit 1
                fi
        fi
        break
    elif [[ "$_retVal" == "1" ]]; then
        [[ "$_DEBUG" == "1" ]] && echo "($$) [$_program] DEBUG: sendMsg($_message;$_inbox) failed." 1>&2
        sleep 0.5
        continue
    elif [[ "$_retVal" == "2" ]]; then
        echo "[$_program] E: Message box \"$_messageBox\" not existing." 1>&2
        exit 1
    fi
done

#  should we wait for an answer?
if [[ $_noWaitForAnswer -eq 0 ]]; then
        #  yes
        while [[ 1 ]]; do
                #  touch it first, so changes on other hosts are propagated
                touch --no-create "$_inbox"
                if ipc/file/messageAvailable "$_inbox"; then
                        _answer=$( ipc/file/receiveMsg "$_inbox" )
                        _retVal="$?"
                        if [[ "$_retVal" == "0" ]]; then
                                [[ "$_DEBUG" == "1" ]] && echo "($$) [$_program] DEBUG: receiveMsg($_inbox) successful." 1>&2
                                break
                        else
                                [[ "$_DEBUG" == "1" ]] && echo "($$) [$_program] DEBUG: receiveMsg($_inbox) failed." 1>&2
                                sleep 0.5
                        fi
                else
                        sleep 0.5
                fi
        done

        sendcmd/processMsg "$_answer"
fi

#  no
exit

