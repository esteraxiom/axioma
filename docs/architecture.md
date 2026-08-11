# Architecture

## Trust and update flow

```text
Fedora COSMIC Atomic digest
          +
Bazzite's locked OGC kernel version
          +
matching uBlue akmods and NVIDIA-open artifacts
          |
          v
      CI build + image assertions
          |
          v
signed testing digest --hardware test--> stable digest
                                            |
                                            +--> signed installer ISO
                                            +--> staged client updates
```

`stable` promotion copies the tested manifest by digest. It does not rebuild.

## Upstream boundaries

Axioma does not inherit Bazzite's final KDE or GNOME image. It uses Fedora's
official COSMIC Atomic image and reproduces an explicit allowlist of Bazzite's
kernel, gaming, tuning and desktop facilities.

Included from or aligned with Bazzite:

- OGC kernel and signed uBlue kmods
- NVIDIA-open module artifact and matching proprietary userspace
- xone/xpadneo
- Steam/Lutris/gamescope/UMU and multilib runtime
- dmemcg/uresourced, tuned profiles, sysctls, zram and I/O schedulers
- Greenboot, uupd, Homebrew, Waydroid, Cockpit, Tailscale and virtualization

Excluded:

- KDE/GNOME configuration and applications
- Steam Deck and gamescope-session mode
- announcements and Bazzite branding
- akmods-extra and specialty hardware helpers

## Session isolation

The launcher for `Axioma COSMIC on niri` exports `NIRI_CONFIG` before invoking
`cosmic-session niri`. Its configuration starts COSMIC components through
`cosmic-ext-alternative-startup` and does not start DMS.

The ordinary niri desktop file loads `config.kdl`, starts DMS and Vicinae, and
does not run the COSMIC session manager. This separation prevents the two shells
from competing for layer-shell surfaces, notifications, locking and shortcuts.

## Runtime service policy

Network-facing and heavyweight optional services are installed but disabled.
The public `ujust axioma-*` recipes are the only supported enable/disable
interface. Every optional recipe provides a read-only `status` action.

