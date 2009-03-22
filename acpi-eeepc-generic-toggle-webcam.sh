#!/bin/bash
#
# http://code.google.com/p/acpi-eeepc-generic/
#

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh


### Information for bluetooth ###################################
DRIVER=$CAMERA_DRIVER
NAME="Camera"
NAME_SMALL="camera"
ICON="camera-web"
SYS_NAME="camera"

### Load saved state from file ##################################
load_saved_state

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

