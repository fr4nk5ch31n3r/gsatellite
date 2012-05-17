#!/bin/bash

#  sputnikd - daemon like tool to start sputnik in the background without
#+ binding it to a tty.

nohup sputnik "$@" &>/dev/null &

exit

