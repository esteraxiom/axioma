# Axioma

Axioma is a Fedora 44 bootc desktop image combining:

- COSMIC as the desktop environment
- niri as the default compositor through an integrated COSMIC-on-niri session
- native COSMIC and standalone niri recovery sessions
- the OGC kernel, NVIDIA-open modules, gaming runtime, tuning, update model and
  desktop conveniences selected from Bazzite

The published target is x86_64 with an RTX/GTX 16-series-or-newer NVIDIA GPU.
The initial machine is an i7-11700F workstation with an RTX 3090 and 32 GiB RAM.

> [!WARNING]
> COSMIC-on-niri is an upstream-unofficial integration. Keep native COSMIC
> available and test rollback before relying on this image as the only OS.

## Image and sessions

The OCI image is:

```text
ghcr.io/esteraxiom/axioma:testing
ghcr.io/esteraxiom/axioma:stable
```

COSMIC Greeter exposes:

1. **Axioma COSMIC on niri** — default integrated session
2. **COSMIC** — native recovery session
3. **niri** — standalone session with DMS and Vicinae

The integrated and standalone niri sessions deliberately use different files:

```text
~/.config/niri/cosmic.kdl
~/.config/niri/config.kdl
```

Machine-specific integrated overrides belong in
`~/.config/niri/cosmic-local.kdl`.

## Installation

Download the signed NVIDIA-open installer from the latest GitHub release and
verify it:

```bash
sha256sum -c axioma-*.iso.sha256
cosign verify-blob --key cosign.pub \
  --bundle axioma-*.iso.bundle axioma-*.iso
```

The ISO starts an interactive Anaconda installer. It never selects or erases a
disk automatically. For the first clariframe test:

- select the 223.6 GiB WD Green SSD (`/dev/sdc`) explicitly;
- use LUKS2 and Btrfs;
- create `esteraxiom` as the first user, which gives it UID/GID 1000;
- leave Secure Boot disabled;
- do not alter `/dev/sda`, `/dev/sdb`, or `/dev/sdd`.

See [the installation and migration guide](docs/installation.md).

## Updates and rollback

Daily successful builds are signed and published to `testing`. A tested digest
is manually promoted to `stable` without rebuilding it. Installed systems stage
verified stable updates and wait for a manual reboot.

```bash
ujust axioma-status
ujust axioma-update
ujust axioma-rollback
```

Verify an OCI digest directly:

```bash
cosign verify --key cosign.pub \
  ghcr.io/esteraxiom/axioma@sha256:REPLACE_WITH_DIGEST
```

## First-login setup

The Axioma Setup checklist provides explicit actions for:

```bash
ujust axioma-mount-data
ujust axioma-migrate-home
ujust axioma-setup-sunshine status
ujust axioma-setup-waydroid status
ujust axioma-setup-tailscale status
ujust axioma-setup-cockpit status
ujust axioma-setup-virtualization status
ujust axioma-enable-scx status
```

Sunshine, Waydroid, Tailscale, Cockpit, libvirt and sched-ext are disabled by
default. Each corresponding recipe accepts `enable` or `disable`.

## Gaming stack

Steam and Lutris are host packages. The image also includes gamescope, UMU,
MangoHud, vkBasalt, FAudio, OpenXR, multilib NVIDIA/Vulkan libraries and
Bazzite-derived resource management.

The following are installed from Flathub on first boot:

- Bazaar
- Bottles
- Heroic Games Launcher
- PCSX2
- RetroArch

Common Xbox, DualSense, Steam and generic controllers are supported. Specialty
racing-wheel, GameCube, DisplayLink and Looking Glass modules are not included.

## Secure Boot

The first installation keeps Secure Boot off. The OGC and NVIDIA kernel modules
are signed with Universal Blue's module-signing key. To enroll that key later:

```bash
ujust axioma-enroll-secure-boot-key
```

Complete the firmware MOK screen on reboot using `universalblue`. OCI Cosign
signing and UEFI Secure Boot are separate trust mechanisms.

## Development

Inputs are locked in [`build/versions.env`](build/versions.env). Upstream lock
updates arrive as PRs and must pass the full image build before merging.

```bash
bash tests/validate-repo.sh
just build testing
just image-test testing
```

Building the complete image requires rootful Podman, significant disk space and
access to GHCR, Fedora, COPR and Terra repositories.

The architecture and upstream boundaries are documented in
[`docs/architecture.md`](docs/architecture.md).

## License

Axioma's original and adapted source is GPL-3.0-only. Third-party components
retain their upstream licenses; see [`NOTICE`](NOTICE).
