#!/bin/sh
# Copyright 2009 Nicolas Bigaouette
# This file is part of acpi-eeepc-generic.
# http://code.google.com/p/acpi-eeepc-generic/
# 
# acpi-eeepc-generic is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# acpi-eeepc-generic is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with acpi-eeepc-generic.  If not, see <http://www.gnu.org/licenses/>.

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh

logger "#############################################"
logger "acpi-eeepc-generic-suspend2ram.sh:"

function suspend_check_blacklisted_processes() {
    processes=( "$@" )
    p_num=${#processes[@]}
    logger "Checking for processes before suspending: $processes ($p_num)"
    for ((i=0;i<${p_num};i++)); do
        p=${processes[${i}]}
        pid=`pidof $p`
        logger "process #$i: $p ($pid)"
        echo "process #$i: $p ($pid)"
        if [ "x$pid" != "x" ]; then
            echo "$p is running! Canceling suspend"
            logger "$p is running! Canceling suspend"
            eeepc_notify "$p is running! Canceling suspend" stop 5000
            exit 0
        fi
    done
}

suspend_check_blacklisted_processes "${SUSPEND_BLACKLISTED_PROCESSES[@]}"

if [ -e "${EEEPC_VAR}/power.lock" ]; then
    msg="Suspend lock exist, canceling suspend"
    logger "$msg (${EEEPC_VAR}/power.lock)"
    eeepc_notify "$msg" stop 5000
    exit 0
fi

vga_is_on=`xrandr | grep -A 1 VGA | grep "*"`
if [ "x$vga_is_on" != "x" ]; then
    msg="VGA is up and running, canceling suspend"
    logger $msg
    eeepc_notify "$msg" stop 5000
    exit 0
fi

if grep -q mem /sys/power/state ; then

    # BEGIN SUSPEND SEQUENCE

    logger "Start suspend sequence"

    # Get console number
    CONSOLE_NUMBER=$(fgconsole)
    logger "Saving console number: $CONSOLE_NUMBER"

    # Turn off external monitor
    xrandr --output LVDS --preferred --output VGA --off

    # Save logs
    /etc/rc.d/logsbackup stop

    # Flush disk buffers
    sync

    # Change virtual terminal to not screw up X
    chvt 1

    # Suspend
    execute_commands "${SUSPEND2RAM_COMMANDS[@]}"

    logger "BEGIN WAKEUP SEQUENCE..."

    # Restore screen
    #/usr/sbin/vbetool post

    # Get back to screen
    chvt $CONSOLE_NUMBER

    # Restore brightness
    restore_brightness

fi

exit 0

