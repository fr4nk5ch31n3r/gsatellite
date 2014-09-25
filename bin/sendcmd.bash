#!/bin/bash

# sendcmd.bash - send command test program

:<<COPYRIGHT

Copyright (C) 2011, 2012 Frank Scheiner
Copyright (C) 2013, 2014 Frank Scheiner, HLRS, Universitaet Stuttgart

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

################################################################################
# DEFINES
################################################################################

readonly _program=$( basename "$0" )

readonly _sendcmdVersion="0.4.0"

readonly _sendcmd_exit_software=70
readonly _sendcmd_exit_usage=64
readonly _sendcmd_exit_ok=0

readonly _true=1
readonly _false=0

################################################################################
# EXTERNAL VARIABLES
################################################################################

#_GSAT_DEBUG

################################################################################
# PATH CONFIGURATION
################################################################################

# path to configuration files (prefer system paths!)
# For native OS packages:
if [[ -e "/etc/gsatellite" ]]; then
        _configurationFilesPath="/etc/gsatellite"
        _installBasePath="/usr"
        _libBasePath="$_installBasePath/share"
        _libexecBasePath="$_installBasePath/libexec/gsatellite"

# For installation with "install.sh".
#sed#elif [[ -e "<PATH_TO_GSATELLITE>/etc" ]]; then
#sed#	_configurationFilesPath="<PATH_TO_GSATELLITE>/etc"

# According to FHS 2.3, configuration files for packages located in "/opt" have
# to be placed here (if you use a provider super dir below "/opt" for the
# gtransfer files, please also use the same provider super dir below
# "/etc/opt").
#elif [[ -e "/etc/opt/<PROVIDER>/gsatellite" ]]; then
#	 _configurationFilesPath="/etc/opt/<PROVIDER>/gsatellite"
#        _installBasePath="/opt/<PROVIDER>/gsatellite"
#        _libBasePath="$_installBasePath/lib"
#        _libexecBasePath="$_installBasePath/libexec"
elif [[ -e "/etc/opt/gsatellite" ]]; then
        _configurationFilesPath="/etc/opt/gsatellite"
        _installBasePath="/opt/gsatellite"
        _libBasePath="$_installBasePath/lib"
        _libexecBasePath="$_installBasePath/libexec"

# For git deploy, use $BASH_SOURCE
elif [[ -e "$( dirname $BASH_SOURCE )/../etc" ]]; then
	_configurationFilesPath="$( dirname $BASH_SOURCE )/../etc"
	_installBasePath="$( dirname $BASH_SOURCE )/../"
	_libBasePath="$_installBasePath/lib"
        _libexecBasePath="$_installBasePath/libexec"
fi

_pathsConfigurationFile="$_configurationFilesPath/paths.conf"

# include path config or fail with EX_SOFTWARE = 70, internal software error
# not related to OS
if ! . "$_pathsConfigurationFile"; then
	echo "$_program: Paths configuration file couldn't be read or is corrupted." 1>&2
	exit $_sendcmd_exit_software
fi

readonly _LIB="$_libBasePath"
readonly _GSAT_LIBEXECPATH="$_libexecBasePath"

################################################################################
# INCLUDES
################################################################################

_neededLibraries=( "gsatellite/ipc/file/sigfwd.bashlib"
		   "gsatellite/gsatlc.bashlib"
		   "gsatellite/utils.bashlib" )

for _library in "${_neededLibraries[@]}"; do

	if ! . "$_LIB"/"$_library"; then
		echo "$_program: Library \""$_LIB"/"$_library"\" couldn't be read or is corrupted." 1>&2
		exit $_sendcmd_exit_software
	fi
done


################################################################################
# FUNCTIONS
################################################################################

sendcmd/usageMsg()
{

        cat <<-USAGE
Usage: sendcmd --command command --message-box messageBox [--no-sigfwd] [--no-wait-for-answer]
Try \`$_program --help' for more information.
USAGE

        return
}


sendcmd/helpMsg()
{
    
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

[--no-sigfwd]           Disable signal forwarding during send (e.g. when
                        contacting the signal forwarder (sigfwd) itself)

[--no-wait-for-answer]  Don't wait for an answer after sending a command.

[--help]                Display this help and exit.

[-V, --version]         Display version information and exit.
HELP

        return
}


sendcmd/versionMsg()
{

        echo "$_program v$_sendcmdVersion"

        return
}


# Public: Process a received message.
#
# $1 (_message) - File (string) containing the message.
sendcmd/processMsg()
{
        local _message="$1"

        local _answer=$( echo "$_message" | cut -d ';' -f 1 )
        local _answerBox=$( echo "$_message" | cut -d ';' -f 2 )

        if [[ $_GSAT_DEBUG -eq 1 ]]; then
		echo "$_program: answer \"$_answer\" from box \"$_answerBox\"."
        else
		echo "$_answer"
        fi

        return
}


# Private: Perform cleanup on exit.
sendcmd/onExit()
{
	# remove message boxes
	ipc/file/removeMsgBox "$_inbox"

	return
}

################################################################################
# MAIN
################################################################################

# setup trap to remove inbox on exit
trap 'sendcmd/onExit' EXIT

_noSignalForwarding=$_false
_noWaitForAnswer=$_false

# correct number of params?
if [[ "$#" -lt 1 ]]; then
   # no, so output a usage message
   sendcmd/usageMsg
   exit 1
fi

# read in all parameters
while [[ "$1" != "" ]]; do

	# only valid params used?
	#
	# NOTICE:
	# This was added to prevent high speed loops
	# if parameters are mispositioned.
	if [[   "$1" != "--help" && \
                "$1" != "--version" && "$1" != "-V" && \
                "$1" != "--command" && "$1" != "-c" && \
                "$1" != "--message-box" && "$1" != "-m" && \
                "$1" != "--no-sigfwd" && \
                "$1" != "--no-wait-for-answer" \
        ]]; then
		# no, so output a usage message
		sendcmd/usageMsg
		exit $_sendcmd_exit_usage
	fi

	# "--help"
	if [[ "$1" == "--help" ]]; then
		sendcmd/helpMsg
		exit $_sendcmd_exit_ok

	# "--version|-V"
	elif [[ "$1" == "--version" || "$1" == "-V" ]]; then
		sendcmd/versionMsg
		exit $_sendcmd_exit_ok

	# "--command|-c command"
	elif [[ "$1" == "--command" || "$1" == "-c" ]]; then
                _option="$1"
                if [[ $_commandSet -ne $_true ]]; then
	                shift 1
                        # next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _command="$1"
                                _commandSet=$_true
                                shift 1
                        else
                                echo "$_program: missing option parameter for option \"$_option\"!" 1>&2
                                exit $_sendcmd_exit_usage
                        fi
                else
	                # duplicate usage of this parameter
	                echo "$_program: The option \"$_option\" cannot be used multiple times!" 1>&2
	                exit $_sendcmd_exit_usage
                fi

        # "--message-box|-m messageBox"
	elif [[ "$1" == "--message-box" || "$1" == "-m" ]]; then
                _option="$1"
                if [[ $_messageBoxSet -ne $_true ]]; then
	                shift 1
                        # next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _messageBox="$1"
                                _messageBoxSet=$_true
                                shift 1
                        else
                                echo "$_program: missing option parameter for option \"$_option\"!" 1>&2
                                exit $_sendcmd_exit_usage
                        fi
                else
	                # duplicate usage of this parameter
	                echo "$_program: The option \"$_option\" cannot be used multiple times!" 1>&2
	                exit $_sendcmd_exit_usage
                fi

        # "--no-sigfwd"
	elif [[ "$1" == "--no-sigfwd" ]]; then
                _option="$1"
                if [[ $_noSignalForwardingSet -ne $_true ]]; then
                        shift 1
	                _noSignalForwarding=$_true
                        _noSignalForwardingSet=$_true
                else
	                # duplicate usage of this parameter
	                echo "$_program: The option \"$_option\" cannot be used multiple times!" 1>&2
	                exit $_sendcmd_exit_usage
                fi

        # "--no-wait-for-answer"
	elif [[ "$1" == "--no-wait-for-answer" ]]; then
                _option="$1"
                if [[ $_noWaitForAnswerSet -ne $_true ]]; then
                        shift 1
	                _noWaitForAnswer=$_true
                        _noWaitForAnswerSet=$_true
                else
	                # duplicate usage of this parameter
	                echo "$_program: The option \"$_option\" cannot be used multiple times!" 1>&2
	                exit $_sendcmd_exit_usage
                fi
        fi

done

# check that all mandatory options are set
if [[ $_commandSet -eq $_true && \
      $_messageBoxSet -eq $_true \
]]; then
        # continue
        :
else
        sendcmd/usageMsg
        exit $_sendcmd_exit_usage
fi

_self="$$"

_inboxName="$_self.inbox"

# create inbox
_inbox=$( ipc/file/createMsgBox "$_inboxName" )

_contactHostName="$( ipc/file/getHostNameForMsgBox $_messageBox )"
_contactPid="$( ipc/file/getPidForMsgBox $_messageBox )"


while [[ 1 ]]; do
	# TODO:
	# Improve message format to also include an id, that could be used to
	# identify answers to specific messages. This could be needed if answers
	# come in asynchronously.
	#
	# new format:
	# "$_message;$_inbox;$_id"
	ipc/file/sendMsg "$_messageBox" "$_command;$_inbox"
	_retVal=$?

	if [[ $_retVal -eq 0 ]]; then

		utils/debugEcho "$_program: sendMsg($_command;$_inbox) successful."
		touch -mc "$_messageBox"

		if [[ $_noSignalForwarding -ne $_true ]]; then

			# send SIGCONT to stop&go process (sputnik)
			utils/debugEcho "$_program: before forwardSignal()."
			ipc/file/sigfwd/forwardSignal "$_contactHostName" "$_contactPid" "SIGCONT"

			if [[ $? -ne 0 ]]; then

				# signal couldn't be delivered, perhaps contact is dead
				echo "$_program: Signal forwarding to contact \"$_contactPid\" on host \"$_contactHostName\" failed. Exiting." 1>&2
				exit 1
			fi
		fi
		break

	elif [[ $_retVal -eq 1 ]]; then

		utils/debugEcho "$_program: sendMsg($_message;$_inbox) failed."
		sleep 0.5
		continue

	elif [[ $_retVal -eq 2 ]]; then

		echo "$_program: Message box \"$_messageBox\" not existing." 1>&2
		exit 1
	fi
done

# should we wait for an answer?
if [[ $_noWaitForAnswer -ne $_true ]]; then

        # yes
        while [[ 1 ]]; do

                # touch it first, so changes on other hosts are propagated
                touch --no-create "$_inbox"

                if ipc/file/messageAvailable "$_inbox"; then

                        _answer=$( ipc/file/receiveMsg "$_inbox" )
                        _retVal=$?

                        if [[ $_retVal -eq 0 ]]; then

                                utils/debugEcho "$_program: receiveMsg($_inbox) successful."
                                break
                        else
                                utils/debugEcho "$_program: receiveMsg($_inbox) failed."
                                sleep 0.5
                        fi
                else
                        sleep 0.5
                fi
        done

        sendcmd/processMsg "$_answer"
fi

# no
exit

