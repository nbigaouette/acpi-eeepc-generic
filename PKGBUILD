# Contributor: Nicolas Bigaouette nbigaouette a_t gmail c o m

pkgname=acpi-eeepc-generic
pkgver=0.9.3
pkgrel=1
pkgdesc="ACPI scripts for EeePC netbook computers (700, 701, 900, 900A, 901, 904HD, S101, 1000, 1000H, 1000HD, 1000HE)"
url="http://code.google.com/p/acpi-eeepc-generic/"
arch=(any)
license=(GPL3)
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
    "acpi-eeepc-1000HE-events.conf"
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
    "acpi-eeepc-generic-toggle-displays.sh"
    "acpi-eeepc-generic-toggle-lock-suspend.sh"
    "acpi-eeepc-generic-toggle-resolution.sh"
    "acpi-eeepc-generic-toggle-touchpad.sh"
    "acpi-eeepc-generic-toggle-webcam.sh"
    "acpi-eeepc-generic-toggle-wifi.sh"
    "acpi-eeepc-generic.conf"
    "bluetooth.png"
    "eee.png"
    "eeepc-suspend-lock.desktop"
    "eeepc.desktop")

md5sums=('25bd92d98277a9fc85d0526667e20c72'
         '25bd92d98277a9fc85d0526667e20c72'
         '25bd92d98277a9fc85d0526667e20c72'
         '2bcb2acab06a06ac3b8a093070dfc783'
         '9cb149714f72e898e035e46b28b6cf94'
         '9cb149714f72e898e035e46b28b6cf94'
         'a8d84f7be1fd6f97a7f65db99bb58788'
         'c5d0521ea9058270d1ac6fd6b5fbfe70'
         '26e7a9ded8a342765abeb786417a0dfb'
         'bad61c7e5ec007e0c95f034e54399aa5'
         '510ff5ff6dac8ea7bad26ca956a7de56'
         'cf253e386d7e743a3d25ec4165051521'
         '340390ce925b4dfe307b8de82826158b'
         '6451b2bed31f7684a9bf4a1fcdb38ca6'
         '91f27d2a66b8907f86b14d4ac9a48e2f'
         '7e26565bd36e2411ab998d6bcfe15f9e'
         'cdfd2a0ddba5ad21ce4f08f1722fa784'
         'b482e6023981b8a2b9442cc945fb5727'
         '8e5f6c2dcdd2c16e095ab58726f09e1e'
         'fe6ced0bd5abf8f5425deacba646af09'
         'd231ec9fd49a1a9413265ea52526d621'
         '12c506d5a4ae304833f22f04b5d5c1f0'
         'b1f127a9b7808b22a1985a5b0301340b'
         '8668240f98b6500107fe675dbe898ebf'
         'e2c66aadc54e923076d7b69e6737a2af'
         'a2ae7f747cd1cf9a664cbc37aef02947'
         'b6e3ad05a0d6c9ed87bd0859267e86d8'
         '4d9af939dbd59121cd4bb191d340eb1c'
         '3adb93ff8f99bf6ce7746acf119df0fd'
         '6e46b54564cdd14f2588c921c0a7faf1')

build() {
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
    for f in ${srcdir}/acpi-eeepc-generic-toggle-*.sh; do
        install -m0755 $f ${pkgdir}/etc/acpi/eeepc
    done

    install -m0755 ${srcdir}/eeepc.desktop ${pkgdir}/usr/share/applications || return 1
    install -m0755 ${srcdir}/eeepc-suspend-lock.desktop ${pkgdir}/usr/share/applications || return 1
    install -m0644 ${srcdir}/eee.png ${pkgdir}/usr/share/pixmaps || return 1
    install -m0644 ${srcdir}/bluetooth.png ${pkgdir}/usr/share/pixmaps || return 1
}

