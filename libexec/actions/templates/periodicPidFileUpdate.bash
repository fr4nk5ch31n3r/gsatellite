#!/bin/bash

# periodicPidFileUpdate - Updates a PID file's timestamps as long as the process
# identified by the contained PID is still running.

_period="<PERIOD_IN_SECONDS>"

################################################################################
__action()
{
	local _pidFile="<PID_FILE>"

	local _pid=$( cat "$_pidFile" )
	
	if kill -0 $_pid &>/dev/null; then

		touch -m "$_pidFile"
		return
	else
		return 1
	fi	
}
################################################################################

if [[ $_period != 0 ]]; then
	while [[ 1 ]]; do

		__action

		if [[ $? == 0 ]]; then
			sleep $_period
		else
			exit 1
		fi
	done
else
	__action
fi

exit

