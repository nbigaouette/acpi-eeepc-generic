#!/bin/bash
#
# http://code.google.com/p/acpi-eeepc-generic/
#

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh

SAVED_STATE_FILE=$EEEPC_VAR/states/bluetooth

if [ -e $SAVED_STATE_FILE ]; then
  SAVED_STATE=$(cat $SAVED_STATE_FILE)
else
  SAVED_STATE=0
fi

# Find the right rfkill switch, but default to the second one
rfkill="rfkill1"
lsrfkill=""
[ -e /sys/class/rfkill ] && lsrfkill=`/bin/ls /sys/class/rfkill/`
for r in $lsrfkill; do
    name=`cat /sys/class/rfkill/$r/name`
    [ "$name" == "eeepc-bluetooth" ] && rfkill=$r
done
RFKILL_SWITCH="/sys/class/rfkill/${rfkill}/state"

# Get rfkill switch state (0 = card off, 1 = card on)
RFKILL_STATE=0
[ -e "$RFKILL_SWITCH" ] && RFKILL_STATE=$(cat $RFKILL_SWITCH)

SYS_DEVICE="/sys/devices/platform/eeepc/bt"
if [ -e $SYS_DEVICE ]; then
    SYS_STATE=$(cat $SYS_DEVICE)
else
    # Some models do not have any such device, we must
    # get the state based on what is reported in rfkill
    SYS_STATE=${RFKILL_STATE}
fi


function debug_bluetooth() {
    print_generic_debug
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): Device: $SYS_DEVICE"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): Driver: $BLUETOOTH_DRIVER"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): Radio: $SYS_STATE"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): State: $RFKILL_STATE"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): rfkill: $RFKILL_SWITCH"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): COMMANDS_BT_PRE_UP:"
    print_commands "${COMMANDS_BT_PRE_UP[@]}"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): COMMANDS_BT_POST_UP:"
    print_commands "${COMMANDS_BT_POST_UP[@]}"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): COMMANDS_BT_PRE_DOWN:"
    print_commands "${COMMANDS_BT_PRE_DOWN[@]}"
    echo "DEBUG (acpi-eeepc-generic-toggle-bluetooth.sh): COMMANDS_BT_POST_DOWN:"
    print_commands "${COMMANDS_BT_POST_DOWN[@]}"

    eeepc_notify "Bluetooth
Device: $SYS_DEVICE
Driver: $BLUETOOTH_DRIVER
Radio: $SYS_STATE
State: $RFKILL_STATE
rfkill: $RFKILL_SWITCH" bluetooth 10000
}

function radio_on {
    show_notifications=1
    [ "$2" == "0" ] && show_notifications=0

    [ "$RFKILL_STATE" == "1" ] && eeepc_notify "Bluetooth already tuned on!" bluetooth && return 0

    [ "$show_notifications" == "1" ] && eeepc_notify "Turning Bluetooth on..." bluetooth

    # Execute pre-up commands just once
    [ $1 -eq 1 ] && execute_commands "${COMMANDS_BLUETOOTH_PRE_UP[@]}"

    # Enable radio, might fail on less then 2.6.29
    [ -e "$RFKILL_SWITCH" ] && echo 1 > $RFKILL_SWITCH
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
        echo 1 > $SAVED_STATE_FILE
        [ -e $SYS_DEVICE ] && \
            echo 1 > $SYS_DEVICE
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

    [ "$RFKILL_STATE" == "0" ] && eeepc_notify "Bluetooth already tuned off!" bluetooth && return 0

    [ "$show_notifications" == "1" ] && eeepc_notify "Turning Bluetooth off..." bluetooth

    # Execute pre-down commands just once
    [ $1 -eq 1 ] && execute_commands "${COMMANDS_BLUETOOTH_PRE_DOWN[@]}"

    # Unload module
    /sbin/modprobe -r $BLUETOOTH_DRIVER 2>/dev/null
    success=$?
    if [ $success ]; then
        # If successful, disable card through rkfill and save the state
        # might fail on less then 2.6.29
        [ -e "$RFKILL_SWITCH" ] && echo 0 > $RFKILL_SWITCH
        if [ ${KERNEL_rel} -lt 29 ]; then
            s="rfkill switch usage might fail on kernel lower than 2.6.29"
            logger "$s"
            echo "$s"
        fi

        [ -e $SYS_DEVICE ] && echo 0 > $SYS_DEVICE

        echo 0 > $SAVED_STATE_FILE

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
    if [ "$SYS_STATE" = "1" ]; then
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

