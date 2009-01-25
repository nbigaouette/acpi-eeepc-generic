#!/bin/bash
#
#  EeePC LVDS resolution toggle
#  Andrew Wyatt
#  Tool to toggle LVDS output resolutions
#  Edited by Nicolas Bigaouette
#  Generic WIFI toggle utility which should work across EeePC models.
#
# http://code.google.com/p/acpi-eeepc-generic/
#

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh

tmp_xrandr="$EEEPC_VAR/lvds-modes"

if [ -e "$tmp_xrandr" ]; then
    LVDS_XRANDR=$(cat $tmp_xrandr)
else
    LVDS_XRANDR=$(xrandr > $tmp_xrandr)
fi

LVDS_MODES=$(cat $tmp_xrandr | grep -F -e LVDS -A 12 | grep [0-9]x[0-9] | grep -v -e LVDS | awk '{printf $1" "}')
LVDS_CURRENT=$(cat $tmp_xrandr | grep -F -e LVDS -A 12 | grep -F -e [0-9]x[0-9] -e "*" | awk '{print $1}')

function toggle_resolution {
    for mode in $LVDS_MODES $LVDS_MODES; do
        if [ "$mode" = "$LVDS_CURRENT" ]; then
            NEXT=1;
        elif [ "$NEXT" = "1" ]; then
            xrandr -s $mode
            eeepc_notify "Changing resolution to \"$mode\"" video-display
            echo $mode > $EEEPC_VAR/resolution_saved
            exit
        fi
    done
}

function restore_resolution {
    if [ -e "$EEEPC_VAR/resolution_saved" ]; then
        RESOLUTION=$(cat $EEEPC_VAR/resolution_saved)
        xrandr -s $RESOLUTION
        eeepc_notify "Changing resolution back to \"$RESOLUTION\"" video-display
    fi
}

case $1 in
    restore)
        restore_resolution
    ;;
    *)
        toggle_resolution
    ;;
esac
