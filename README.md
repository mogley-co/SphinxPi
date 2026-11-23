# SphinxPi

A lightweight, safety-first custom OS layer for the original Raspberry Pi Zero family.

**Target hardware:** Raspberry Pi Zero / Zero W / Zero WH (ARMv6, 512 MB RAM).

## Base image

SphinxPi v0.1.0 is based on the official DietPi Raspberry Pi 1 / Zero ARMv6 Debian 13 (Trixie) image.

- Image: [DietPi_RPi1-ARMv6-Trixie.img.xz](https://github.com/mogley-co/SphinxPi/releases/download/v0.1.0/DietPi_RPi1-ARMv6-Trixie.img.xz)
- Release asset SHA-256: `f95e0315df7d28d3514aaa03fd28759d5afd4666d7b3a358dd9269bdde93f79e`

## Desktop direction

SphinxPi uses a minimal LXDE desktop profile built around Openbox. LXPanel provides the top panel, PCManFM provides the file manager and desktop icons, and LXTerminal provides a terminal. The profile avoids XFCE and does not install a display manager or enable graphical autologin.

The original Pi Zero W has 512 MB RAM and a single-core ARMv6 CPU. Debian Trixie provides LXDE components for the original Pi's armel architecture. Performance will still be limited, especially with browsers or several applications open.

## Install the SphinxPi command

```sh
git clone https://github.com/mogley-co/SphinxPi.git
cd SphinxPi
sh scripts/install.sh  # if logged in as root on DietPi; otherwise use sudo sh scripts/install.sh
```

## Optional desktop

```sh
sphinx desktop-install  # as root; use sudo from a normal user account
```

This installs Xorg, Xinit, LXDE core and lightweight desktop utilities. It does not enable a display manager, automatic graphical login, change the default boot target, replace the kernel, or alter partitions.

Start LXDE from a normal non-root account:

```sh
sphinx desktop
```

Inside the graphical session, move the LXPanel to the top:

```sh
sphinx desktop-layout
```

## Archive Manager

Install the optional archive tools:

```sh
sphinx archive-install  # as root; use sudo from a normal user account
```

Open the interactive terminal menu:

```sh
sphinx archive
```

The menu supports ZIP, AES-256 encrypted ZIP, 7Z, TAR, TAR.GZ, TAR.XZ and TAR.BZ2 creation; extraction; content listing; and archive testing. When replacing an existing archive, SphinxPi builds a temporary file first and only replaces the old archive after successful creation. It lets you choose the output path and compression level, then reports the resulting file size. It uses whiptail menus when available and a numbered text menu as a fallback. Debian's 7zip package provides the `7z` command used by SphinxPi. Extraction is restricted to an empty destination folder to reduce the risk of overwriting existing files.

**Password note:** AES-256 is used for password-protected ZIP and 7Z archives through 7-Zip. Passwords are requested interactively rather than placed directly in the command line. TAR-based formats do not support built-in password encryption. Keep your password safe; encrypted archives cannot be recovered if it is lost.

## Network diagnostics

Run:

```sh
sphinx network-check
```

This checks the system clock, default route, DNS resolution for Debian, HTTPS connectivity over IPv4, and configured APT source entries. It is read-only and does not change Wi-Fi, DNS, IPv4/IPv6, or repository settings.

## Commands

- `sphinx help`
- `sphinx info`
- `sphinx version`
- `sphinx network-check`
- `sphinx desktop-install` (run as root; use `sudo` from a normal account)
- `sphinx desktop`
- `sphinx desktop-layout`
- `sphinx archive-install` (run as root; use `sudo` from a normal account)
- `sphinx archive`
- `sphinx uninstall` (run as root; removes SphinxPi files only)

## Uninstall

From the repository directory, run `sh scripts/uninstall.sh` as root, or
`sudo sh scripts/uninstall.sh` from a normal account. You can also run
`sphinx uninstall` after installation. The script asks for confirmation.
It removes the SphinxPi CLI, helper scripts and `/etc/sphinxpi` configuration.
It deliberately leaves LXDE, Xorg, archive utilities, personal files and all
boot/kernel/firmware/partition settings untouched.

## Safety

- Back up the SD card before system-level changes.
- Do not flash or repartition the card during normal SphinxPi upgrades.
- Desktop and archive tool installation are optional and require explicit confirmation.
- The existing text login remains available as a recovery path.
