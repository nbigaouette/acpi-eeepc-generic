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

