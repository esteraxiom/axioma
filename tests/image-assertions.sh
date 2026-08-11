#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

expected_kernel=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel)
mapfile -t module_trees < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
[[ ${#module_trees[@]} -eq 1 ]]
[[ ${module_trees[0]} == "$expected_kernel" ]]
[[ -f "/usr/lib/modules/${expected_kernel}/initramfs.img" ]]

rpm -q niri cosmic-session cosmic-greeter steam lutris terra-gamescope \
    nvidia-driver vicinae quickshell zram-generator
command -v dms cosmic-ext-alternative-startup xwayland-satellite axioma-setup

kmod_version=$(rpm -q --qf '%{VERSION}' kmod-nvidia)
driver_version=$(rpm -q --qf '%{VERSION}' nvidia-driver)
[[ "$kmod_version" == "$driver_version" ]]

modinfo -k "$expected_kernel" nvidia >/dev/null
modinfo -k "$expected_kernel" xone-gip-gamepad >/dev/null 2>&1 || \
    modinfo -k "$expected_kernel" xone_gip_gamepad >/dev/null
modinfo -k "$expected_kernel" hid-xpadneo >/dev/null

test -f /usr/share/wayland-sessions/axioma-cosmic-niri.desktop
test -f /usr/share/wayland-sessions/niri.desktop
test -f /usr/share/axioma/niri/cosmic-base.kdl

systemctl is-enabled cosmic-greeter.service
systemctl is-enabled uupd.timer
systemctl is-enabled axioma-flatpak-setup.service
if systemctl is-enabled --quiet tailscaled.service; then exit 1; fi
if systemctl is-enabled --quiet waydroid-container.service; then exit 1; fi
if systemctl is-enabled --quiet cockpit.socket; then exit 1; fi
for forbidden in plasma-desktop gnome-shell sddm gdm; do
    if rpm -q "$forbidden"; then exit 1; fi
done

bootc container lint
echo 'Image assertions passed.'
