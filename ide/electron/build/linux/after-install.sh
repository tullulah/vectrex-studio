#!/bin/bash
# The .deb's post-install: electron-builder's own (the /usr/bin link, the SUID sandbox
# helper, the desktop databases), plus an AppArmor profile and a udev rule for the UVMC2.
#
# Ubuntu 23.10 and later restrict unprivileged user namespaces through AppArmor, which
# is what Chromium's sandbox is built on: without a profile the IDE dies at start with
# "No usable sandbox!" unless run with --no-sandbox. The profile below lets this one
# binary create them (unconfined otherwise), the way VS Code, Chrome and Slack ship.

APP='/opt/Vectrex Studio'
EXE='vpy-ide'

if type update-alternatives 2>/dev/null >&1; then
    # Remove previous link if it doesn't use update-alternatives
    if [ -L "/usr/bin/$EXE" -a -e "/usr/bin/$EXE" -a "`readlink "/usr/bin/$EXE"`" != "/etc/alternatives/$EXE" ]; then
        rm -f "/usr/bin/$EXE"
    fi
    update-alternatives --install "/usr/bin/$EXE" "$EXE" "$APP/$EXE" 100 || ln -sf "$APP/$EXE" "/usr/bin/$EXE"
else
    ln -sf "$APP/$EXE" "/usr/bin/$EXE"
fi

# SUID chrome-sandbox for Electron 5+
chmod 4755 "$APP/chrome-sandbox" || true

# AppArmor profile (only where AppArmor 4 is there: it is what knows the userns rule)
if [ -d /etc/apparmor.d ] && [ -f /etc/apparmor.d/abi/4.0 ]; then
    cat > "/etc/apparmor.d/$EXE" <<PROFILE
# Installed by the Vectrex Studio package: lets the IDE create the user
# namespaces Chromium's sandbox needs (Ubuntu 23.10+). Removed with the package.
abi <abi/4.0>,
include <tunables/global>

profile $EXE "$APP/$EXE" flags=(unconfined) {
  userns,

  include if exists <local/$EXE>
}
PROFILE
    if hash apparmor_parser 2>/dev/null; then
        apparmor_parser --replace --write-cache "/etc/apparmor.d/$EXE" || true
    fi
fi

# udev: the logged-in user may use the UVMC2 (Raspberry Pi VID 2E8A) without sudo or the
# dialout group: picotool (the multicart menu 0009, BOOTSEL 000F) and the serial port of the
# debug monitor / SD bridge (10DB). "uaccess" gives the seat's user an ACL on the device.
if [ -d /etc/udev/rules.d ]; then
    cat > /etc/udev/rules.d/60-vectrex-studio-uvmc2.rules <<'RULES'
# Installed by the Vectrex Studio package: Upload / Debug on Cartridge (UVMC2) over USB.
SUBSYSTEM=="usb", ATTR{idVendor}=="2e8a", TAG+="uaccess"
SUBSYSTEM=="tty", ATTRS{idVendor}=="2e8a", TAG+="uaccess"
RULES
    if hash udevadm 2>/dev/null; then
        udevadm control --reload-rules 2>/dev/null || true
        udevadm trigger --subsystem-match=usb --subsystem-match=tty 2>/dev/null || true
    fi
fi

if hash update-mime-database 2>/dev/null; then
    update-mime-database /usr/share/mime || true
fi

if hash update-desktop-database 2>/dev/null; then
    update-desktop-database /usr/share/applications || true
fi
