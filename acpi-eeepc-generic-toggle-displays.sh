#!/bin/bash
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

connected=$(grep " connected " $var_xrandr | awk '{print ""$1""}')
disconnected=$(grep " disconnected " $var_xrandr | awk '{print ""$1""}')
all="$connected $disconnected"

if [ "x`echo $connected | grep -i VGA`" == "x" ]; then
    vga_connected="no"
else
    vga_connected="yes"
fi

xrandr_clone="$xrandr --output LVDS --auto --output VGA --auto"
xrandr_vga="$xrandr --output LVDS --off --output VGA --auto"
xrandr_vga_and_lvds="$xrandr --output LVDS --auto --output VGA --auto --${COMMANDS_XRANDR_TOGGLE_VGA}-of LVDS"
xrandr_lvds="$xrandr --output LVDS --auto --output VGA --off"

modes=(
    "${xrandr_lvds}"
    "${xrandr_clone}"
    "${xrandr_vga}"
    "${xrandr_vga_and_lvds}"
)
modes_names=(
    "Laptop screen only"
    "Clone"
    "VGA only"
    "VGA (${COMMANDS_XRANDR_TOGGLE_VGA} of) laptop screen"
)

# Get the number of modes of LVDS
lvds_nb_modes=$((`sed -n '/LVDS/,//p' $var_xrandr | wc -l` - 1))
# What is the actual LVDS mode?
actual_mode_lvds=`sed -n '/LVDS/,//p' $var_xrandr | grep "*" | awk '{print ""$1""}'`
# Get the position of LVDS
position_lvds=(`grep LVDS /var/eeepc/xrandr.log | awk '{print ""$3""}' | sed "s|[0-9]*x[0-9]*+\(.*\)+\(.*\)|\1 \2|g"`)

# Assume we are actually at modes[0] (LVDS only)
m=0
if [[ "$vga_connected" = "yes" ]]; then
    #echo "VGA connected. Trying to detect which configuration..."

    # Get the number of modes of VGA
    vga_nb_modes=$((`sed -n '/VGA/,/LVDS/p' $var_xrandr | wc -l` - 2))
    # What is the actual VGA mode?
    actual_mode_vga=`sed -n '/VGA/,/LVDS/p' $var_xrandr | grep "*" | awk '{print ""$1""}'`
    # Get the position of VGA
    position_vga=(`grep VGA /var/eeepc/xrandr.log | awk '{print ""$3""}' | sed "s|[0-9]*x[0-9]*+\(.*\)+\(.*\)|\1 \2|g"`)

    # Check VGA only if it is activated
    if [ "${position_vga}" != "(normal" ]; then

        # Detect if we are at modes[1] (Clone)
        if   [[ \
                "${position_lvds[0]}" == "0" && \
                "${position_lvds[1]}" == "0" && \
                "${position_vga[0]}"  == "0" && \
                "${position_vga[1]}"  == "0" ]]; then
            m=1
        # Detect if we are at modes[2] (VGA only)
        elif [ "${position_lvds}" == "(normal" ]; then
            m=2
        # Detect if we are at modes[3] (VGA + LVDS)
        else
            m=3
        fi

    fi
fi

#################################################################
function display_toggle() {
    prev_m=$m
    echo "Actual mode is ${modes_names[m]} (m=${prev_m})"

    if [ "$1" == "" ]; then
        # We are at mode "m", go to next mode
        m=$((m+1))
        # Check for round-up
        [ "$m" == "4" ] && m=0
    else
        m=$1
    fi

    echo "Next mode will be ${modes_names[m]} (m=$m)"

    if [ "${prev_m}" == "${m}" ]; then
        eeepc_notify "Display already in '${modes_names[m]}' mode" video-display
        return
    fi

    xrandr_cmd="${modes[m]}"

    if [ "$m" == "0" ]; then
        # If next mode is 0 (LVDS only), we really want to go there,
        # whatever the state of the VGA is.
        eeepc_notify "Changing display mode to: ${modes_names[m]}" video-display
        #echo "1. xrandr_cmd = $xrandr_cmd"
        execute_commands "${xrandr_cmd}"
    else
        # Else, we check if VGA is connected: it does not make sense
        # to activate it if it's not present!
        if [ "$vga_connected" == "yes" ]; then
            eeepc_notify "Changing display mode to '${modes_names[m]}' mode" video-display
            #echo "2. xrandr_cmd = $xrandr_cmd"
            execute_commands "${xrandr_cmd}"
        else
            # If VGA is not connected, don't do anything
            eeepc_notify "VGA not connected: not going to '${modes_names[m]}' mode" video-display
            return
        fi
    fi

}


#################################################################
function display_debug() {
    echo "All: ${all}"
    echo "Connected: ${connected}"
    echo "Disconnected: ${disconnected}"
    echo "vga_connected = $vga_connected"
    echo "current = $current"

    echo "vga_nb_modes = $vga_nb_modes"
    echo "lvds_nb_modes = $lvds_nb_modes"
    echo "actual_mode_vga = $actual_mode_vga"
    echo "actual_mode_lvds = $actual_mode_lvds"

    echo "position_lvds = ${position_lvds[*]}"
    echo "position_vga = ${position_vga[*]}"

    xrandr

    exit
}

#################################################################
case $1 in
    lvds|Lvds|LVDS)
        display_toggle 0
    ;;
    clone|Clone|CLONE)
        display_toggle 1
    ;;
    vga|Vga|VGA)
        display_toggle 2
    ;;
    vga_and_lvds|both|Both|BOTH)
        display_toggle 3
    ;;
    debug|Debug|DEBUG)
        display_debug
    ;;
    *)
        display_toggle
    ;;
esac


### End of file #################################################


