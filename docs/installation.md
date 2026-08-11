# Installation and migration

## Before booting the ISO

Back up irreplaceable data. Record the target by model and capacity rather than
assuming Linux disk letters remain stable.

The intended first test layout is:

| Device | Size | Role | Action |
|---|---:|---|---|
| `/dev/sda` | 447.1 GiB | CachyOS | Preserve |
| `/dev/sdc` | 223.6 GiB | Old Bluefin | Erase for Axioma test |
| `/dev/sdb` | 3.6 TiB | Mega Storage | Preserve |
| `/dev/sdd` | 931.5 GiB | Storage | Preserve |

Disconnecting the two data disks during installation is an additional safety
option. They can be reconnected before running the mount recipe.

## Anaconda choices

1. Confirm the installer was booted in UEFI mode.
2. Select only the 223.6 GiB WD Green SSD.
3. Reclaim the old Bluefin partitions on that disk.
4. Use automatic Btrfs partitioning with LUKS2 encryption.
5. Choose a strong disk passphrase.
6. Create user `esteraxiom` and grant administrator access.
7. Choose the hostname in the installer.
8. Keep Secure Boot disabled for this first test.

## Data disks

After the first installed boot, run:

```bash
ujust axioma-mount-data
```

The command checks both UUID and label before touching `/etc/fstab`. It creates:

```text
/mnt/MegaStorage
/mnt/Storage
```

The filesystem roots are owned by UID/GID 1000, so the new `esteraxiom` account
retains access despite the username change.

## Selective home migration

The default migration copies personal directories and the standalone niri,
DMS, Quickshell and Vicinae configurations. It mounts the old Btrfs `@home`
subvolume read-only.

```bash
ujust axioma-migrate-home
```

To additionally copy Bottles, PCSX2, Heroic and RetroArch data:

```bash
ujust axioma-migrate-home --gaming-data
```

Existing destination configurations are backed up below
`~/.local/state/axioma-migration/`. COSMIC settings, browser profiles, SSH keys,
GPG keys and caches are deliberately not copied.

## Acceptance gate

Complete [`tests/hardware-smoke-test.md`](../tests/hardware-smoke-test.md)
before deciding whether to replace CachyOS on the 447.1 GiB SSD.

