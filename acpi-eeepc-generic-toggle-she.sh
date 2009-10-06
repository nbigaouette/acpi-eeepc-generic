#!/bin/bash
# Copyright 2009 Nicolas Bigaouette
# This file is part of acpi-eeepc-generic.
# http://code.google.com/p/acpi-eeepc-generic/
#
# acpi-eeepc-generic is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# acpi-eeepc-generic is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with acpi-eeepc-generic.  If not, see <http://www.gnu.org/licenses/>.

. /etc/acpi/eeepc/acpi-eeepc-generic-functions.sh


### Information #################################################
DRIVERS=()
NAME="Super Hybrid Engine"
NAME_SMALL="she"
ICON="cpu"
SYS_NAME="cpufv"
COMMANDS_PRE_UP=""
COMMANDS_PRE_DOWN=""
COMMANDS_POST_UP=""
COMMANDS_POST_DOWN=""


### Load saved state from file ##################################
load_saved_state

### Check /sys interface ########################################
check_sys_interface

### Detect if card is enabled or disabled #######################
detect_if_enabled

### Toggle Super Hybrid Engine ##################################
# function she_toggle() {
#
# }

#################################################################
case $1 in
    "debug")
        print_generic_debug
    ;;
    "powersave")
        echo 2 > ${SYS_DEVICE}
        # 770
    ;;
    "normal")
        echo 1 > ${SYS_DEVICE}
        # 769
    ;;
    "performance")
        echo 0 > ${SYS_DEVICE}
        # 768
    ;;
    *)
        she_toggle
    ;;
esac

### End of file #################################################

