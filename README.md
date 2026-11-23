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

## Install the SphinxPi Debian package

SphinxPi is distributed as a normal Debian `.deb` package. The package installs
its command in `/usr/bin/sphinx` and its private helper scripts in
`/usr/lib/sphinxpi`.

Build it from a checkout:

```sh
git clone https://github.com/mogley-co/SphinxPi.git
cd SphinxPi
sh scripts/build-deb.sh
sudo apt install ./dist/sphinxpi_0.1.2_all.deb
```

Or build and install in one step:

```sh
sh scripts/install.sh
```

To update directly on the Pi, run `sudo sphinx update` (or `sphinx update`
from a normal account). It downloads the latest `main` branch from the official
GitHub repository, builds the Debian package locally, and installs it with APT.
A working internet connection and `curl` or `wget` are required. You can also
build and install a newer `.deb` manually. A package upgrade replaces the old
Debian-managed files. The package's pre-install step also removes the
legacy `/usr/local/bin/sphinx` command so it cannot shadow the new
`/usr/bin/sphinx` command.

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

The manager supports both a direct root login and `sudo sphinx archive`.
When launched through sudo, it runs the interactive manager as the original
sudo user so files created by the manager are not unnecessarily owned by root.
When logged in directly as root, it runs as root.

The menu supports ZIP, AES-256 encrypted ZIP, 7Z, TAR, TAR.GZ, TAR.BZ2 creation; extraction; content listing; and archive testing. When replacing an existing archive, SphinxPi builds a temporary file first and only replaces the old archive after successful creation. It lets you choose the output path and compression level, then reports the resulting file size. It uses whiptail menus when available and a numbered text menu as a fallback. The installer installs and verifies all required tools (`whiptail`, `zip`, `unzip`, `7zip`, `tar`, `gzip` and `bzip2`), so the manager does not depend on these utilities already being present. Debian's 7zip package provides the `7z` command used by SphinxPi. Extraction is restricted to an empty destination folder to reduce the risk of overwriting existing files.

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
- `sphinx update` (downloads and installs the latest GitHub version)
- `sphinx network-check`
- `sphinx desktop-install` (run as root; use `sudo` from a normal account)
- `sphinx desktop`
- `sphinx desktop-layout`
- `sphinx archive-install` (run as root; use `sudo` from a normal account)
- `sphinx archive`
- `sphinx uninstall` (uses Debian's package manager)

## Uninstall

Run:

```sh
sphinx uninstall
```

This invokes `apt-get remove sphinxpi` (using sudo when needed). You can also
run `sudo apt remove sphinxpi` directly.
Optional LXDE and archive packages are intentionally not removed because they
may be used by other software. No personal files, boot files, kernel, firmware
or partitions are changed.

## Safety

- Back up the SD card before system-level changes.
- Do not flash or repartition the card during normal SphinxPi upgrades.
- Desktop and archive tool installation are optional and require explicit confirmation.
- The existing text login remains available as a recovery path.


### Management UI and full removal

- `sphinx ui` opens the whiptail management menu.
- `sphinx update` asks for confirmation before installing the latest GitHub version.
- `sphinx uninstall` removes only the SphinxPi package.
- `sphinx uninstall -f` purges SphinxPi, removes optional packages recorded as newly installed by SphinxPi, and deletes its system state/configuration.

Full removal keeps the home directory, personal files, and a cloned `~/SphinxPi` source repository. It does not run global `apt autoremove`. Package tracking applies to optional desktop/archive installs made after this version; older installs have no reliable manifest and are left untouched.
