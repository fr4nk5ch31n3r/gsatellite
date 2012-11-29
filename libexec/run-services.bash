#!/bin/bash

#  run-services - run gsatellite services

:<<COPYRIGHT

Copyright (C) 2012 Frank Scheiner

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
#  FUNCTIONS
################################################################################

#functionName()
#{
#	: #  do something...
#}
#
##  export function
#export -f functionName

__getEmailAddress()
{
	echo "mail@localhost"
	return
}
export -f __getEmailAddress

################################################################################

_event="$1"

_environment="$2"

_servicesBaseDir="$3"

################################################################################

#  export event
export GSAT_EVENT="$_event"

#  source environment
. "$_environment"

#  execute services
for _service in "$_servicesBaseDir"/*; do
        if [[ -x "$_service" && -r "$_service" ]]; then
                "$_service" &
        fi
done

exit

