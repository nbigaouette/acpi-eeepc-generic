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

if [ -e "$EEEPC_VAR/touchpad_saved" ]; then
  TPSAVED=$(cat $EEEPC_VAR/touchpad_saved)
fi

enable=`synclient -l 2>&1`
if [ "$enable" == "Can't access shared memory area. SHMConfig disabled?" ]; then
    eeepc_notify "$enable" stop 10000
    eeepc_notify "Ensure xorg.conf is properly configured." stop 10000
    exit 1
fi

function touchpad_toggle {
    TOUCHPAD=`synclient -l | grep TouchpadOff | awk '{print $3}'`
    if [ "$TOUCHPAD" = "0" ]; then
        echo 1 > $EEEPC_VAR/touchpad_saved
        synclient TouchpadOff=1
        if [ $? ]; then
            eeepc_notify "Touchpad Disabled" mouse
        else
            eeepc_notify "Unable to disable touchpad; Ensure xorg.conf is properly configured." stop
        fi
    else
        echo 0 > $EEEPC_VAR/touchpad_saved
        synclient TouchpadOff=0
        if [ $? ]; then
            eeepc_notify "Touchpad Enabled" mouse
        else
            eeepc_notify "Unable to enable touchpad; Ensure xorg.conf is properly configured." stop
        fi
    fi
}

function touchpad_restore {
    if [ "$TPSAVED" = "1" ]; then
        synclient TouchpadOff=1
        if [ $? ]; then
            eeepc_notify "Touchpad Disabled" mouse
        else
            eeepc_notify "Unable to disable touchpad; Ensure xorg.conf is properly configured." stop
        fi
    else
        synclient TouchpadOff=0
        if [ $? ]; then
            eeepc_notify "Touchpad Enabled" mouse
        else
            eeepc_notify "Unable to enable touchpad; Ensure xorg.conf is properly configured." stop
        fi
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

