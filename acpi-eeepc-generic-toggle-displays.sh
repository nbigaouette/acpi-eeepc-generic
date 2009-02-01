#!/bin/bash
#
# Toggle between available displays using xrandr
#

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh

xrandr=`which xrandr`
if [ ! -e "$xrandr" ]; then
    msg="Please install xorg-server-utils to be able
to use xrandr."
    eeepc_notify "$msg" display
    logger "$msg"
    echo "$msg"
    exit 0
fi

var_xrandr="$EEEPC_VAR/xrandr.log"
xrandr > $var_xrandr

current=$(grep -B 1 "*" $var_xrandr | head -n 1 | awk '{print ""$1""}')

vga_connected=$(grep VGA $var_xrandr | awk '{print ""$2""}')

if [ "x$vga_connected" == "xdisconnected" ]; then
    msg="External monitor not connected"
    eeepc_notify "$msg" display
    #logger "$msg"
    echo "$msg"
    exit 0
fi

xrandr_clone="$xrandr --output LVDS --auto --output VGA --auto"

xrandr_vga_right_of_lvds="$xrandr --output LVDS --auto --output VGA --auto --right-of LVDS"
xrandr_vga_left_of_lvds="$xrandr --output LVDS --auto --output VGA --auto --left-of LVDS"
xrandr_vga_above_of_lvds="$xrandr --output LVDS --auto --output VGA --auto --above-of LVDS"
xrandr_vga_below_of_lvds="$xrandr --output LVDS --auto --output VGA --auto --below-of LVDS"

xrandr_vga="$xrandr --output LVDS --off --output VGA --auto"
xrandr_lvds="$xrandr --output LVDS --auto --output VGA --off"

function toggle_screens {

}





















