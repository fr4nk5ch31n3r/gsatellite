#!/bin/bash

#  sigfwdd - daemon like tool to start sigfwd in the background without binding
#+ it to a tty.

_hostName=$( hostname --fqdn )

if [[ "$1" == "--start" ]]; then

        if [[ ! -e $HOME/.gsatellite/var/log/$_hostName ]]; then
                mkdir -p $HOME/.gsatellite/var/log/$_hostName
        fi

        nohup sigfwd > $HOME/.gsatellite/var/log/$_hostName/sigfwd.log 2>&1 &
        exit

elif [[ "$1" == "--stop" ]]; then

        _sigfwdPid=$( cat $HOME/.gsatellite/var/run/$_hostName/sigfwdPid )

        kill "$_sigfwdPid"

        if [[ $? -eq 0 ]]; then
                rm -f $HOME/.gsatellite/var/run/$_hostName/sigfwdPid
                exit
        else
                exit 1
        fi

else
        echo "usage: sigfwdd {--start|--stop}"
        exit 1
fi

