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
get_model
. /etc/acpi/eeepc/models/acpi-eeepc-$EEEPC_MODEL-events.conf

# Disable access control. Needed for GUI notification.
execute_commands "@xhost +localhost"

SELECTION=$3
if [ "$KEY_SHOW" = "1" ]; then
eeepc_notify "The event of the pressed key is: \"$SELECTION\"" keyboard 20000
fi

case "$1" in
    button/power)
        case "$2" in
            PWRF|PBTN)
                eeepc_notify "Power button pressed" gnome-session-halt
                execute_commands "${COMMANDS_POWER_BUTTON[@]}"
            ;;
            *)
                msg="Button (button/power) undefined: $2 $3 $4"
                eeepc_notify $msg keyboard
                logger $msg
            ;;
        esac
        ;;

    button/sleep)
        case "$2" in
            SLPB|SBTN)
                eeepc_notify "Sleep button pressed" gnome-session-suspend
                execute_commands "${COMMANDS_SLEEP[@]}"
            ;;
            *)
                msg="Button (button/sleep) undefined: $2 $3 $4"
                eeepc_notify $msg keyboard
                logger $msg
            ;;
        esac
        ;;

    ac_adapter)
        case "$2" in
            AC0)
                case "$4" in
                    $POWER_BAT) # AC off
                        execute_commands "${COMMANDS_AC_UNPLUGGED[@]}"
                    ;;
                    $POWER_AC) # AC on
                        execute_commands "${COMMANDS_AC_PLUGGED[@]}"
                    ;;
                esac
                ;;
            *)
                msg="ACPI AC (ac_adapter) undefined: $2 $3 $4"
                eeepc_notify $msg keyboard
                logger $msg
            ;;
        esac
        ;;

    battery)
        case "$2" in
            BAT0)
                case "$4" in
                    00000000) # Battery removed
                    ;;
                    00000001) # Battery present
                    ;;
                esac
                ;;
            *)
                msg="ACPI battery (battery) undefined: $2 $3 $4"
                eeepc_notify $msg keyboard
                logger $msg
            ;;
        esac
        ;;

    button/lid)
        # Detect correctly lid state
        lidstate=""
        # /proc/acpi is deprecated
        [ -e /proc/acpi/button/lid/LID/state ] && \
            lidstate=$(cat /proc/acpi/button/lid/LID/state | awk '{print $2}')
        [ "x$lidstate" == "x" ] && \
            [ "x$3" != "x" ] && lidstate=$3 # Use event given (2rd argument) to acpid
        # FIXME: It seems there is no /sys inteface to replace this
        # old /proc/acpi interface, so the latter is not deprecated...

        case "$lidstate" in
        open)
            xset dpms force on  # Screen on
            restore_brightness  # Restore brightness
        ;;
        closed)
            save_brightness     # Save brightness
            if [ "$COMMANDS_ON_LID_CLOSE" == "yes" ]; then
                state_file1="/proc/acpi/ac_adapter/AC0/state"
                state_file2="/sys/class/power_supply/AC0/online"
                # /proc/acpi/* is deprecated
                [ -e $state_file1 ] && ac_state=$(cat $state_file1 | awk '{print $2}' )
                # /sys is the future
                [ -e $state_file2 ] && ac_state=$(cat $state_file2)

                case $ac_state in
                1|on-line)
                    # AC adapter plugged in
                    execute_commands "${COMMANDS_LID_CLOSE_ON_AC[@]}"
                ;;
                0|off-line)
                    # Battery powered
                    execute_commands "${COMMANDS_LID_CLOSE_ON_BATTERY[@]}"
                ;;
                esac
            fi
        ;;
        *)
            msg="Button (button/lid) undefined: $2 $3 $4"
            eeepc_notify $msg keyboard
            logger $msg
        ;;
        esac
        ;;
    hotkey)
        case "$3" in
            $EEEPC_BLANK) # Silver function button 1 (Blank)
                logger "acpi-eeepc-generic-handler.sh (hotkey): Silver function button (Blank)"
                execute_commands "${COMMANDS_BUTTON_BLANK[@]}"
            ;;
            $EEEPC_RESOLUTION) # Silver function button 2 (Resolution)
                logger "acpi-eeepc-generic-handler.sh (hotkey): Silver function button (Resolution)"
                execute_commands "${COMMANDS_BUTTON_RESOLUTION[@]}"
            ;;
            $EEEPC_USER1) # Silver function button 3 (User1)
                logger "acpi-eeepc-generic-handler.sh (hotkey): Silver function button (User1)"
                execute_commands "${COMMANDS_BUTTON_USER1[@]}"
            ;;
            $EEEPC_USER2) # Silver function button 4 (User2)
                logger "acpi-eeepc-generic-handler.sh (hotkey): Silver function button (User2)"
                execute_commands "${COMMANDS_BUTTON_USER2[@]}"
            ;;
            $EEEPC_USER3) # Fn+Space
                logger "acpi-eeepc-generic-handler.sh (hotkey): Fn+Space"
                execute_commands "${COMMANDS_BUTTON_USER3[@]}"
            ;;

            $EEEPC_SLEEP)
                logger "acpi-eeepc-generic-handler.sh (hotkey): Sleep"
                eeepc_notify "Going to sleep..." gnome-session-suspend
                execute_commands "${COMMANDS_SLEEP[@]}"
            ;;
            $EEEPC_WIFI_TOGGLE) # WiFi Toggle
                logger "acpi-eeepc-generic-handler.sh (hotkey): WiFi toggle"
                execute_commands "${COMMANDS_WIFI_TOGGLE[@]}"
            ;;
            $EEEPC_WIFI_UP) # WiFi Up
                logger "acpi-eeepc-generic-handler.sh (hotkey): WiFi Up"
                execute_commands "${COMMANDS_WIFI_UP[@]}"
            ;;
            $EEEPC_WIFI_DOWN) # WiFi Down
                logger "acpi-eeepc-generic-handler.sh (hotkey): WiFi Down"
                execute_commands "${COMMANDS_WIFI_DOWN[@]}"
            ;;
            $EEEPC_TOUCHPAD_TOGGLE) # Toggle touchpad
                logger "acpi-eeepc-generic-handler.sh (hotkey): Toggling touchpad"
                execute_commands "${COMMANDS_TOUCHPAD_TOGGLE[@]}"
            ;;
            $EEEPC_RESOLUTION) # Change resolution
                logger "acpi-eeepc-generic-handler.sh (hotkey): Changing resolution"
                execute_commands "${COMMANDS_RESOLUTION[@]}"
            ;;
            $EEEPC_BRIGHTNESS_UP|$EEEPC_BRIGHTNESS_DOWN) # Brightness
                brightness_direction=`brightness_find_direction`
                if [ "$brightness_direction" == "up" ]; then
                    execute_commands "${COMMANDS_BRIGHTNESS_UP[@]}"
                    brightness_percentage=`brightness_get_percentage`
                    [ "$brightness_percentage" != "100" ] && logger "acpi-eeepc-generic-handler.sh (hotkey): Brightness Up ($brightness_percentage%)"
                    [ "$brightness_percentage" != "100" ] && eeepc_notify "Brightness Up ($brightness_percentage%)" dialog-information
                elif [ "$brightness_direction" == "down" ]; then
                    execute_commands "${COMMANDS_BRIGHTNESS_DOWN[@]}"
                    brightness_percentage=`brightness_get_percentage`
                    [ "$brightness_percentage" != "0" ] && logger "acpi-eeepc-generic-handler.sh (hotkey): Brightness Down ($brightness_percentage%)"
                    [ "$brightness_percentage" != "0" ] && eeepc_notify "Brightness Down ($brightness_percentage%)" dialog-information
                fi
            ;;
            $EEEPC_SCREEN_OFF) # Turn off screen
                logger "acpi-eeepc-generic-handler.sh (hotkey): Turn off screen"
                execute_commands "${COMMANDS_SCREEN_OFF[@]}"
                eeepc_notify "Turning screen off..." dialog-information
            ;;
            $EEEPC_XRANDR_TOGGLE) # RandR
                logger "acpi-eeepc-generic-handler.sh (hotkey): RandR"
                execute_commands "${COMMANDS_XRANDR_TOGGLE[@]}"
                #eeepc_notify "Clone" video-display
            ;;
            $EEEPC_XRANDR_CLONE) # RandR (clone)
                logger "acpi-eeepc-generic-handler.sh (hotkey): RandR (clone)"
                execute_commands "${COMMANDS_XRANDR_CLONE[@]}"
                eeepc_notify "Clone" video-display
            ;;
            $EEEPC_XRANDR_VGA) # RandR (vga only)
                logger "acpi-eeepc-generic-handler.sh (hotkey): RandR (vga only)"
                eeepc_notify "VGA" video-display
                execute_commands "${COMMANDS_XRANDR_VGA[@]}"
            ;;
            $EEEPC_XRANDR_LCD) # RandR (lcd only)
                logger "acpi-eeepc-generic-handler.sh (hotkey): RandR (lcd only)"
                eeepc_notify "LCD" video-display
                execute_commands "${COMMANDS_XRANDR_LCD[@]}"
            ;;
            $EEEPC_TASKMAN) # Task Manager
                logger "acpi-eeepc-generic-handler.sh (hotkey): Task Manager"
                execute_commands "${COMMANDS_TASKM[@]}"
            ;;
            $EEEPC_VOL_MUTE) # Mute
                logger "acpi-eeepc-generic-handler.sh (hotkey): Mute"
                execute_commands "${COMMANDS_MUTE[@]}"
                if [ "`volume_is_mute`" == "1" ]; then
                    volume_icon="audio-volume-muted"
                    mute_toggle=""
                elif [ "`volume_is_mute`" == "0" ]; then
                    volume_icon="audio-volume-medium"
                    mute_toggle="Un"
                fi
                eeepc_notify "${mute_toggle}Mute (`get_volume`%)" $volume_icon
            ;;
            $EEEPC_VOL_DOWN) # Volume Down
                if [ "`volume_is_mute`" == "1" ]; then
                    volume_icon="audio-volume-muted"
                elif [ "`volume_is_mute`" == "0" ]; then
                    volume_icon="audio-volume-low"
                fi
                if [ "`get_volume`" != "0" ]; then
                    execute_commands "${COMMANDS_VOLUME_DOWN[@]}"
                    sleep 0.1
                    eeepc_notify "Volume Down (`get_volume`%)" $volume_icon
                fi
                logger "acpi-eeepc-generic-handler.sh (hotkey): Volume Down"
            ;;
            $EEEPC_VOL_UP) # Volume Up
                if [ "`volume_is_mute`" == "1" ]; then
                    volume_icon="audio-volume-muted"
                elif [ "`volume_is_mute`" == "0" ]; then
                    volume_icon="audio-volume-high"
                fi
                if [ "`get_volume`" != "100" ]; then
                    execute_commands "${COMMANDS_VOLUME_UP[@]}"
                    sleep 0.1
                    eeepc_notify "Volume Up (`get_volume`%)" $volume_icon
                fi
                logger "acpi-eeepc-generic-handler.sh (hotkey): Volume Up"
            ;;
#             00000052) # battery level critical
#             logger "Battery is critical, suspending"
#             $BATTERY_CRITICAL &
#             ;;
            *)
                msg="Hotkey (hotkey) undefined: $2 $3 $4"
                eeepc_notify $msg keyboard
                logger $msg
            ;;
        esac
    ;;
    processor)
        logger "Processor acpi event not implemented: $1 $2 $3 $4"
    ;;
    *)
        msg="ACPI group/action ($1) undefined: $2 $3 $4"
        eeepc_notify $msg keyboard
        logger $msg
    ;;
esac

# Restore access control
execute_commands "@xhost -localhost"

