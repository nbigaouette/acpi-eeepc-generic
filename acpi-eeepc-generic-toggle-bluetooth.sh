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
load_saved_state

### Check rfkill switch #########################################
check_rfkill_switch

### Check /sys interface
check_sys_interface

### Detect if card is enabled or disabled #######################
detect_if_enabled

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

