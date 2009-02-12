# Maintainer: Nicolas Bigaouette <nbigaouette@gmail.com>
# Greatly inspired by:
#   EeePC ACPI Utilities : http://eeepc-acpi-util.sourceforge.net
#   Other Eee acpi packages from AUR: http://aur.archlinux.org/packages.php?K=eee

# TODO
#   XRandR toggle between (see acpi-eeepc900, display.sh):
#       -LVDS only
#       -VGA only
#       -VGA clone of LVDS
#       -VGA left/right/below/top of LVDS
#   XOSD for really basic osd
#   Suspend2disk helper script
#   Wifi module autodetection + hacks (See acpi-eee 10.0-1's wlan.sh)
#   Volume devices autodetection (LineIn/LineOut/iSpeaker...)
#   Reset values of AC after resume (see powersource.sh, called at the end of suspend2ram.sh)
#   FSB+Fan control

pkgname=acpi-eeepc-generic
pkgver=0.8.0b
pkgrel=1
pkgdesc="ACPI scripts for EeePC netbook computers (700, 701, 900, 900A, 901, 904HD, S101, 1000, 1000H, 1000HD)"
url="http://code.google.com/p/acpi-eeepc-generic/"
arch=(any)
license=(GPL2)
depends=(acpid xorg-server-utils dmidecode)
optdepends=(
    "notification-daemon: On Screen Display (OSD) of notifications (GTK+)"
    "kdebase: On Screen Display (OSD) of notifications (KDE)"
    "dzen2: On Screen Display (OSD) with no depedencies"
    "lxtask: Lightweight task manager from LXDE"
    "lxrandr: Lightweight GUI for controling screen output from LXDE"
    "pcmanfm: Lightweight file browser from LXDE"
    "lxterminal: Lightweight terminal from LXDE"
    "wicd: Network connection GUI"
    "xf86-input-synaptics: Touchpad driver"
    "gksu: Graphical su frontend to edit the configuration file"
    "unclutter: Hide cursor when touchpad is disable"
)
install=$pkgname.install
backup=(etc/conf.d/acpi-eeepc-generic.conf)
conflicts=("acpi-eee" "acpi-eee900" "acpi-eee901" "acpi-eee1000" "acpi-eeepc900" "buttons-eee901" "e3acpi" "eee-control" "eee-fan")
source=(
    "acpi-eeepc-1000-events.conf"
    "acpi-eeepc-1000H-events.conf"
    "acpi-eeepc-1000HD-events.conf"
    "acpi-eeepc-700-events.conf"
    "acpi-eeepc-701-events.conf"
    "acpi-eeepc-900-events.conf"
    "acpi-eeepc-900A-events.conf"
    "acpi-eeepc-901-events.conf"
    "acpi-eeepc-904HD-events.conf"
    "acpi-eeepc-S101-events.conf"
    "acpi-eeepc-generic-events"
    "acpi-eeepc-generic-functions.sh"
    "acpi-eeepc-generic-handler.sh"
    "acpi-eeepc-generic-logsbackup.rcd"
    "acpi-eeepc-generic-restore.rcd"
    "acpi-eeepc-generic-rotate-lvds.sh"
    "acpi-eeepc-generic-suspend2ram.sh"
    "acpi-eeepc-generic-toggle-bluetooth.sh"
    "acpi-eeepc-generic-toggle-resolution.sh"
    "acpi-eeepc-generic-toggle-touchpad.sh"
    "acpi-eeepc-generic-toggle-wifi.sh"
    "acpi-eeepc-generic-toggle-lock-suspend.sh"
    "acpi-eeepc-generic.conf"
    "bluetooth.png"
    "eee.png"
    "eeepc.desktop"
    "eeepc-suspend-lock.desktop")

build() {
    #cd $srcdir/$pkgname-$pkgver

    mkdir -p $pkgdir/{etc/{acpi/{eeepc/models,events},conf.d,rc.d},usr/share/{applications,pixmaps}}

    # Install our own handler
    install -m0755 ${srcdir}/acpi-eeepc-generic-handler.sh ${pkgdir}/etc/acpi/acpi-eeepc-generic-handler.sh || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-functions.sh ${pkgdir}/etc/acpi/eeepc/acpi-eeepc-generic-functions.sh || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-events ${pkgdir}/etc/acpi/events/acpi-eeepc-generic-events || return 1

    install -m0644 ${srcdir}/acpi-eeepc-generic.conf ${pkgdir}/etc/conf.d/acpi-eeepc-generic.conf || return 1

    # Install events configuration files for each model
    for f in ${srcdir}/acpi-eeepc-*-events.conf; do
        install -m0644 $f ${pkgdir}/etc/acpi/eeepc/models
    done

    install -m0755 ${srcdir}/acpi-eeepc-generic-restore.rcd ${pkgdir}/etc/rc.d/eeepc-restore || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-logsbackup.rcd ${pkgdir}/etc/rc.d/logsbackup || return 1

    # Helper scripts
    install -m0755 ${srcdir}/acpi-eeepc-generic-rotate-lvds.sh ${pkgdir}/etc/acpi/eeepc || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-suspend2ram.sh ${pkgdir}/etc/acpi/eeepc || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-toggle-bluetooth.sh ${pkgdir}/etc/acpi/eeepc || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-toggle-resolution.sh ${pkgdir}/etc/acpi/eeepc || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-toggle-touchpad.sh ${pkgdir}/etc/acpi/eeepc || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-toggle-wifi.sh ${pkgdir}/etc/acpi/eeepc || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-toggle-lock-suspend.sh ${pkgdir}/etc/acpi/eeepc || return 1

    install -m0755 ${srcdir}/eeepc.desktop ${pkgdir}/usr/share/applications || return 1
    install -m0755 ${srcdir}/eeepc-suspend-lock.desktop ${pkgdir}/usr/share/applications || return 1
    install -m0644 ${srcdir}/eee.png ${pkgdir}/usr/share/pixmaps || return 1
    install -m0644 ${srcdir}/bluetooth.png ${pkgdir}/usr/share/pixmaps || return 1
}

