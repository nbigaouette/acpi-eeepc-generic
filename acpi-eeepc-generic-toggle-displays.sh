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
#xrandr > $var_xrandr

current=$(grep -B 1 "*" $var_xrandr | head -n 1 | awk '{print ""$1""}')

connected=$(grep " connected " $var_xrandr | awk '{print ""$1""}')
disconnected=$(grep " disconnected " $var_xrandr | awk '{print ""$1""}')
all="$connected $disconnected"

if [ "x`echo $connected | grep -i VGA`" == "x" ]; then
    vga_connected=0
else
    vga_connected=1
fi

echo "All: ${all}"
echo "Connected: ${connected}"
echo "Disconnected: ${disconnected}"
echo "vga_connected = $vga_connected"
echo "current = $current"

if [ "$vga_connected" == "0" ]; then
    msg="External monitor not connected"
#    eeepc_notify "$msg" display
#    logger "$msg"
    echo "$msg"
#    exit 0
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


# Assume we are actually at modes[0] (LVDS only)
m=0
if [[ "`echo \"${connected}\" | grep VGA`" != "" ]]; then
    echo "VGA connected. Trying to detect which configuration..."

    vga_nb_modes=$((`sed -n '/VGA/,/LVDS/p' $var_xrandr | wc -l` - 2))
    lvds_nb_modes=$((`sed -n '/LVDS/,//p' $var_xrandr | wc -l` - 1))
    echo "vga_nb_modes = $vga_nb_modes"
    echo "lvds_nb_modes = $lvds_nb_modes"

    # Detect if we are at modes[1] (Clone)

    # Detect if we are at modes[2] (VGA only)

    # Detect if we are at modes[3] (VGA + LVDS)

fi

echo "Actual mode is ${modes_names[m]}"

# We are at mode "m", go to next mode
m=$((m+1))

#eeepc_notify "Changing display mode to: ${modes_names[m]}" video-display
cmd="${modes[m]}"
echo "cmd = $cmd"
#execute_commands "${cmd}"

