#!/bin/bash
#
#  EeePC Touchpad toggle
#  Tool to enable / disable touchpad
#  Andrew Wyatt
#  Edited by Nicolas Bigaouette
#  Generic WIFI toggle utility which should work across EeePC models.
#
#  http://code.google.com/p/acpi-eeepc-generic/
#

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh

# 0 means off, 1 means on
STATE_FILE="$EEEPC_VAR/states/touchpad"

if [ -e "$STATE_FILE" ]; then
  TPSAVED=$(cat $STATE_FILE)
fi

enable=`synclient -l 2>&1`
if [ "$enable" == "Can't access shared memory area. SHMConfig disabled?" ]; then
    eeepc_notify "$enable" stop 10000
    eeepc_notify "Ensure xorg.conf is properly configured." stop 10000
    exit 1
fi

function touchpad_toggle() {
    if [ -S /tmp/.X11-unix/X0 ]; then
        TOUCHPAD_OFF=`synclient -l | grep TouchpadOff | awk '{print $3}'`
        if [ "$TOUCHPAD_OFF" = "0" ]; then
            echo 0 > $STATE_FILE
            synclient TouchpadOff=1
            if [ $? ]; then
                [ -e /usr/bin/unclutter ] && unclutter -idle 0 &
                eeepc_notify "Touchpad Disabled" mouse
            else
                eeepc_notify "Unable to disable touchpad; Ensure xorg.conf is properly configured." stop
            fi
        else
            echo 1 > $STATE_FILE
            synclient TouchpadOff=0
            if [ $? ]; then
                pkill unclutter
                eeepc_notify "Touchpad Enabled" mouse
            else
                eeepc_notify "Unable to enable touchpad; Ensure xorg.conf is properly configured." stop
            fi
        fi
    fi
}

function touchpad_restore() {
    if [ "$TPSAVED" = "0" ]; then
        synclient TouchpadOff=1
    else
        synclient TouchpadOff=0
    fi
}

case $1 in
    restore)
        touchpad_restore
    ;;
    *)
        touchpad_toggle
    ;;
esac

