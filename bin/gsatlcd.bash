#!/bin/bash

#  gsatlcd - daemon like tool to start gsatlc in the background without binding
#+ it to a tty.

if [[ "$1" == "--start" ]]; then

        if [[ ! -e $HOME/.gsatellite/var/log ]]; then
                mkdir -p $HOME/.gsatellite/var/log
        fi

        nohup gsatlc > $HOME/.gsatellite/var/log/gsatlc.log 2>&1 &
        exit

elif [[ "$1" == "--stop" ]]; then

        _gsatlcPid=$( cat $HOME/.gsatellite/gsatlcPid )

        kill "$_gsatlcPid" && kill -SIGCONT "$_gsatlcPid"

        if [[ $? -eq 0 ]]; then
                rm -f $HOME/.gsatellite/gsatlcPid $HOME/.gsatellite/gsatlcHostName
                exit
        else
                exit 1
        fi
        
elif [[ "$1" == "--status" ]]; then

	_gsatlcHostName=$( cat $HOME/.gsatellite/gsatlcHostName 2>/dev/null )
	_gsatlcPid=$( cat $HOME/.gsatellite/gsatlcPid 2>/dev/null )
	
	if [[ "$_gsatlcHostName" != "" && \
              "$_gsatlcPid" != "" ]]; then

		echo "gsatlc hostname=\"$_gsatlcHostName\""
		echo "gsatlc PID=\"$_gsatlcPid\""

		exit 0
	else
		exit 1
	fi
else
        echo "usage: gsatlcd {--start|--stop|--status}"
        exit 1
fi

