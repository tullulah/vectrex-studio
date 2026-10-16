#!/bin/bash
# The .deb's post-install: electron-builder's own (the /usr/bin link, the SUID sandbox
# helper, the desktop databases), plus an AppArmor profile.
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

if hash update-mime-database 2>/dev/null; then
    update-mime-database /usr/share/mime || true
fi

if hash update-desktop-database 2>/dev/null; then
    update-desktop-database /usr/share/applications || true
fi
