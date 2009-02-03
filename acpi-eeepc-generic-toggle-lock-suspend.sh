#!/bin/sh

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh

lock="${EEEPC_VAR}/power.lock"

if [ -e "$lock" ]; then
    msg="You can now suspend normally"
    rm -f $lock
    logger "$msg"
    eeepc_notify "$msg" gnome-session-suspend
    exit 0
else
    msg="Suspend is now blocked"
    touch $lock
    logger "$msg"
    eeepc_notify "$msg" stop
    exit 0
fi

