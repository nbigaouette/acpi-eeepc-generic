#!/bin/bash

. /etc/conf.d/acpi-eeepc-generic.conf

[ ! -d "$EEEPC_VAR" ] && mkdir -p $EEEPC_VAR

KERNEL=`uname -r`
KERNEL=${KERNEL%%-*}
KERNEL_maj=${KERNEL%%\.*}
k=${KERNEL#${KERNEL_maj}.}
KERNEL_min=${k%%\.*}
k=${KERNEL#${KERNEL_maj}.${KERNEL_min}.}
KERNEL_rel=${k%%\.*}
k=${KERNEL#${KERNEL_maj}.${KERNEL_min}.${KERNEL_rel}}
KERNEL_patch=${k%%\.*}

# Get username
if [ -S /tmp/.X11-unix/X0 ]; then
    export DISPLAY=:0
    user=$(who | sed -n '/ (:0[\.0]*)$\| :0 /{s/ .*//p;q}')
    # If autodetection fails, try another way...
    [ "x$user" == "x" ] && user=`ps aux | awk '{print ""$1""}' | sort | uniq | grep -v root | grep -v hal | grep -v ntp | grep -v dbus | grep -v bin | grep -v USER`
    # If autodetection fails, fallback to default user
    # set in /etc/conf.d/acpi-eeepc-generic.conf
    [ "x$user" == "x" ] && user=$XUSER
    home=$(getent passwd $user | cut -d: -f6)
    XAUTHORITY=$home/.Xauthority
    [ -f $XAUTHORITY ] && export XAUTHORITY
fi

function eeepc_notify {
    if [ "$NOTIFY" == "libnotify" ]; then
        send_libnotify "$1" "$2" "$3"
    elif [ "$NOTIFY" == "kdialog" ]; then
        send_kdialog "$1" "$2" "$3"
    elif [ "$NOTIFY" == "dzen" ]; then
        send_dzen "$1" "$2" "$3"
    fi
    logger "EeePC $EEEPC_MODEL: $1 ($2)"
}

function send_libnotify() {
    if [ ! -e /usr/bin/notify-send ]; then
        logger "To use libnotify's OSD, please install 'notification-daemon'"
        echo   "To use libnotify's OSD, please install 'notification-daemon'"
        return 1
    fi
    duration=$3
    [ "x$duration" == "x" ] && duration="1500"
    cmd="/usr/bin/notify-send -i $2 -t $duration \"EeePC $EEEPC_MODEL\" \"$1\""
    send_generic "${cmd}"
}

function send_kdialog() {
    if [ ! -e /usr/bin/kdialog ]; then
        logger "To use kdialog's OSD, please install 'kdebase'"
        echo   "To use kdialog's OSD, please install 'kdebase'"
        return 1
    fi
    duration=$3
    [ "x$duration" == "x" ] && duration="2000"
    duration=$(( $duration / 1000 ))
    cmd="/usr/bin/kdialog --passivepopup \"$1\" --title \"EeePC $EEEPC_MODEL\" $duration"
    send_generic "${cmd}"
}

function send_dzen() {
    if [ ! -e /usr/bin/dzen2 ]; then
        logger "To use dzen's OSD, please install 'dzen2'"
        echo   "To use dzen's OSD, please install 'dzen2'"
        return 1
    fi
    duration=$3
    [ "x$duration" == "x" ] && duration="2000"
    duration=$(( 5 * $duration / 1000 ))
    cmd="(echo \"$1\"; sleep $duration) | /usr/bin/dzen2"
#    cmd="/usr/bin/dzen2 --passivepopup \"$1\" --title \"EeePC $EEEPC_MODEL\" $duration"
    send_generic "${cmd}"
}

function send_generic() {
    if [ "x$UID" == "x0" ]; then
        /bin/su $user --login -c "${@}"
    else
        bash -c "${@}"
    fi
}

function print_commands() {
    cmds=( "$@" )
    cmds_num=${#cmds[@]}
    [ "$cmds_num" == "0" ] && echo "NONE"
    for ((i=0;i<${cmds_num};i++)); do
        c=${cmds[${i}]}
        echo "#$(($i+1)): $c"
    done
}
function execute_commands() {
    [ "x$EEEPC_CONF_DONE" == "xno" ] && eeepc_notify "PLEASE EDIT YOUR CONFIGURATION FILE:
/etc/conf.d/acpi-eeepc-generic.conf" stop 20000
    cmds=( "$@" )
    cmds_num=${#cmds[@]}
    for ((i=0;i<${cmds_num};i++)); do
        c=${cmds[${i}]}
        logger "execute_commands #$(($i+1)): $c"
        echo "execute_commands #$(($i+1)): $c"
        ${c} &
    done
}
function execute_commands_as_user() {
    cmds=( "$@" )
    cmds_num=${#cmds[@]}
    for ((i=0;i<${cmds_num};i++)); do
        c=${cmds[${i}]}
        logger "execute_commands_as_user #$(($i+1)): $c"
        echo "execute_commands_as_user #$(($i+1)): $c"
        su $user --login -c "${c} &"
    done
}

function volume_is_mute() {
    # 0 is true, 1 is false
    on_off=`amixer get iSpeaker | grep -A 1 -e Mono | grep Playback | awk '{print ""$4""}'`
    is_muted=1
    [ "$on_off" == "[off]" ] && is_muted=0
    return $is_muted
}

function get_volume() {
    echo `amixer get PCM | grep -A 1 -e Mono | grep Playback | awk '{print ""$5""}' | sed -e "s|\[||g" -e "s|]||g" -e "s|\%||g"`
}

function get_model() {
    if [ -z "${EEEPC_MODEL}" ]; then
        echo "EEEPC_MODEL=\"$(dmidecode -s system-product-name | sed 's/[ \t]*$//')\"" >> /etc/conf.d/acpi-eeepc-generic.conf
        CPU=NONE
        grep_cpu=`grep Celeron /proc/cpuinfo`
        [ "x$grep_cpu" != "x" ] && CPU="Celeron"
        grep_cpu=`grep Atom /proc/cpuinfo`
        [ "x$grep_cpu" != "x" ] && CPU="Atom"
        echo "EEEPC_CPU=\"$CPU\"" >> /etc/conf.d/acpi-eeepc-generic.conf
    fi
}

function brightness_get_percentage() {
    actual_brightness=`cat /sys/class/backlight/eeepc/actual_brightness`
    maximum_brightness=`cat /sys/class/backlight/eeepc/max_brightness`
    echo $((10000*$actual_brightness / (100*$maximum_brightness) ))
}

function brightness_find_direction() {
    actual_brightness=`cat /sys/class/backlight/eeepc/actual_brightness`
    previous_brightness=`cat /var/eeepc/brightness_saved`
    [ "x$previous_brightness" == "x" ] && previous_brightness=$actual_brightness
    to_return="up"
    [ $actual_brightness -lt $previous_brightness ] && to_return="down"
    echo $actual_brightness > /var/eeepc/brightness_saved
    echo $to_return
}


