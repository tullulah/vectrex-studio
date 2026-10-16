#!/bin/bash
# The .deb's post-remove: electron-builder's own, plus the AppArmor profile out again.

EXE='vpy-ide'

# Delete the link to the binary
if type update-alternatives >/dev/null 2>&1; then
    update-alternatives --remove "$EXE" "/usr/bin/$EXE"
else
    rm -f "/usr/bin/$EXE"
fi

if [ -f "/etc/apparmor.d/$EXE" ]; then
    if hash apparmor_parser 2>/dev/null; then
        apparmor_parser --remove "/etc/apparmor.d/$EXE" 2>/dev/null || true
    fi
    rm -f "/etc/apparmor.d/$EXE"
fi
