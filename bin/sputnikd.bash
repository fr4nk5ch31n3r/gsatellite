#!/bin/bash

#  sputnikd - daemon like tool to start sputnik in the background without
#+ binding it to a tty.

#nohup sputnik "$@" &>/dev/null &

# start a new session for every sputnik, so the sputnik is the session leader.
nohup setsid sputnik "$@" &>$HOME/.gsatellite/var/log/$( hostname --fqdn )/$$_sputnik.log &

exit

