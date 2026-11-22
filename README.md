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
sudo sh scripts/install.sh
```

## Install and start the optional desktop

```sh
sudo sphinx desktop-install
```

This installs Xorg, Xinit, LXDE core and lightweight desktop utilities. It does not enable a display manager, automatic graphical login, change the default boot target, replace the kernel, or alter partitions.

After installation, start LXDE from a normal non-root account:

```sh
sphinx desktop
```

Inside the graphical session, move the LXPanel to the top:

```sh
sphinx desktop-layout
```

## Current commands

- `sphinx help`
- `sphinx info`
- `sphinx version`
- `sudo sphinx desktop-install`
- `sphinx desktop`
- `sphinx desktop-layout`

## Safety

- Back up the SD card before system-level changes.
- Do not flash or repartition the card during normal SphinxPi upgrades.
- Desktop installation is optional and requires explicit confirmation.
- The existing text login remains available as a recovery path.
