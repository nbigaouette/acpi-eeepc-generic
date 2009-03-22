#!/bin/bash
#
# http://code.google.com/p/acpi-eeepc-generic/
#

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh


### Information for bluetooth ###################################
DRIVER=$BLUETOOTH_DRIVER
NAME="Bluetooth"
NAME_SMALL="bluetooth"
ICON=${NAME_SMALL}
SYS_NAME="bt"
COMMANDS_PRE_UP="${COMMANDS_BT_PRE_UP[@]}"
COMMANDS_PRE_DOWN="${COMMANDS_BT_PRE_DOWN[@]}"
COMMANDS_POST_UP="${COMMANDS_BT_POST_UP[@]}"
COMMANDS_POST_DOWN="${COMMANDS_BT_POST_DOWN[@]}"
TOGGLE_MAX_TRY=${BLUETOOTH_TOGGLE_MAX_TRY}

### Load saved state from file ##################################
SAVED_STATE_FILE=$EEEPC_VAR/states/${NAME_SMALL}
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
        [ "$name" == "eeepc-${NAME_SMALL}" ] && rfkill=$r
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
SYS_DEVICE="${sys_path}/${SYS_NAME}"
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
function device_on {
    # First argument ($1):  Number of times the funciton has been called
    # Second argument ($2): Should we show notifications?

    # Check if 2nd argument to given to function is "0" and disable
    # notifications,
    show_notifications=1
    [ "$2" == "0" ] && show_notifications=0

    [ "${IS_ENABLED}" == "yes" ] && \
        eeepc_notify "${NAME} already turned on!" ${ICON} && \
            return 0

    [ "$show_notifications" == "1" ] && \
        eeepc_notify "Turning ${NAME} on..." ${ICON}

    # Execute pre-up commands just once
    [ $1 -eq 1 ] && \
        execute_commands "${COMMANDS_PRE_UP[@]}"

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
    /sbin/modprobe ${DRIVER} 2>/dev/null
    success=$?
    if [ $success ]; then
        # If successful, enable card
        [ "${SYS_IS_PRESENT}" == "yes" ] && \
            echo 1 > ${SYS_DEVICE}

        # Save the card state
        echo 1 > $SAVED_STATE_FILE

        # Execute post-up commands
        execute_commands "${COMMANDS_POST_UP[@]}"

        [ "$show_notifications" == "1" ] && \
            eeepc_notify "${NAME} is now on" ${ICON}
    else
        # If module loading was not successful...

        [ "$show_notifications" == "1" ] && \
            eeepc_notify "Could not enable ${NAME}" stop

        # Try again
        if [ $1 -lt $TOGGLE_MAX_TRY ]; then
            [ "$show_notifications" == "1" ] && \
                eeepc_notify "Trying again in 2 second ($(($1+1)) / $TOGGLE_MAX_TRY)" ${ICON}
            sleep 2
            device_on $(($1+1)) $show_notifications
        fi
    fi
}

#################################################################
function device_off {
    # First argument ($1):  Number of times the funciton has been called
    # Second argument ($2): Should we show notifications?

    # Check if 2nd argument to given to function is "0" and disable
    # notifications,
    show_notifications=1
    [ "$2" == "0" ] && show_notifications=0

    [ "${IS_ENABLED}" == "no" ] && \
        eeepc_notify "${NAME} already turned off!" ${ICON} && \
            return 0

    [ "$show_notifications" == "1" ] && \
        eeepc_notify "Turning ${NAME} off..." ${ICON}

    # Execute pre-down commands just once
    [ $1 -eq 1 ] && \
        execute_commands "${COMMANDS_PRE_DOWN[@]}"

    # Unload module
    /sbin/modprobe -r ${DRIVER} 2>/dev/null
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
        execute_commands "${COMMANDS_POST_DOWN[@]}"

        [ "$show_notifications" == "1" ] && \
            eeepc_notify "${NAME} is now off" ${ICON}
    else
        # If module unloading unsuccessful, try again

        [ "$show_notifications" == "1" ] && \
            eeepc_notify "Could not disable ${NAME}" stop

        if [ $1 -lt $TOGGLE_MAX_TRY ]; then
            [ "$show_notifications" == "1" ] && \
                eeepc_notify "Trying again in 2 second ($(($1+1)) / $TOGGLE_MAX_TRY)" ${ICON}
            sleep 2
            device_off $(($1+1)) $show_notifications
        fi
    fi
}

#################################################################
function device_toggle {
    if [ "${SYS_STATE}" = "1" ]; then
        device_off 1
    else
        device_on 1
    fi
}

#################################################################
function device_restore {
    if [ "$RADIO_SAVED_RADIO" = "1" ]; then
        device_on 1 0
    else
        device_off 1 0
    fi
}

#################################################################
case $1 in
    "debug")
        print_generic_debug
    ;;
    "restore")
        device_restore
    ;;
    "off")
        device_off 1
    ;;
    "on")
        device_on 1
    ;;
    *)
        device_toggle
    ;;
esac

### End of file #################################################

