#!/bin/bash
#
# http://code.google.com/p/acpi-eeepc-generic/
#

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh

SAVED_STATE_FILE=$EEEPC_VAR/states/bluetooth

### Load saved state from file ##################################
if [ -e $SAVED_STATE_FILE ]; then
    SAVED_STATE=$(cat $SAVED_STATE_FILE)
else
    SAVED_STATE=0
fi

### Check rfkill switch #########################################
if [ -e ${rfkills_path} ]; then
    # Default to the second one
    rfkill="rfkill1"
    for r in `/bin/ls ${rfkills_path}/`; do
        name=`cat ${rfkills_path}/$r/name`
        [ "$name" == "eeepc-bluetooth" ] && rfkill=$r
    done
    RFKILL_IS_PRESENT="yes"
    RFKILL_SWITCH="${rfkills_path}/${rfkill}/state"
    # Get rfkill switch state (0 = card off, 1 = card on)
    RFKILL_STATE=$(cat ${RFKILL_SWITCH})
else
    # rfkill disabled/not present
    RFKILL_IS_PRESENT="no"
    RFKILL_SWITCH=""
    RFKILL_STATE=0
fi

### Check /sys interface ########################################
SYS_DEVICE="${sys_path}/bt"
if [ -e ${SYS_DEVICE} ]; then
    SYS_IS_PRESENT="yes"
    # Get sys state (0 = card off, 1 = card on)
    SYS_STATE=$(cat ${SYS_DEVICE})
else
    # Some models do not have any such device (1000HE)
    SYS_IS_PRESENT="no"
    SYS_STATE=""
fi

### Detect if card is enabled or disabled #######################
if [[ "${SYS_IS_PRESENT}" == "yes" && "${RFKILL_IS_PRESENT}" == "yes" ]]; then
    # Both are present, no problem!

    # States of both should match. Else we have a problem...
    if   [[ "${SYS_STATE}" == "1" && "${RFKILL_STATE}" == "1" ]]; then
        IS_ENABLED="yes"
    elif [[ "${SYS_STATE}" == "0" && "${RFKILL_STATE}" == "0" ]]; then
        IS_ENABLED="no"
    else
        msg="ERROR in $0: /sys interface state (${SYS_STATE}) and rfkill switch state (${RFKILL_STATE}) do not match!"
        logger "$msg"
        eeepc_notify "$msg" stop
        exit 1
    fi
else
    # One of the two is not present. Just get the state of the other
    if   [[ "${SYS_IS_PRESENT}"    == "yes" && "${SYS_STATE}"    == "1" ]]; then
        IS_ENABLED="yes"
    elif [[ "${RFKILL_IS_PRESENT}" == "yes" && "${RFKILL_STATE}" == "1" ]]; then
        IS_ENABLED="yes"
    else
        IS_ENABLED="no"
    fi
fi

#################################################################
function debug_bluetooth() {
    print_generic_debug
    echo "DEBUG ($0): Driver:        ${BLUETOOTH_DRIVER}"
    echo "DEBUG ($0): is enabled:    ${IS_ENABLED}"
    echo "DEBUG ($0): /sys device:   ${SYS_DEVICE}"
    echo "DEBUG ($0): /sys state:    ${SYS_STATE}"
    echo "DEBUG ($0): rfkill switch: ${RFKILL_SWITCH}"
    echo "DEBUG ($0): rfkill state:  ${RFKILL_STATE}"
    echo "DEBUG ($0): COMMANDS_BT_PRE_UP:"
    print_commands "${COMMANDS_BT_PRE_UP[@]}"
    echo "DEBUG ($0): COMMANDS_BT_POST_UP:"
    print_commands "${COMMANDS_BT_POST_UP[@]}"
    echo "DEBUG ($0): COMMANDS_BT_PRE_DOWN:"
    print_commands "${COMMANDS_BT_PRE_DOWN[@]}"
    echo "DEBUG ($0): COMMANDS_BT_POST_DOWN:"
    print_commands "${COMMANDS_BT_POST_DOWN[@]}"

    eeepc_notify "Bluetooth
Driver: ${BLUETOOTH_DRIVER}
is enabled:    ${IS_ENABLED}
/sys device: ${SYS_DEVICE}
/sys state: ${SYS_STATE}
rfkill switch: ${RFKILL_SWITCH}
rfkill state: ${RFKILL_STATE}" bluetooth 10000
}

#################################################################
function radio_on {
    # First argument ($1):  Number of times the funciton has been called
    # Second argument ($2): Should we show notifications?

    # Check if 2nd argument to given to function is "0" and disable
    # notifications,
    show_notifications=1
    [ "$2" == "0" ] && show_notifications=0

    [ "${IS_ENABLED}" == "yes" ] && \
        eeepc_notify "Bluetooth already turned on!" bluetooth && \
            return 0

    [ "$show_notifications" == "1" ] && \
        eeepc_notify "Turning Bluetooth on..." bluetooth

    # Execute pre-up commands just once
    [ $1 -eq 1 ] && \
        execute_commands "${COMMANDS_BLUETOOTH_PRE_UP[@]}"

    # Enable rfkill switch (which might fail on less then 2.6.29)
    if [ "${RFKILL_IS_PRESENT}" == "yes" ]; then
        echo 1 > ${RFKILL_SWITCH}

        if [ ${KERNEL_rel} -lt 29 ]; then
            s="rfkill switch usage might fail on kernel lower than 2.6.29"
            logger "$s"
            echo "$s"
        fi
    fi

    # Load module
    /sbin/modprobe ${BLUETOOTH_DRIVER} 2>/dev/null
    success=$?
    if [ $success ]; then
        # If successful, enable card
        [ "${SYS_IS_PRESENT}" == "yes" ] && \
            echo 1 > ${SYS_DEVICE}

        # Save the card state
        echo 1 > $SAVED_STATE_FILE

        # Execute post-up commands
        execute_commands "${COMMANDS_BLUETOOTH_POST_UP[@]}"

        [ "$show_notifications" == "1" ] && \
            eeepc_notify "Bluetooth is now on" bluetooth
    else
        # If module loading was not successful...

        [ "$show_notifications" == "1" ] && \
            eeepc_notify "Could not enable Bluetooth" stop

        # Try again
        if [ $1 -lt $BLUETOOTH_TOGGLE_MAX_TRY ]; then
            [ "$show_notifications" == "1" ] && \
                eeepc_notify "Trying again in 2 second ($(($1+1)) / $BLUETOOTH_TOGGLE_MAX_TRY)" bluetooth
            sleep 2
            radio_on $(($1+1)) $show_notifications
        fi
    fi
}

#################################################################
function radio_off {
    # First argument ($1):  Number of times the funciton has been called
    # Second argument ($2): Should we show notifications?

    # Check if 2nd argument to given to function is "0" and disable
    # notifications,
    show_notifications=1
    [ "$2" == "0" ] && show_notifications=0

    [ "${IS_ENABLED}" == "no" ] && \
        eeepc_notify "Bluetooth already turned off!" bluetooth && \
            return 0

    [ "$show_notifications" == "1" ] && \
        eeepc_notify "Turning Bluetooth off..." bluetooth

    # Execute pre-down commands just once
    [ $1 -eq 1 ] && \
        execute_commands "${COMMANDS_BLUETOOTH_PRE_DOWN[@]}"

    # Unload module
    /sbin/modprobe -r ${BLUETOOTH_DRIVER} 2>/dev/null
    success=$?
    if [ $success ]; then
        # If successful...
        if [ "${RFKILL_IS_PRESENT}" == "yes" ]; then
            # ...and rfkill switch exists

            # Disable the card via rfkill switch
            echo 0 > ${RFKILL_SWITCH}

            if [ ${KERNEL_rel} -lt 29 ]; then
                s="rfkill switch usage might fail on kernel lower than 2.6.29"
                logger "$s"
                echo "$s"
            fi
        fi

        # If /sys device exists, disable it too
        [ "${SYS_IS_PRESENT}" == "yes" ] && \
            echo 0 > ${SYS_DEVICE}

        # Save the card states
        echo 0 > $SAVED_STATE_FILE

        # Execute post-down commands
        execute_commands "${COMMANDS_BLUETOOTH_POST_DOWN[@]}"

        [ "$show_notifications" == "1" ] && \
            eeepc_notify "Bluetooth is now off" bluetooth
    else
        # If module unloading unsuccessful, try again

        [ "$show_notifications" == "1" ] && \
            eeepc_notify "Could not disable Bluetooth" stop

        if [ $1 -lt $BLUETOOTH_TOGGLE_MAX_TRY ]; then
            [ "$show_notifications" == "1" ] && \
                eeepc_notify "Trying again in 2 second ($(($1+1)) / $BLUETOOTH_TOGGLE_MAX_TRY)" bluetooth
            sleep 2
            radio_off $(($1+1)) $show_notifications
        fi
    fi
}

#################################################################
function radio_toggle {
    if [ "${SYS_STATE}" = "1" ]; then
        radio_off 1
    else
        radio_on 1
    fi
}

#################################################################
function radio_restore {
  if [ "$RADIO_SAVED_RADIO" = "1" ]; then
    radio_on 1 0
  else
    radio_off 1 0
  fi
}

#################################################################
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
