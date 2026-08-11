#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

: "${INSTALL_IMAGE_PAYLOAD:?INSTALL_IMAGE_PAYLOAD is required}"

install -d "$(realpath /root)" /var/mnt /var/tmp
mount -o remount,rw /proc/sys 2>/dev/null || true

dnf5 versionlock clear || true
dnf5 install -y \
    anaconda-live anaconda-install-env-deps anaconda-dracut \
    libblockdev-btrfs libblockdev-lvm libblockdev-dm \
    dracut-live dracut-config-generic dracut-network \
    livesys-scripts grub2-efi-x64-cdboot \
    squashfs-tools xorriso net-tools firefox

if mountpoint -q /usr/lib/containers/storage; then
    podman save --format oci-archive "$INSTALL_IMAGE_PAYLOAD" | \
        podman load --storage-opt additionalimagestore=''
else
    podman pull "$INSTALL_IMAGE_PAYLOAD"
fi

image_ref=${INSTALL_IMAGE_PAYLOAD##*://}

cat >>/usr/share/anaconda/interactive-defaults.ks <<EOF

ostreecontainer --url=${image_ref} --transport=containers-storage --no-signature-verification

%post --erroronfail --log=/root/axioma-bootc-switch.log
bootc switch --mutate-in-place --enforce-container-sigpolicy --transport registry ${image_ref}
%end
EOF

# A live ISO uses Fedora's signed kernel. The installed payload retains OGC.
mapfile -t kernel_packages < <(rpm -qa 'kernel*' --qf '%{NAME}\n' | sort -u)
dnf5 versionlock delete "${kernel_packages[@]}" 2>/dev/null || true
dnf5 remove -y --setopt=protect_running_kernel=false "${kernel_packages[@]}" || true
rm -rf /usr/lib/modules/*
dnf5 install -y --repo=fedora,updates kernel kernel-core kernel-modules

kernel=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
depmod "$kernel"
DRACUT_NO_XATTR=1 dracut --force --verbose --zstd --reproducible --no-hostonly \
    --add 'dmsquash-live dmsquash-live-autooverlay anaconda' \
    "/usr/lib/modules/${kernel}/initramfs.img" "$kernel"

if [[ -f /etc/sysconfig/livesys ]]; then
    sed -i 's/^livesys_session=.*/livesys_session=cosmic/' /etc/sysconfig/livesys
fi
systemctl enable livesys.service livesys-late.service

install -Dm0644 /src/installer/files/axioma-installer.desktop \
    /etc/skel/.config/autostart/axioma-installer.desktop
install -Dm0755 /src/installer/files/axioma-live-welcome \
    /usr/bin/axioma-live-welcome

install -d /usr/lib/bootc-image-builder /boot/efi
install -m0644 /src/installer/iso.yaml /usr/lib/bootc-image-builder/iso.yaml
cp -a /usr/lib/efi/*/*/EFI /boot/efi/

install -d /etc/systemd/system
cat >/etc/systemd/system/var-tmp.mount <<'EOF'
[Unit]
Description=Large temporary filesystem for the live installer
[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=size=50%,nr_inodes=1m
[Install]
WantedBy=local-fs.target
EOF
systemctl enable var-tmp.mount

dnf5 clean all
rm -rf /var/cache/dnf /var/cache/libdnf5

