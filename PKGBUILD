# Contributor: Nicolas Bigaouette nbigaouette a_t gmail c o m

pkgname=acpi-eeepc-generic
pkgver=1.0rc2
pkgrel=0.1
pkgdesc="ACPI scripts for EeePC netbook computers (700, 701, 900, 900A, 901, 904HD, S101, 1000, 1000H, 1000HD, 1000HE)"
url="http://code.google.com/p/acpi-eeepc-generic/"
arch=(any)
license=(GPL3)
depends=(acpid xorg-server-utils dmidecode)
optdepends=(
    "unclutter: Hide cursor when touchpad is disabled"
    "kdebase-runtime: KDE's super-user privileges gaining"
    "kdebase-kdialog: KDE's OSD"
    "sudo: super-user privileges gaining"
    "gksu: GNOME/GTK super-user privileges gaining"
)
install=$pkgname.install
backup=(etc/conf.d/acpi-eeepc-generic.conf)
conflicts=("acpi-eee" "acpi-eee900" "acpi-eee901" "acpi-eee1000" "acpi-eeepc900" "buttons-eee901" "e3acpi" "eee-control" "eee-fan")
source=(
    "acpi-eeepc-1000-events.conf"
    "acpi-eeepc-1000H-events.conf"
    "acpi-eeepc-1000HD-events.conf"
    "acpi-eeepc-1000HE-events.conf"
    "acpi-eeepc-1005-HA-H-events.conf"
    "acpi-eeepc-1005HA-events.conf"
    "acpi-eeepc-1008HA-events.conf"
    "acpi-eeepc-700-events.conf"
    "acpi-eeepc-701-events.conf"
    "acpi-eeepc-900-events.conf"
    "acpi-eeepc-900A-events.conf"
    "acpi-eeepc-901-events.conf"
    "acpi-eeepc-904HD-events.conf"
    "acpi-eeepc-S101-events.conf"
    "acpi-eeepc-defaults-events.conf"
    "acpi-eeepc-generic-events"
    "acpi-eeepc-generic-functions.sh"
    "acpi-eeepc-generic-handler.sh"
    "acpi-eeepc-generic-logsbackup.rcd"
    "acpi-eeepc-generic-restore.rcd"
    "acpi-eeepc-generic-rotate-lvds.sh"
    "acpi-eeepc-generic-suspend2ram.sh"
    "acpi-eeepc-generic-toggle-bluetooth.sh"
    "acpi-eeepc-generic-toggle-cardr.sh"
    "acpi-eeepc-generic-toggle-displays.sh"
    "acpi-eeepc-generic-toggle-lock-suspend.sh"
    "acpi-eeepc-generic-toggle-resolution.sh"
    "acpi-eeepc-generic-toggle-she.sh"
    "acpi-eeepc-generic-toggle-touchpad.sh"
    "acpi-eeepc-generic-toggle-webcam.sh"
    "acpi-eeepc-generic-toggle-wifi.sh"
    "acpi-eeepc-generic.conf"
    "bluetooth.png"
    "eee.png"
    "eeepc-rotate-lvds.desktop"
    "eeepc-suspend-lock.desktop"
    "eeepc-suspend2ram.desktop"
    "eeepc-toggle.desktop")

md5sums=('be2c9c078c781185356c775f7a785569'
         'be2c9c078c781185356c775f7a785569'
         'be2c9c078c781185356c775f7a785569'
         '8978b064b40be086942116b0c7779de6'
         'be56ea98b9aa016098bdab9cbb110334'
         '5ec8097c18e623d6ba2bff1f5a814885'
         '5ec8097c18e623d6ba2bff1f5a814885'
         '75016dde1f414772434c2c151b159c29'
         '75016dde1f414772434c2c151b159c29'
         'ae981fe86cd99b736ba740fffbfec3e0'
         'a34fbf623a7d3e41cdf378924837dbbe'
         '0e7c2e4cdcb2894d67cb62f526ae491d'
         '533018701f2f67873396994ec364bb36'
         'ce02758525ba114f2f0ab3d5c564d4f3'
         '323c03e32baec7eca3f360a282490cda'
         'cf253e386d7e743a3d25ec4165051521'
         '06ac985d224b36ac5822ccaeb2349e45'
         '9d2c81af757aad3eb4569082209351ed'
         '06137998d8ef768763bb327f8716641e'
         '7e26565bd36e2411ab998d6bcfe15f9e'
         '13c38e64dab996301f8d724342178cfc'
         '266d068f186ea33c1851d20476847aeb'
         '3927305c811cef63ae52e803a169d7b2'
         'e956bc5d3761630f3c01b8b7df80f1d1'
         '45738315630165b45470694a67c8121d'
         '87a977662d92c640b21b97e1c705ad57'
         '12c506d5a4ae304833f22f04b5d5c1f0'
         '614647590c18eb4de123263bd7bceaa8'
         'ca53efde37b4484ca05a5a9dddde423c'
         'fb7539a926831b28050267e13394c831'
         '39f88b5f21b1249a1da04e921deeec95'
         '98b7a18979b830661d639daeba738074'
         'b6e3ad05a0d6c9ed87bd0859267e86d8'
         '4d9af939dbd59121cd4bb191d340eb1c'
         '65f4a9f8b860500ee9e24440f167be2d'
         'b0f1db5801d32668aa76437cf40e9879'
         '8377c74074844a14c9588d10f6e152e4'
         '05e95ab6b843c08a5e66d1b3770a50d9')

build() {
    mkdir -p $pkgdir/{etc/{acpi/{eeepc/models,events},conf.d,rc.d},usr/share/{applications,pixmaps}} || return 1

    # Install our own handler
    install -m0755 ${srcdir}/acpi-eeepc-generic-handler.sh ${pkgdir}/etc/acpi/acpi-eeepc-generic-handler.sh || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-functions.sh ${pkgdir}/etc/acpi/eeepc/acpi-eeepc-generic-functions.sh || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-events ${pkgdir}/etc/acpi/events/acpi-eeepc-generic-events || return 1

    install -m0644 ${srcdir}/acpi-eeepc-generic.conf ${pkgdir}/etc/conf.d/acpi-eeepc-generic.conf || return 1

    # Install events configuration files for each model
    for f in ${srcdir}/acpi-eeepc-*-events.conf; do
        install -m0644 $f ${pkgdir}/etc/acpi/eeepc/models || return 1
    done

    install -m0755 ${srcdir}/acpi-eeepc-generic-restore.rcd ${pkgdir}/etc/rc.d/eeepc-restore || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-logsbackup.rcd ${pkgdir}/etc/rc.d/logsbackup || return 1

    # Helper scripts
    install -m0755 ${srcdir}/acpi-eeepc-generic-rotate-lvds.sh ${pkgdir}/etc/acpi/eeepc || return 1
    install -m0755 ${srcdir}/acpi-eeepc-generic-suspend2ram.sh ${pkgdir}/etc/acpi/eeepc || return 1
    for f in ${srcdir}/acpi-eeepc-generic-toggle-*.sh; do
        install -m0755 $f ${pkgdir}/etc/acpi/eeepc || return 1
    done

    install -m0755 ${srcdir}/eeepc-rotate-lvds.desktop ${pkgdir}/usr/share/applications || return 1
    install -m0755 ${srcdir}/eeepc-suspend-lock.desktop ${pkgdir}/usr/share/applications || return 1
    install -m0755 ${srcdir}/eeepc-suspend2ram.desktop ${pkgdir}/usr/share/applications || return 1
    for action in bluetooth cardr displays resolution she touchpad webcam wifi; do
        install -m0755 ${srcdir}/eeepc-toggle.desktop ${pkgdir}/usr/share/applications/eeepc-toggle-${action}.desktop || return 1
        sed -e "s|GENERIC|${action}|g" -i ${pkgdir}/usr/share/applications/eeepc-toggle-${action}.desktop || return 1
    done

    install -m0644 ${srcdir}/eee.png ${pkgdir}/usr/share/pixmaps || return 1
    install -m0644 ${srcdir}/bluetooth.png ${pkgdir}/usr/share/pixmaps || return 1
}
