#!/bin/sh

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh

if [ -e "${EEEPC_VAR}/power.lock" ]; then
    msg="Disabling suspend lock"
    logger "$msg"
    eeepc_notify "$msg" stop
    exit 0
else
    msg="Enabling suspend lock"
    logger "$msg"
    eeepc_notify "$msg" gnome-session-suspend
    exit 0
fi

