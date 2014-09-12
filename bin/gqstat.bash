#!/bin/bash

# gqstat - gqstat implementation as separate program with additional
# functionality

:<<COPYRIGHT

Copyright (C) 2013 Frank Scheiner
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

_DEBUG="0"

readonly _program=$( basename "$0" )
readonly _gqstatVersion="0.2.0"

readonly _gqstat_exit_usage=64
readonly _gqstat_exit_ok=0

readonly _true=1
readonly _false=0

readonly __GLOBAL__jobAttributes=( "job.id"
				   "job.name"
				   "job.dir"
				   "job.state"
                                   "job.execHost"
                                   "job.pid"
                                   "job.start"
                                   "job.stop" )

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
if ! . "$_pathsConfigurationFile"; then
	echo "$_program: Paths configuration file \"$_pathsConfigurationFile\" couldn't be read or is corrupted." 1>&2
	exit 70
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
		exit 70
	fi
done

################################################################################
# FUNCTIONS
################################################################################

gqstat/usageMsg()
{

	cat >&2 <<-USAGE
	Usage: $_program [-f [jobId]] [-s jobState]
	Try \`$_program --help' for more information.
	USAGE

	return
}


gqstat/helpMsg()
{
    
	cat <<-HELP
	$( gqstat/versionMsg )

	SYNOPSIS:

	gqstat [options]

	DESCRIPTION:

	gqstat is part of the user interface to gsatellite. It provides status and
	general information about gsatellite jobs.

	OPTIONS:

	[-f, --detailed-listing [jobId]]
	                        List all available information about jobs or about a
	                        specific job if a job id is given.

	[-s, --job-state jobState]
	                        Filter listing by given job state.

	[-V, --version]         Display version information and exit.

	Without arguments gqstat prints general information about all jobs.
	HELP

	return
}


gqstat/versionMsg()
{

        echo "gqstat v$_gqstatVersion"

        return
}





# Public: Provide detailed listing for a job. This includes all attributes
#         listed in $__GLOBAL__jobAttributes.
#
# $1 (_jobId) - Id (number) of the job.
#
# Returns 0 on success.
gqstat/listJobDetailed()
{
	local _jobId="$1"
	
	local _jobDir=$( gschedule/getJobDir "$_jobId" )
	
	for _jobAttribute in "${__GLOBAL__jobAttributes[@]}"; do
	
		_jobAttributeFile="$_jobDir/$_jobAttribute"
	
		if [[ -s "$_jobAttributeFile" ]]; then
	
			# NOTICE: Command substitution removes trailing newlines
			echo "${_jobAttribute}=\"$( cat "$_jobAttributeFile" )\"" 
	
		elif [[ "$_jobAttribute" == "job.dir" &&\
		        "$_jobDir" != "" \
		]]; then
			echo "${_jobAttribute}=\"$_jobDir\""
		fi
	done
	
	return
}


# Private: Get all job ids with given job state.
#
# $1 (_jobState) - Desired job state (string)
#
# Returns 0 on success.
gqstat/getJobIds()
{
	local _jobState="$1"

	if [[ "$_jobState" == "" ]]; then
		cd "$_gscheduleBaseDir/jobs"
	else
		cd "$_gscheduleBaseDir/$_jobState"
	fi

	for _jobDir in *.d; do
		# Break for loop if directory is empty
		if [[ "$_jobDir" == "*.d" ]]; then
			break
		fi
		local _jobId=${_jobDir%.d}
		echo "$_jobId"
	done

	return
}


# Public: Provide detailed listing for all jobs. This includes all attributes
#         listed in $__GLOBAL__jobAttributes.
#
# Returns 0 on success.
gqstat/listAllJobsDetailed()
{
	for _jobId in $( gqstat/getJobIds ); do
		gqstat/listJobDetailed "$_jobId"
		# separate jobs by an empty line
		echo ""
	done
	
	return	
}


# Public: Provide detailed listing for all jobs with given job state. This
#         includes all attributes listed in $__GLOBAL__jobAttributes.
#
# Returns 0 on success.
gqstat/listJobsInStateDetailed()
{
	local _jobState="$1"
	local _jobId="$2"

	for _specificJobId in $( gqstat/getJobIds "$_jobState" ); do
		if [[ "$_jobId" == "" || \
		      "$_specificJobId" == "$_jobId" \
		]]; then
			gqstat/listJobDetailed "$_specificJobId"
			# separate jobs by an empty line
			echo ""
		fi			
	done
	
	return	
}


# Private: Get value of given job attribute for given job id.
#
# $1 (_jobId) - Id (number) of the job.
# $2 (_jobAttribute) - Job attribute (string).
#
# Returns 0 on success, 1 otherwise.
gqstat/getJobAttributeValue()
{
	local _jobId="$1"
	local _jobAttribute="$2"
	
	for _attribute in "${__GLOBAL_jobAttributes[@]}"; do
		if [[ "$_jobAttribute" == "$_attribute" ]]; then
			cat "$( gschedule/getJobDir "$_jobId")/$_jobAttribute" 2>/dev/null || return 1
			return 0
		fi
	done			

	# unknown job attribute
	return 1	
}

################################################################################
# MAIN
################################################################################

# Defaults:
_mode="list"

# read in all parameters
while [[ "$1" != "" ]]; do

	# only valid params used?
	#
	# NOTICE:
	# This was added to prevent high speed loops if parameters are
	# mispositioned.
	if [[   "$1" != "--help" && \
                "$1" != "--version" && "$1" != "-V" && \
                "$1" != "-f" && "$1" != "--detailed-listing" && \
                "$1" != "-s" && "$1" != "--job-state" \
        ]]; then
		# no, so output a usage message
		gqstat/usageMsg
		exit $_gqstat_exit_usage
	fi

	# "--help"
	if [[ "$1" == "--help" ]]; then
		gqstat/helpMsg
		exit $_gqstat_exit_ok

	# "--version|-V"
	elif [[ "$1" == "--version" || "$1" == "-V" ]]; then
		gqstat/versionMsg
		exit $_gqstat_exit_ok

        # "-f"
        elif [[ "$1" == "-f" || "$1" == "--detailed-listing" ]]; then
                _option="$1"
		_mode="listDetailed"
                if [[ "$_jobIdSet" != "$_true" ]]; then
                        shift 1
                        # next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobId="$1"
                                _jobIdSet="$_true"
                                shift 1
                        fi
                else
                        # duplicate usage of this parameter
                        echo "$_program: The option \"$_option\" cannot be used multiple times!" 1>&2
                        gqstat/usageMsg
                        exit $_gqstat_exit_usage
                fi

        # "-s"
        elif [[ "$1" == "-s" || "$1" == "--job-state" ]]; then
                _option="$1"
                if [[ "$_jobStateSet" != "$_true" ]]; then
                        shift 1
                        # next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobState="$1"
                                _jobStateSet="$_true"
                                shift 1
                        else
				echo "$_program: Missing argument for option \"$_option\"!" 1>&2
				gqstat/usageMsg
				exit $_gqstat_exit_usage
                        fi

                else
                        # duplicate usage of this parameter
                        echo "$_program: The option \"$_option\" cannot be used multiple times!" 1>&2
                        gqstat/usageMsg
                        exit $_gqstat_exit_usage
                fi
	fi

done


if [[ "$_mode" == "list" ]]; then

	if [[ "$_jobStateSet" == "$_true" ]]; then
		gsatellite/interface/qstat "$_jobState"
	else
		gsatellite/interface/qstat "all"
	fi

elif [[ "$_mode" == "listDetailed" ]]; then

	if [[ "$_jobStateSet" == "$_true" && \
	      "$_jobIdSet" == "$_true" \
	]]; then
		gqstat/listJobsInStateDetailed "$_jobState" "$_jobId"
		
	elif [[ "$_jobStateSet" == "$_true" && \
	        "$_jobIdSet" != "$_true" \
	]]; then
		gqstat/listJobsInStateDetailed "$_jobState"
		
	elif [[ "$_jobStateSet" != "$_true" && \
	        "$_jobIdSet" == "$_true" \
	]]; then
		gqstat/listJobDetailed "$_jobId"
	
	elif [[ "$_jobStateSet" != "$_true" && \
	        "$_jobIdSet" != "$_true" \
	]]; then
		gqstat/listAllJobsDetailed
	fi
fi

exit

