#!/bin/bash
#
# http://code.google.com/p/acpi-eeepc-generic/
#

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh

CAMERA_SAVED_STATE_FILE=$EEEPC_VAR/states/camera

if [ -e $CAMERA_SAVED_STATE_FILE ]; then
    CAMERA_SAVED_STATE=$(cat $CAMERA_SAVED_STATE_FILE)
else
    CAMERA_SAVED_STATE=0
fi

CAMERA_DEVICE="/sys/devices/platform/eeepc/camera"

if [ -e "$CAMERA_DEVICE" ]; then
    CAMERA_STATE=$(cat $CAMERA_DEVICE)
fi


function debug_webcam() {
    echo "DEBUG (acpi-eeepc-generic-toggle-wifi.sh): EeePC model: $EEEPC_MODEL ($EEEPC_CPU)"
    echo "DEBUG (acpi-eeepc-generic-toggle-wifi.sh): BIOS version: `dmidecode | grep -A 5 BIOS | grep Version | awk '{print ""$2""}'`"
    echo "DEBUG (acpi-eeepc-generic-toggle-wifi.sh): Running kernel: `uname -a`"
    if [ -e /usr/bin/pacman ]; then
        echo "DEBUG (acpi-eeepc-generic-toggle-wifi.sh): Installed kernel(s):"
        /usr/bin/pacman -Qs kernel26
    fi
    echo "DEBUG (acpi-eeepc-generic-toggle-webcam.sh): Device: $CAMERA_DEVICE"
    echo "DEBUG (acpi-eeepc-generic-toggle-webcam.sh): Driver: $CAMERA_DRIVER"
    echo "DEBUG (acpi-eeepc-generic-toggle-webcam.sh): State: $CAMERA_STATE"

    eeepc_notify "Webcam
Device: $CAMERA_DEVICE
Driver: $CAMERA_DRIVER
State: $CAMERA_STATE" camera-web 10000
}

function webcam_on {
    show_notifications=1
    [ "$2" == "0" ] && show_notifications=0

    [ "$CAMERA_STATE" == "1" ] && eeepc_notify "Webcam already tuned on!" camera && return 0

    [ "$show_notifications" == "1" ] && eeepc_notify "Turning webcam on..." camera

    # Enable camera
    [ -e "$CAMERA_DEVICE" ] && echo 1 > $CAMERA_DEVICE

    # Load module
    /sbin/modprobe $CAMERA_DRIVER 2>/dev/null
    if [ $? ]; then
        # If successful, enable card
        echo 1 > $CAMERA_SAVED_STATE_FILE
        [ -e $CAMERA_DEVICE ] && \
            echo 1 > $CAMERA_DEVICE

        [ "$show_notifications" == "1" ] && eeepc_notify "Webcam is now on" camera
    else
        [ "$show_notifications" == "1" ] && eeepc_notify "Could not enable webcam" stop
    fi
}

function webcam_off {
    show_notifications=1
    [ "$2" == "0" ] && show_notifications=0

    [ "$CAMERA_STATE" == "0" ] && eeepc_notify "Webcam already tuned off!" camera && return 0

    [ "$show_notifications" == "1" ] && eeepc_notify "Turning webcam off..." camera

    [ -e "$CAMERA_DEVICE" ] && echo 0 > $CAMERA_DEVICE

    if [ $? ]; then
        # Disabling camera
        [ -e $CAMERA_DEVICE ] && echo 0 > $CAMERA_DEVICE

        echo 0 > $CAMERA_SAVED_STATE_FILE

        [ "$show_notifications" == "1" ] && eeepc_notify "Webcam is now off" camera
    else
        # If module unloading unsuccessful, try again
        [ "$show_notifications" == "1" ] && eeepc_notify "Could not disable webcam" stop
    fi
}

function webcam_toggle {
    if [ "$CAMERA_STATE" = "1" ]; then
        webcam_off 1
    else
        webcam_on 1
    fi
}


case $1 in
    "debug")
        debug_webcam
    ;;
    "off")
        webcam_off 1
    ;;
    "on")
        webcam_on 1
    ;;
    *)
        webcam_toggle
    ;;
esac

