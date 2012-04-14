#!/bin/bash

#  gsatlcd - daemon like tool to start gsatlc in the background without binding
#+ it to a tty.

nohup gsatlc > ./gsatlc.log &

exit

