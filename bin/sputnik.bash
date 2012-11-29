#!/bin/bash

#  sputnik.bash - gsatellite tool (runs and controls jobs)

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

_gsatBaseDir=$HOME/.gsatellite
_gscheduleBaseDir="$_gsatBaseDir/gschedule"

################################################################################

#  child libs inherit parent lib functions
#. "$_LIB"/ipc.bashlib
#. "$_LIB"/ipc/file.bashlib
. "$_LIB/ipc/file/sigfwd.bashlib"
. "$_LIB/ipc/file/msgproc.bashlib"
. "$_LIB/utils.bashlib"
. "$_LIB/gschedule.bashlib"
 
################################################################################

#  ignore SIGINT and SIGTERM
trap 'echo "($$) DEBUG: SIGINT received." >&1' SIGINT
trap 'echo "($$) DEBUG: SIGTERM received." >&1' SIGTERM

sputnik/holdJob() {
        #  Put a hold on a job
        #
        #  usage:
        #+ sputnik/holdJob job

        local _job="$1"

        local _jobTmpDir=$( dirname "$_job" )
        
        local _jobPid=$( cat "$_jobTmpDir/../job.pid" )

	#  this information is retrieved and stored in the job's directory by
	#+ the scheduler (gsatlc)
        #local _jobType=$( cat "$_jobTmpDir/../job.type" )

	#local _holdSignal=$( sputnik/getHoldSignal "$_jobType" )
	local _holdSignal="SIGINT"
	
	#  "hold" job
	#  NOTICE: There's a "-" in front of the PID. This results in signalling
	#+ the whole process group of sputnik. All sputnik processes should
	#+ ignore SIGINT, but the children of the job child should react on
	#+ this.
	echo /bin/kill -"$_holdSignal" -"$$" >&2 #&>/dev/null
        /bin/kill -"$_holdSignal" -"$$" #&>/dev/null

        if [[ "$?" == "0" ]]; then
                return 0
        else
                return 1
        fi
        
}

sputnik/runJob() {
        #  run the gsatellite job and notify parent when it terminates.
        #
        #  usage:
        #+ sputnik/runJob job parentPid parentInbox

        local _job="$1"
        local _parentPid="$2"
        local _parentInbox="$3"

        local _jobTmpDir=$( dirname "$_job" )

	chmod +x "$_job"

        #  run job in the background to get its PID. We need its PID to be able
        #+ to interact with it with signals later.
        cd "$_jobTmpDir" && \
	$_job 1>"$_jobDir/job.stdout" 2>"$_jobDir/job.stderr" &

        local _jobPid="$!"

        #  save job's PID
        echo "$_jobPid" > "$_jobDir/job.pid"

	#  determine values for add. environment
	local _jobId="$__GLOBAL__jobId"
	local _jobDir=$( gschedule/getJobDir "$_jobId" )
	local _jobName=$( basename "$_job" )
	local _jobWorkDir="$_jobDir/jobtmp"
	local _home="$HOME"
	local _user="$USER"
	local _execHost=$( utils/getHostName )
	local _path="$PATH"

        #  create additional environment
	local _environmentFile="${_jobDir}/${_gschedule_jobEnvFileName}"

	cat > "$_environmentFile" <<-EOF
	export GSAT_JOBNAME="$_jobName"
	export GSAT_O_WORKDIR="$_jobWorkDir"
	export GSAT_O_HOME="$_home"
	export GSAT_O_LOGNAME="$_user"
	export GSAT_O_JOBID="$_jobId"
	export GSAT_O_HOST="$_execHost"
	export GSAT_O_PATH="$_path"
	EOF

	. "$_environmentFile"

        #  wait for the job to terminate
        wait "$_jobPid"

        local _jobExitValue="$?"

	#  save job's exit value
	echo "$_jobExitValue" > "$_jobDir/job.exit"

        #  no answer from the parent needed, hence no inbox provided
        local _message="TERMINATED $_jobExitValue;"

        ipc/file/sendMsg "$_parentInbox" "$_message"

        #  wakeup parent
        /bin/kill -SIGCONT $_parentPid &>/dev/null

        if [[ "$?" == "0" ]]; then
                return 0
        else
                return 1
        fi
}


#  reimplementation with if clauses, as this could allow to include
#+ functionality dynamically
processMsg() {
        local _message="$1"
        local _inbox="$2"

        local _command=""
        local _answerBox=""

        local _gsatlcHostName=$( cat "$_gsatBaseDir/gsatlcHostName" )
        local _gsatlcPid=$( cat "$_gsatBaseDir/gsatlcPid" )
        local _gsatlcMessageBox="$_MBOXES/$_gsatlcHostName/$_gsatlcPid.inbox"

        _command=$( echo "$_message" | cut -d ';' -f 1 )
        _answerBox=$( echo "$_message" | cut -d ';' -f 2 )

        #  special functionality
        if [[ "$_command" == "WAKE UP" ]]; then
                #echo "sputnik: awake!"
                return

        elif [[ "$_command" =~ ^TERMINATED.* ]]; then
                if [[ $_jobHeld -eq 0 ]]; then
                
                	#  command is "TERMINATED <EXIT_VALUE>"
                	local _jobExitValue=$( echo "$_command" | cut -d ' ' -f 2 )

		        local _gsatlcMessage="TERMINATED $__GLOBAL__jobId $_jobExitValue;$_inbox"

		        ipc/file/sendMsg "$_gsatlcMessageBox" "$_gsatlcMessage"
		        
		        local _signal="SIGCONT"

		        #  wake gsatlc with signal forwarding
		        ipc/file/sigfwd/forwardSignal "$_gsatlcHostName" "$_gsatlcPid" "$_signal"

			local _returnValue="$?"

		        if [[ $_returnValue -eq 0 ]]; then
		                exit 0
			else
		                exit 1
		        fi
		fi
		
		exit
		

        elif [[ "$_command" =~ ^HOLD$ ]]; then
                #  command is "HOLD"
                #  TODO:
                #+ Encapsulate "holding a job" in different libs depending on
                #+ the job type.

                #  Actually hold the job
                sputnik/holdJob "$_job"

                if [[ "$?" == "0" ]]; then
                        local _gsatlcMessage="OK;$_inbox"
                        _jobHeld=1
                else
                        local _gsatlcMessage="HOLD FAILED;$_inbox"
                fi

                ipc/file/sendMsg "$_answerBox" "$_gsatlcMessage"
                
                #  No wakeup needed, gsatlc is actively waiting for this answer
                #local _signal="SIGCONT"

                #  wake gsatlc with signal forwarding
                #ipc/file/sigfwd/forwardSignal "$_gsatlcHostName" "$_gsatlcPid" "$_signal"

                if [[ "$?" == "0" ]]; then
                        return 0
                else
                        return 1
                fi

        fi

        #  standard functionality for message processing
        ipc/file/msgproc/processMsg "$_message" "$_inbox"

        return
}

################################################################################

#  a gsatellite job is a shell script
_job="$1"
_jobDir="$2" #  e.g. "$_gscheduleJobsDir/$_jobId.d"
__GLOBAL__jobId="$3"

_jobHeld=0

#if [[ ! -e "$_job" ]]; then
#	exit 1
#fi

_self="$$"

_inboxName="$_self.inbox"

_message=""

#  create inbox
_inbox=$( ipc/file/createMsgBox "$_inboxName" )

#  setup trap to stop children and remove inbox on exit
trap '/bin/kill "$_wakeupChildPid" &>/dev/null; ipc/file/removeLocalMsgBoxByName "$_inboxName"' EXIT

#  wake up regularly every 10 seconds
utils/wakeUp "$_self" "10" &

#  child's PID
_wakeupChildPid="$!"

#  start job
sputnik/runJob "$_job" "$_self" "$_inbox" &

#  child's PID
_jobChildPid="$!"

#  save PID
echo "$_self" > "$_jobDir/sputnik.pid"

while [[ 1 ]]; do
        if ipc/file/messageAvailable "$_inbox"; then        
                _message=$( ipc/file/receiveMsg "$_inbox" )
                #  process message asynchronously (assumption was to speedup message
                #+ processing, but in reality the effect wasn't that impressive:
                #+ Processing 24 messages (from 24 concurrently running gsatlc, 12
                #+ gsatlc processes on each host) took about 1m30s for each host with
                #+ standard synchronous message processing and about 1m10s for each host
                #+ with asynchronous message processing.).
                #+
                #+ PROBLEM:
                #+ Stopping doesn't work anymore. It looks like the exit in processMsg()
                #+ is now done for the child and no longer for the father.
                #processMsg "$_message" &
                processMsg "$_message" "$_inbox"
        else
                #  pause execution
                #  If you need something, wake me up!
                /bin/kill -SIGSTOP "$_self"
        fi

        #echo "awake!"

done

exit

