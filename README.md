# SphinxPi

A lightweight, safety-first custom OS layer for the original Raspberry Pi Zero family.

**Target hardware:** Raspberry Pi Zero / Zero W / Zero WH (ARMv6, 512 MB RAM).

## Base image

SphinxPi v0.1.0 is based on the official DietPi Raspberry Pi 1 / Zero ARMv6 Debian 13 (Trixie) image.

- Image: [DietPi_RPi1-ARMv6-Trixie.img.xz](https://github.com/mogley-co/SphinxPi/releases/download/v0.1.0/DietPi_RPi1-ARMv6-Trixie.img.xz)
- Release asset SHA-256: `f95e0315df7d28d3514aaa03fd28759d5afd4666d7b3a358dd9269bdde93f79e`

The release asset digest above is the checksum reported by GitHub for the uploaded file. Verify it after downloading.

## Project approach

SphinxPi is initially a customization layer, not a new kernel or bootloader. It preserves DietPi's kernel, firmware, boot configuration, and partition layout.

Development stages:

1. Add a small SphinxPi command-line interface.
2. Detect hardware and OS safely.
3. Add an optional lightweight desktop after checking ARMv6 package availability and memory use.
4. Add system management commands only after each operation has a tested rollback path.

## Install the current CLI

On the Pi, clone this repository, then run:

```sh
sudo sh scripts/install.sh
```

The installer only places the SphinxPi CLI and its configuration. It does not install packages or alter boot, kernel, firmware, or partitions.

Then run:

```sh
sphinx help
sphinx info
```

## Safety

- Back up the SD card before system-level changes.
- Do not flash or repartition the card during normal SphinxPi upgrades.
- Commands that modify packages or system configuration will require explicit confirmation.
- The original Pi Zero W has only 512 MB RAM; desktop choices must be lightweight.
