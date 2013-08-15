#!/bin/bash

#  gqstat - gqstat implementation as separate program with additional
#+ functionality

:<<COPYRIGHT

Copyright (C) 2013 Frank Scheiner
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

_gsatBaseDir=$HOME/.gsatellite
_gscheduleBaseDir="$_gsatBaseDir/gschedule"
_gqstatVersion="0.1.0"


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


#  include needed libaries
_neededLibraries=( "gschedule.bashlib"
		   "utils.bashlib" )

for _library in "${_neededLibraries[@]}"; do

	if ! . "$_LIB"/"$_library"; then
		echo "($_program) E: Library \""$_LIB"/"$_library"\" couldn't be read or is corrupted." 1>&2
		exit 70
	fi
done

################################################################################


gqstat/usageMsg()
{

    cat <<-USAGE

usage: gqstat [-f [jobId]] [-s jobState]

--help gives more information

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


gqstat/listJobsInState()
{
        #  list gsatellite jobs in specified state
        #
        #  usage:
        #+ gqstat/listJobsInState jobState

        local _jobState="$1"

        #  right-bound text ouptut (default!)
        printf "%12s\t%12s\t%12s\t%12s\n" "job.state" "job.id" "job.execHost" "job.name"
        echo -e "------------\t------------\t------------\t------------"

        for _jobDir in $( ls -1 "$_gscheduleBaseDir/$_jobState" ); do

                #echo "($$) DEBUG: _jobDir=\"$_jobDir\""

                local _jobId=$( basename "$_gscheduleBaseDir/$_jobState/$_jobDir" )
                _jobId=${_jobId%.d}
                local _jobHost=$( cat "$_gscheduleBaseDir/jobs/$_jobDir/job.execHost" 2>/dev/null )
                local _jobName=$( basename $( readlink "$_gscheduleBaseDir/$_jobState/$_jobDir/$_jobId" ) )

                #  left-bound text output ("-"!)
                printf '%-12s\t%-12s\t%-12s\t%-12s\n' "$_jobState" "$_jobId" "$_jobHost" "$_jobName" #>> tmpfile

        done

        if [[ -e tmpfile ]]; then
                cat tmpfile && rm tmpfile
        fi

        return
}


gqstat/listAllJobs()
{
        #  list all gsatellite jobs
        #
        #  usage:
        #+ gsatlc/listAllJobs

        #  perhaps locking needed before listing?

        #  right-bound text ouptut (default!)
        printf "%12s\t%12s\t%12s\t%12s\n" "job.state" "job.id" "job.execHost" "job.name"
        echo -e "------------\t------------\t------------\t------------"

        for _jobDir in $( ls -1 "$_gscheduleBaseDir/jobs" ); do

                #echo "($$) DEBUG: _jobDir=\"$_jobDir\""

                local _jobId=$( basename "$_gscheduleBaseDir/jobs/$_jobDir" )
                _jobId=${_jobId%.d}
                local _jobState=$( cat "$_gscheduleBaseDir/jobs/$_jobDir/job.state" 2>/dev/null )
                local _jobHost=$( cat "$_gscheduleBaseDir/jobs/$_jobDir/job.execHost" 2>/dev/null )
                local _jobName=$( basename $( readlink "$_gscheduleBaseDir/jobs/$_jobDir/$_jobId" ) )

                #  left-bound text output ("-"!)
                printf '%-12s\t%-12s\t%-12s\t%-12s\n' "$_jobState" "$_jobId" "$_jobHost" "$_jobName" #>> tmpfile

        done

        if [[ -e tmpfile ]]; then
                cat tmpfile && rm tmpfile
        fi

        return
}



gqstat/listJobDetailed()
{
	local _jobId="$1"
	
	local _jobDir=$( gschedule/getJobDir "$_jobId" )
	
	for _jobAttribute in "${__GLOBAL__jobAttributes[@]}"; do
	
		_jobAttributeFile="$_jobDir/$_jobAttribute"
	
		if [[ -s "$_jobAttributeFile" ]]; then
	
			#  NOTICE: Command substitution removes trailing newlines
			echo "${_jobAttribute}=\"$( cat "$_jobAttributeFile" )\"" 
	
		elif [[ "$_jobAttribute" == "job.dir" &&\
		        "$_jobDir" != "" \
		]]; then
			echo "${_jobAttribute}=\"$_jobDir\""
		fi
	done
	
	return
}


gqstat/getJobIds()
{
	local _jobState="$1"

	if [[ "$_jobState" == "" ]]; then
		cd "$_gscheduleBaseDir/jobs"
	else
		cd "$_gscheduleBaseDir/$_jobState"
	fi

	for _jobDir in *.d; do
		#  Break for loop if directory is empty
		if [[ "$_jobDir" == "*.d" ]]; then
			break
		fi
		local _jobId=${_jobDir%.d}
		echo "$_jobId"
	done

	return
}


gqstat/listAllJobsDetailed()
{
	for _jobId in $( gqstat/getJobIds ); do
		gqstat/listJobDetailed "$_jobId"
		#  separate jobs by an empty line
		echo ""
	done
	
	return	
}


gqstat/listJobsInStateDetailed()
{
	local _jobState="$1"
	local _jobId="$2"

	for _specificJobId in $( gqstat/getJobIds "$_jobState" ); do
		if [[ "$_jobId" == "" || \
		      "$_specificJobId" == "$_jobId" \
		]]; then
			gqstat/listJobDetailed "$_specificJobId"
			#  separate jobs by an empty line
			echo ""
		fi			
	done
	
	return	
}



gqstat/getJobAttribute()
{
	local _jobId="$1"
	local _jobAttribute="$2"
	
	for _attribute in "${__GLOBAL_jobAttributes[@]}"; do
		if [[ "$_jobAttribute" == "$_attribute" ]]; then
			cat "$( gschedule/getJobDir "$_jobId")/$_jobAttribute" || return 1
			return 0
		fi
	done			

	#  unknown job attribute
	return 1	
}


gqstat/qstat()
{
        #  show info about jobs
        #
        #  usage:
        #+ gsatctl/qstat [jobState]
        local _jobState="$1"

        if [[ "$_jobState" == "" ]]; then
                gsatctl/listAllJobs
        elif [[ "$_jobState" == "ready" || \
                "$_jobState" == "running" || \
                "$_jobState" == "finished" || \
                "$_jobState" == "failed" ]]; then
                gsatctl/listJobsInState "$_jobState"
        else
                return 1
        fi

        return    

}

################################################################################

#  Defaults:
_mode="list"

#  correct number of params?
#if [[ "$#" -lt "1" ]]; then
#   # no, so output a usage message
#   gqstat/usageMsg
#   exit $_gqstat_exit_usage
#fi

# read in all parameters
while [[ "$1" != "" ]]; do

	#  only valid params used?
	#
	#  NOTICE:
	#  This was added to prevent high speed loops
	#+ if parameters are mispositioned.
	if [[   "$1" != "--help" && \
                "$1" != "--version" && "$1" != "-V" && \
                "$1" != "-f" && "$1" != "--detailed-listing" && \
                "$1" != "-s" && "$1" != "--job-state" \
        ]]; then
		#  no, so output a usage message
		gqstat/usageMsg
		exit $_gqstat_exit_usage
	fi

	#  "--help"
	if [[ "$1" == "--help" ]]; then
		gqstat/helpMsg
		exit $_gqstat_exit_ok

	#  "--version|-V"
	elif [[ "$1" == "--version" || "$1" == "-V" ]]; then
		gqstat/versionMsg
		exit $_gqstat_exit_ok

        #  "-f"
        elif [[ "$1" == "-f" || "$1" == "--detailed-listing" ]]; then
                _option="$1"
		_mode="listDetailed"
                if [[ "$_jobIdSet" != "$_true" ]]; then
                        shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobId="$1"
                                _jobIdSet="$_true"
                                shift 1
                        fi
                else
                        #  duplicate usage of this parameter
                        echo "[$_program] E: The option \"$_option\" cannot be used multiple times!" 1>&2
                        exit $_gqstat_exit_usage
                fi

        #  "-s"
        elif [[ "$1" == "-s" || "$1" == "--job-state" ]]; then
                _option="$1"
                if [[ "$_jobStateSet" != "$_true" ]]; then
                        shift 1
                        #  next positional parameter an option or an option parameter?
                        if [[ ! "$1" =~ ^-.* && "$1" != "" ]]; then
                                _jobState="$1"
                                _jobStateSet="$_true"
                                shift 1
                        else
				echo "[$_program] E: Missing argument for option \"$_option\"!" 1>&2
				gqstat/usageMsg
				exit $_gqstat_exit_usage
                        fi

                else
                        #  duplicate usage of this parameter
                        echo "[$_program] E: The option \"$_option\" cannot be used multiple times!" 1>&2
                        exit $_gqstat_exit_usage
                fi
	fi

done


if [[ "$_mode" == "list" ]]; then

	if [[ "$_jobStateSet" == "$_true" ]]; then
		gqstat/listJobsInState "$_jobState"
	else
		gqstat/listAllJobs
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

