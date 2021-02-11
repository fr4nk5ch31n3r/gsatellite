#!/bin/bash

# gqsig - send signal to gsatellite job

:<<COPYRIGHT

Copyright (C) 2015, 2021 Frank Scheiner, HLRS, Universitaet Stuttgart

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

_DEBUG="0"

readonly _program=$( basename "$0" )
readonly _gqsigVersion="0.1.0"
readonly _gqsig_defaultSignal="SIGTERM"

# see `/usr/include/sysexits.h`
readonly _exit_ok=0
readonly _exit_usage=64
readonly _exit_unavailable=69
readonly _exit_software=70

readonly _true=1
readonly _false=0


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
# gtransfer files, please also use the same provider super dir below "/etc/opt".
#elif [[ -e "/etc/opt/<PROVIDER>/gsatellite" ]]; then
#	_configurationFilesPath="/etc/opt/<PROVIDER>/gsatellite"
#	_configurationFilesPath="/etc/opt/<PROVIDER>/gsatellite"
#	_installBasePath="/opt/<PROVIDER>/gsatellite"
#	_libBasePath="$_installBasePath/lib"
#	_libexecBasePath="$_installBasePath/libexec"
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

# include path config or fail with EX_SOFTWARE = 70, internal software error not
# related to OS
if ! . "$_pathsConfigurationFile" 2>/dev/null; then
	echo "$_program: Paths configuration file \"$_pathsConfigurationFile\" couldn't be read or is corrupted." 1>&2
	exit $_exit_software
fi

readonly _LIB="$_libBasePath"
readonly _GSAT_LIBEXECPATH="$_libexecBasePath"

################################################################################

_gsatBaseDir="$HOME/.gsatellite"
_gscheduleBaseDir="$_gsatBaseDir/gschedule"

################################################################################
# INCLUDES
################################################################################

_neededLibraries=( "gsatellite/interface.bashlib"
		    "gsatellite/gschedule.bashlib"
		    "gsatellite/utils.bashlib" )

for _library in "${_neededLibraries[@]}"; do

	if ! . "$_LIB"/"$_library" 2>/dev/null; then
		echo "$_program: Library \""$_LIB"/"$_library"\" couldn't be read or is corrupted." 1>&2
		exit $_exit_software
	fi
done

################################################################################
# FUNCTIONS
################################################################################

gqsig/usageMsg()
{

	cat >&2 <<-USAGE
	Usage: $_program [-s signal] jobId
	Try \`$_program --help' for more information.
	USAGE

	return
}


gqsig/helpMsg()
{
    
	cat <<-HELP
	$( gqsig/versionMsg )

	SYNOPSIS:

	gqsig [options] jobId

	DESCRIPTION:

	gqsig is part of the user interface of gsatellite. It allows to send a
	signal to a gsatellite job identified by its job Id. jobId always has to
	be the last parameter to gqsig!

	OPTIONS:

	[-s, --signal signal]	Send given signal to gsatellite job with the
	                       given job Id. If not used, send SIGTERM to
	                       gsatellite job.

	[-V, --version]        Display version information and exit.
	HELP

	return
}


gqsig/versionMsg()
{

        echo "gqsig v$_gqsigVersion"

        return
}


################################################################################
# MAIN
################################################################################

# Defaults:
_signal="$_gqsig_defaultSignal"

# read in all parameters
while [[ "$1" != "" ]]; do

	# If it's not an option...
	if [[   "$1" != "--help" && \
                "$1" != "--version" && "$1" != "-V" && \
                "$1" != "-s" && "$1" != "--signal" \
        ]]; then
        # ...then it has to be the job id.
        	_jobId="$1"
        	_jobIdSet=$_true
        	break
	fi

	# "--help" #############################################################
	if [[ "$1" == "--help" ]]; then
		gqsig/helpMsg
		exit $_exit_ok

	# "--version|-V" #######################################################
	elif [[ "$1" == "--version" || "$1" == "-V" ]]; then
		gqsig/versionMsg
		exit $_exit_ok

        # "-s|--signal" ########################################################
        elif [[ "$1" == "-s" || "$1" == "--signal" ]]; then
                _option="$1"
                if [[ "$_signalSet" != "$_true" ]]; then
                        shift 1
                        # next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _signal="$1"
                                _signalSet=$_true
                                shift 1
                        else
				echo "$_program: Missing argument for option \"$_option\"!" 1>&2
				gqsig/usageMsg
				exit $_exit_usage
                        fi

                else
                        # duplicate usage of this parameter
                        echo "$_program: The option \"$_option\" cannot be used multiple times!" 1>&2
                        gqsig/usageMsg
                        exit $_exit_usage
                fi
        ########################################################################
	fi

done

if gsatellite/interface/compRunning "gsatlc"; then

	if [[ $_jobIdSet == $_true ]]; then

		if gschedule/isRunningJob "$_jobId"; then
			gsatellite/interface/qsig "$_signal" "$_jobId"
			exit
		else
			echo "$_program: The job with job id \"$_jobId\" is not running. Exiting." 1>&2
			exit 1
		fi
	else
		echo "$_program: Missing job id. Cannot continue." 1>&2
		gqsig/usageMsg
		exit $_exit_usage 
	fi
else
	echo "$_program: gsatlc is not running. Start it with \`gsatlcd --start'." 1>&2
	exit $_exit_unavailable
fi



