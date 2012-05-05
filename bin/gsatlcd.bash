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
        exit

else
        echo "usage: gsatlcd {--start|--stop}"
        exit 1
fi

