# Contributor: Nicolas Bigaouette nbigaouette a_t gmail c o m

pkgname=acpi-eeepc-generic
pkgver=1.0
pkgrel=0.1
pkgdesc="ACPI scripts for EeePC netbook computers (700, 701, 900, 900A, 901, 904HD, S101, 1000, 1000H, 1000HD, 1000HE)"
url="http://code.google.com/p/acpi-eeepc-generic/"
arch=(any)
license=(GPL3)
depends=(acpid xorg-server-utils dmidecode)
optdepends=(
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
    "eeepc-suspend-lock.desktop")

md5sums=('07e82644997f2a12911511cbde9c158d'
         '07e82644997f2a12911511cbde9c158d'
         '07e82644997f2a12911511cbde9c158d'
         '2a5807c11264c753f0609d6cd55d81ed'
         'c5dc209025f5b0923c00729fef85633c'
         'dc83b07fd398f237faaf305cb56ee278'
         'dc83b07fd398f237faaf305cb56ee278'
         '45573412b704eb599b6705afe12bb432'
         '45573412b704eb599b6705afe12bb432'
         'db451374b504c0cf3459931a376a4ec3'
         '0f175b043418b17e61b48a34fe30dcab'
         'd48945a8142aab647f76ad2e98fc5c3f'
         'b32bafaf56a7e489bfd9dea2000a5689'
         '8068d8ba142f223832a19472afb934cf'
         'cf253e386d7e743a3d25ec4165051521'
         'fe03a179a105fa6a95f7498fa1deaf96'
         '66622ba2974a9f67da93dfecccd3a202'
         '91f27d2a66b8907f86b14d4ac9a48e2f'
         '7e26565bd36e2411ab998d6bcfe15f9e'
         '13c38e64dab996301f8d724342178cfc'
         'ee7ee3ac79d46a14f47cbfb3edac8cbd'
         '8e5f6c2dcdd2c16e095ab58726f09e1e'
         'ed03fa563c36c23ffbf586cfaff5a14d'
         '45738315630165b45470694a67c8121d'
         'd231ec9fd49a1a9413265ea52526d621'
         '12c506d5a4ae304833f22f04b5d5c1f0'
         'ae9cc2beecc1990688bf811cbe075642'
         'c28c987e7bf99e244d63c21c336f7e87'
         '8668240f98b6500107fe675dbe898ebf'
         'd8ea2a77d7176c85b348a1dafb064346'
         '03bfa167e2e22a6906e3d0daab92becd'
         'b6e3ad05a0d6c9ed87bd0859267e86d8'
         '4d9af939dbd59121cd4bb191d340eb1c'
         '3adb93ff8f99bf6ce7746acf119df0fd'
         '6e46b54564cdd14f2588c921c0a7faf1')

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

    install -m0755 ${srcdir}/eeepc-suspend-lock.desktop ${pkgdir}/usr/share/applications || return 1
    install -m0644 ${srcdir}/eee.png ${pkgdir}/usr/share/pixmaps || return 1
    install -m0644 ${srcdir}/bluetooth.png ${pkgdir}/usr/share/pixmaps || return 1
}
