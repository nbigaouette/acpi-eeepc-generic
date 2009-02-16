#!/bin/bash

. /etc/conf.d/acpi-eeepc-generic.conf

[ ! -d "$EEEPC_VAR/states" ] && mkdir -p $EEEPC_VAR/states

chmod a+w /var/eeepc/states/* &> /dev/null

# Extract kernel version
KERNEL=`uname -r`
KERNEL=${KERNEL%%-*}
KERNEL_maj=${KERNEL%%\.*}
k=${KERNEL#${KERNEL_maj}.}
KERNEL_min=${k%%\.*}
k=${KERNEL#${KERNEL_maj}.${KERNEL_min}.}
KERNEL_rel=${k%%\.*}
k=${KERNEL#${KERNEL_maj}.${KERNEL_min}.${KERNEL_rel}}
KERNEL_patch=${k%%\.*}

#################################################################
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

#################################################################
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

#################################################################
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

#################################################################
function send_dzen() {
    if [ ! -e /usr/bin/dzen2 ]; then
        logger "To use dzen's OSD, please install 'dzen2'"
        echo   "To use dzen's OSD, please install 'dzen2'"
        return 1
    fi
    duration=$3
    [ "x$duration" == "x" ] && duration="2000"
    duration=$(( 5 * $duration / 1000 ))
    cmd="(echo \"$1\"; sleep $duration) | /usr/bin/dzen2 &"
    send_generic "${cmd}"
}

#################################################################
function send_generic() {
    if [ "x$UID" == "x0" ]; then
        /bin/su $user --login -c "${@}"
    else
        bash -c "${@}"
    fi
}

#################################################################
function print_commands() {
    cmds=( "$@" )
    cmds_num=${#cmds[@]}
    [ "$cmds_num" == "0" ] && echo "NONE"
    for ((i=0;i<${cmds_num};i++)); do
        c=${cmds[${i}]}
        echo "#$(($i+1)): $c"
    done
}

#################################################################
function execute_commands() {
    [ "x$EEEPC_CONF_DONE" == "xno" ] && eeepc_notify "PLEASE EDIT YOUR CONFIGURATION FILE:
/etc/conf.d/acpi-eeepc-generic.conf" stop 20000
    cmds=( "$@" )
    cmds_num=${#cmds[@]}
    for ((i=0;i<${cmds_num};i++)); do
        c=${cmds[${i}]}
        if [ "${c:0:1}" == "@" ]; then
            logger "execute_commands (as user $user) #$(($i+1)): $c"
            echo "execute_commands (as user $user) #$(($i+1)): $c"
            /bin/su $user --login -c "${c:1} &"
        else
            logger "execute_commands #$(($i+1)): $c"
            echo "execute_commands #$(($i+1)): $c"
            ${c}
        fi
    done
}

#################################################################
function volume_is_mute() {
    # 1 is true, 0 is false
    on_off=`amixer get ${ALSA_MUTE_MIXER} | grep -A 1 -e Mono | grep Playback | awk '{print ""$4""}'`
    is_muted=0
    [ "$on_off" == "[off]" ] && is_muted=1
    echo $is_muted
}

#################################################################
function get_volume() {
    echo `amixer get ${ALSA_MAIN_MIXER} | grep -A 1 -e Mono | grep Playback | awk '{print ""$5""}' | sed -e "s|\[||g" -e "s|]||g" -e "s|\%||g"`
}

#################################################################
function get_output_mixers() {
    mixers=`amixer scontrols | awk '{print ""$4""}' | sed -e "s|'||g" -e "s|,0||g"`
    i=0
    for m in ${mixers}; do
        # If not a capture, its a playback
        if [ "`amixer sget $m | grep -i capture`" == "" ]; then
            output_mixers[i]=$m
            i=$((i+1))
        fi
    done
    #echo "mixers: ${mixers}"
    #echo "nb: ${#mixers[@]}"
    #echo "output_mixers: ${output_mixers[@]}"
    #echo "nb: ${#output_mixers[@]} $i"
    echo ${output_mixers[@]}
}

#################################################################
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

#################################################################
function brightness_get_percentage() {
    actual_brightness=`cat /sys/class/backlight/eeepc/actual_brightness`
    maximum_brightness=`cat /sys/class/backlight/eeepc/max_brightness`
    echo $((10000*$actual_brightness / (100*$maximum_brightness) ))
}

#################################################################
function brightness_set_percentage() {
    #actual_brightness=`cat /sys/class/backlight/eeepc/actual_brightness`
    maximum_brightness=`cat /sys/class/backlight/eeepc/max_brightness`
    to_set=$(( $1 * $maximum_brightness / 100 ))
    #echo "max = $maximum_brightness"
    #echo "now = $actual_brightness"
    #echo "1 = $1"
    #echo "to set = $to_set"
    echo $to_set > /sys/class/backlight/eeepc/brightness
}

#################################################################
function restore_brightness() {
    to_set=`cat /var/eeepc/states/brightness`
    echo $to_set > /sys/class/backlight/eeepc/brightness
}

#################################################################
function brightness_set_absolute() {
    echo $1 > /sys/class/backlight/eeepc/brightness
}

#################################################################
function brightness_find_direction() {
    actual_brightness=`cat /sys/class/backlight/eeepc/actual_brightness`
    previous_brightness=`cat /var/eeepc/states/brightness`
    [ "x$previous_brightness" == "x" ] && previous_brightness=$actual_brightness
    to_return=""
    [ $actual_brightness -lt $previous_brightness ] && to_return="down"
    [ $actual_brightness -gt $previous_brightness ] && to_return="up"
    echo $actual_brightness > /var/eeepc/states/brightness
    echo $to_return
}

#################################################################
# Get username
if [ -S /tmp/.X11-unix/X0 ]; then
    export DISPLAY=:0
    [ "x$user" == "x" ] && user=$(who | head -1 | awk '{print $1}')
    # If autodetection fails, try another way...
    user=$(who | sed -n '/ (:0[\.0]*)$\| :0 /{s/ .*//p;q}')
    # If autodetection fails, try another way...
    [ "x$user" == "x" ] && user=$(ps aux | awk '{print ""$1""}' | \
        sort | uniq | \
        grep -v \
            -e avahi -e bin -e dbus -e ftp-e hal -e nobody \
            -e ntp -e nx -e policykit -e privoxy -e root \
            -e tor -e USER \
        )
    # If autodetection fails, fallback to default user
    # set in /etc/conf.d/acpi-eeepc-generic.conf
    [ "x$user" == "x" ] && user=$XUSER
    # If user is empty, notify
    [ "x$user" == "x" ] && \
        eeepc_notify "User autodetection failed. Please edit your 
configuration file (/etc/conf.d/acpi-eeepc-generic.conf) and set 
XUSER variable to your username" stop
    home=$(getent passwd $user | cut -d: -f6)
    XAUTHORITY=$home/.Xauthority
    [ -f $XAUTHORITY ] && export XAUTHORITY
fi


#################################################################
#################################################################
