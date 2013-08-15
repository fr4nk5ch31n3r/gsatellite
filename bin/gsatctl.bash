#!/bin/bash

#  gsatctl - gsatellite controller (user interface for gsatellite)

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

umask 0077

_DEBUG="0"

readonly _program=$( basename "$0" )
readonly _gsatctlVersion="0.2.0"

readonly _gsatellite_libraryPrefix="gsatellite"

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

################################################################################

# include needed libaries
_neededLibraries=(
"${_gsatellite_libraryPrefix}/interface.bashlib"
)

for _library in ${_neededLibraries[@]}; do

	if ! . "$_LIB"/"$_library"; then
		echo "($_program) E: Library \""$_LIB"/"$_library"\" couldn't be read or is corrupted." 1>&2
		exit 70
	fi
done

################################################################################

#_gsatBaseDir=$HOME/.gsatellite
#_gscheduleBaseDir="$_gsatBaseDir/gschedule"


################################################################################

gsatctl/usageMsg() {

    cat <<-USAGE

usage: gsatctl [--help]
       gsatctl --qsub jobFile
       gsatctl --qhold jobId
       gsatctl --qrls jobId
       gsatctl --qdel jobId
       gsatctl --qstat [jobState]

--help gives more information

USAGE

    return
}


gsatctl/helpMsg() {
    
    cat <<-HELP

$( gsatctl/versionMsg )

SYNOPSIS:

gsatctl [options]

DESCRIPTION:

gsatctl - the gsatellite controller - is the user interface to gsatellite. It
allows for job submission and manipulation. It can also show information about
all gsatellite jobs.

OPTIONS:

-s, --qsub jobFile      Submit a job to gsatellite.

-h, --qhold jobId       Hold a job identified by its job id.

-r, --qrls jobId        Release a hold from a job identified by its job id.

-d, --qdel jobId        Remove a job identified by its job id from gsatellite.
                        This only works for jobs that are not already in the
                        running state.

-l, --qstat [jobState]  List all jobs which are in the state jobState, or if
                        jobState is not provided, list all jobs.

-w, --qwait jobId       Wait for the job specified by its job id to exit and
                        return its exit value.

[--help]                Display this help and exit.

[-V, --version]         Display version information and exit.

SHORTHANDS

gqsub jobFile
qghold jobId
gqrls jobId
gqdel jobId
gqstat [jobState]
gqwait jobId

HELP

    return
}

gsatctl/versionMsg() {

        echo "$_program v$_gsatctlVersion"

        return
}

################################################################################

case $( basename "$0" ) in
        "gqstat")
                exec gsatctl --qstat "$@"
                ;;

        "gqhold")
                exec gsatctl --qhold "$@"
                ;;

        "gqrls")
                exec gsatctl --qrls "$@"
                ;;

        "gqsub")
                exec gsatctl --qsub "$@"
                ;;

        "gqdel")
                exec gsatctl --qdel "$@"
                ;;

        "gqwait")
                exec gsatctl --qwait "$@"
                ;;
        *)
                :
                ;;
esac

#  correct number of params?
if [[ "$#" -lt "1" ]]; then
   # no, so output a usage message
   gsatctl/usageMsg
   exit 1
fi

# read in all parameters
while [[ "$1" != "" ]]; do

	#  only valid params used?
	#
	#  NOTICE:
	#  This was added to prevent high speed loops
	#+ if parameters are mispositioned.
	if [[   "$1" != "--help" && \
                "$1" != "--version" && "$1" != "-V" && \
                "$1" != "--qsub" && "$1" != "-s" && \
                "$1" != "--qhold" && "$1" != "-h" && \
                "$1" != "--qrls" && "$1" != "-r" && \
                "$1" != "--qdel" && "$1" != "-d" && \
                "$1" != "--qstat" && "$1" != "-l" && \
                "$1" != "--qwait" && "$1" != "-w" \
        ]]; then
		#  no, so output a usage message
		gsatctl/usageMsg
		exit 1   
	fi

	#  "--help"
	if [[ "$1" == "--help" ]]; then
		gsatctl/helpMsg
		exit 0

	#  "--version|-V"
	elif [[ "$1" == "--version" || "$1" == "-V" ]]; then
		gsatctl/versionMsg
		exit 0

	#  "--qsub|-s job"
	elif [[ "$1" == "--qsub" || "$1" == "-s" ]]; then
                _option="$1"
                if [[ "$_jobSet" != "0" ]]; then
	                shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _job="$1"
                                _jobSet="0"
                                shift 1
                        else
                                echo "E: missing option parameter for \"$_option\"!"
                                exit 1
                        fi

                        gsat/qsub "$_job"
                        exit
                else
	                #  duplicate usage of this parameter
	                echo "ERROR: The option \"$_option\" cannot be used multiple times!"
	                exit 1
                fi

        #  "--qdel|-d jobId"
        elif [[ "$1" == "--qdel" || "$1" == "-d" ]]; then
                _option="$1"
                if [[ "$_jobIdSet" != "0" ]]; then
	                shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobId="$1"
                                _jobIdSet="0"
                                shift 1
                        else
                                echo "E: missing option parameter for \"$_option\"!"
                                exit 1
                        fi

                        gsat/qdel "$_jobId"
                        exit
                else
	                #  duplicate usage of this parameter
	                echo "ERROR: The option \"$_option\" cannot be used multiple times!"
	                exit 1
                fi

        #  "--qstat|-l [jobState]"
        elif [[ "$1" == "--qstat" || "$1" == "-l" ]]; then
                _option="$1"
                if [[ "$_jobStateSet" != "0" ]]; then
                        shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobState="$1"
                                _jobStateSet="0"
                                shift 1
                        else
                                _jobState="all"
                                _jobStateSet="0"
                        fi

                        gsat/qstat "$_jobState"
                        exit
                else
                        #  duplicate usage of this parameter
                        echo "ERROR: The option \"$_option\" cannot be used multiple times!"
                        exit 1
                fi

        #  "--qhold|-h jobId"
        elif [[ "$1" == "--qhold" || "$1" == "-h" ]]; then
                _option="$1"
                if [[ "$_jobIdSet" != "0" ]]; then
                        shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobId="$1"
                                _jobIdSet="0"
                                shift 1
                        else
                                echo "E: missing option parameter for \"$_option\"!"
                                exit 1
                        fi

                        gsat/qhold "$_jobId"
                        exit
                else
                        #  duplicate usage of this parameter
                        echo "ERROR: The option \"$_option\" cannot be used multiple times!"
                        exit 1
                fi

        #  "--qrls|-r jobId"
        elif [[ "$1" == "--qrls" || "$1" == "-r" ]]; then
                _option="$1"
                if [[ "$_jobIdSet" != "0" ]]; then
                        shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobId="$1"
                                _jobIdSet="0"
                                shift 1
                        else
                                echo "E: missing option parameter for \"$_option\"!"
                                exit 1
                        fi

                        gsat/qrls "$_jobId"
                        exit
                else
                        #  duplicate usage of this parameter
                        echo "ERROR: The option \"$_option\" cannot be used multiple times!"
                        exit 1
                fi

        #  "--qwait|-w jobId"
        elif [[ "$1" == "--qwait" || "$1" == "-w" ]]; then
                _option="$1"
                if [[ "$_jobIdSet" != "0" ]]; then
                        shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobId="$1"
                                _jobIdSet="0"
                                shift 1
                        else
                                echo "E: missing option parameter for \"$_option\"!"
                                exit 1
                        fi

                        echo "Sorry, function is not available yet!"
                        #gsat/qwait "$_jobId"
                        exit
                else
                        #  duplicate usage of this parameter
                        echo "ERROR: The option \"$_option\" cannot be used multiple times!"
                        exit 1
                fi

        fi

done

exit

