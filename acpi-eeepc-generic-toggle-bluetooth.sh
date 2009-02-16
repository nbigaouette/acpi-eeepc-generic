#!/bin/bash
#
# http://code.google.com/p/acpi-eeepc-generic/
#

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh

BT_SAVED_STATE_FILE=$EEEPC_VAR/states/bluetooth

if [ -e $BT_SAVED_STATE_FILE ]; then
  BT_SAVED_STATE=$(cat $BT_SAVED_STATE_FILE)
else
  BT_SAVED_STATE=0
fi

# Find the right rfkill switch, but default to the second one
rfkill="rfkill1"
lsrfkill=""
[ -e /sys/class/rfkill ] && lsrfkill=`/bin/ls /sys/class/rfkill/`
for r in $lsrfkill; do
    name=`cat /sys/class/rfkill/$r/name`
    [ "$name" == "eeepc-bluetooth" ] && rfkill=$r
done

# Get rfkill switch state (0 = card off, 1 = card on)
BLUETOOTH_RFKILL="/sys/class/rfkill/${rfkill}/state"
BLUETOOTH_STATE=0
[ -e "$BLUETOOTH_RFKILL" ] && BLUETOOTH_STATE=$(cat $BLUETOOTH_RFKILL)

BLUETOOTH_DEVICE="/sys/devices/platform/eeepc/bt"
if [ -e $BLUETOOTH_DEVICE ]; then
    BLUETOOTH_RADIO=$(cat $BLUETOOTH_DEVICE)
fi


function debug_bluetooth() {
    echo "EeePC model: $EEEPC_MODEL ($EEEPC_CPU)"
    echo "Running kernel: `uname -a`"
    if [ -e /usr/bin/pacman ]; then
        echo "Installed kernel(s):"
        echo "`/usr/bin/pacman -Qs kernel26`"
    fi
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): rfkill: $BLUETOOTH_RFKILL"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): State: $BLUETOOTH_STATE"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): Device: $BLUETOOTH_DEVICE"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): Radio: $BLUETOOTH_RADIO"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): COMMANDS_BT_PRE_UP:"
    print_commands "${COMMANDS_BT_PRE_UP[@]}"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): COMMANDS_BT_POST_UP:"
    print_commands "${COMMANDS_BT_POST_UP[@]}"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): COMMANDS_BT_PRE_DOWN:"
    print_commands "${COMMANDS_BT_PRE_DOWN[@]}"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): COMMANDS_BT_POST_DOWN:"
    print_commands "${COMMANDS_BT_POST_DOWN[@]}"

    eeepc_notify "Can you see this?" gtk-dialog-question
}

function radio_on {
    show_notifications=1
    [ "$2" == "0" ] && show_notifications=0

    [ "$show_notifications" == "1" ] && eeepc_notify "Turning Bluetooth on..." bluetooth

    # Execute pre-up commands just once
    [ $1 -eq 1 ] && execute_commands "${COMMANDS_BLUETOOTH_PRE_UP[@]}"

    # Enable radio, might fail on less then 2.6.29
    [ -e "$BLUETOOTH_RFKILL" ] && echo 1 > $BLUETOOTH_RFKILL
    if [ ${KERNEL_rel} -lt 29 ]; then
        s="rfkill switch usage might fail on kernel lower than 2.6.29"
        logger "$s"
        echo "$s"
    fi

    # Load module
    /sbin/modprobe $BLUETOOTH_DRIVER 2>/dev/null
    success=$?
    if [ $success ]; then
        # If successful, enable card
        echo 1 > $BT_SAVED_STATE_FILE
        [ -e $BLUETOOTH_DEVICE ] && \
            echo 1 > $BLUETOOTH_DEVICE
        # Execute post-up commands
        execute_commands "${COMMANDS_BLUETOOTH_POST_UP[@]}"

        [ "$show_notifications" == "1" ] && eeepc_notify "Bluetooth is now on" bluetooth
    else
        [ "$show_notifications" == "1" ] && eeepc_notify "Could not enable Bluetooth" stop
        # If module loading unsuccessful, try again
        if [ $1 -lt $BLUETOOTH_TOGGLE_MAX_TRY ]; then
            [ "$show_notifications" == "1" ] && \
                eeepc_notify "Trying again in 2 second ($(($1+1)) / $BLUETOOTH_TOGGLE_MAX_TRY)" bluetooth
            sleep 2
            radio_on $(($1+1)) $show_notifications
        fi
    fi
}

function radio_off {
    show_notifications=1
    [ "$2" == "0" ] && show_notifications=0

    [ "$show_notifications" == "1" ] && eeepc_notify "Turning Bluetooth off..." bluetooth

    # Execute pre-down commands just once
    [ $1 -eq 1 ] && execute_commands "${COMMANDS_BLUETOOTH_PRE_DOWN[@]}"

    # Unload module
    /sbin/modprobe -r $BLUETOOTH_DRIVER 2>/dev/null
    success=$?
    if [ $success ]; then
        # If successful, disable card through rkfill and save the state
        # might fail on less then 2.6.29
        [ -e "$BLUETOOTH_RFKILL" ] && echo 0 > $BLUETOOTH_RFKILL
        if [ ${KERNEL_rel} -lt 29 ]; then
            s="rfkill switch usage might fail on kernel lower than 2.6.29"
            logger "$s"
            echo "$s"
        fi

        [ -e $BLUETOOTH_DEVICE ] && echo 0 > $BLUETOOTH_DEVICE

        echo 0 > $BT_SAVED_STATE_FILE

        # Execute post-down commands
        execute_commands "${COMMANDS_BLUETOOTH_POST_DOWN[@]}"

        [ "$show_notifications" == "1" ] && eeepc_notify "Bluetooth is now off" bluetooth
    else
        # If module unloading unsuccessful, try again
        [ "$show_notifications" == "1" ] && eeepc_notify "Could not disable Bluetooth" stop
        if [ $1 -lt $BLUETOOTH_TOGGLE_MAX_TRY ]; then
            [ "$show_notifications" == "1" ] && \
                eeepc_notify "Trying again in 2 second ($(($1+1)) / $BLUETOOTH_TOGGLE_MAX_TRY)" bluetooth
            sleep 2
            radio_off $(($1+1)) $show_notifications
        fi
    fi
}

function radio_toggle {
    if [ "$BLUETOOTH_RADIO" = "1" ]; then
        radio_off 1
    else
        radio_on 1
    fi
}

function radio_restore {
  if [ "$RADIO_SAVED_RADIO" = "1" ]; then
    radio_on 1 0
  else
    radio_off 1 0
  fi
}

case $1 in
    "debug")
        debug_bluetooth
    ;;
    "restore")
        radio_restore
    ;;
    "off")
        radio_off 1
    ;;
    "on")
        radio_on 1
    ;;
  *)
    radio_toggle
  ;;
esac

