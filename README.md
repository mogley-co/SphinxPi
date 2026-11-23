# SphinxPi

A lightweight, safety-first command-line system toolkit for Debian-based systems.

**Supported operating systems:** Debian 13 (Trixie) and newer, plus Debian-based Raspberry Pi OS releases based on Debian 13 or newer.

**Architecture support:** the SphinxPi package is architecture-independent. Individual applications and optional tools are checked against the configured APT repositories, so availability depends on CPU architecture (armel, armhf, arm64, amd64, etc.), Debian release and enabled repositories.

SphinxPi is not a Linux distribution and does not replace the host operating system, kernel, bootloader or package manager. It installs optional system-management tools on an existing supported Debian installation. It does not require DietPi.

## Supported platform requirements

- Debian 13 (Trixie) or newer.
- Debian-based Raspberry Pi OS releases based on Debian 13 or newer.
- A working apt / dpkg environment.
- Root access for installation and system-changing actions.
- CPU architecture is not hard-coded. APT candidates are checked before optional packages are installed.

Older Debian releases, Ubuntu, Alpine, Arch Linux and non-Debian package systems are not currently supported by the installer.

## Optional desktop profile

SphinxPi can optionally install a lightweight LXDE desktop profile built around Openbox. LXPanel provides the panel, PCManFM provides the file manager and desktop icons, and LXTerminal provides a terminal. It does not install a display manager, enable graphical autologin or change the default boot target.

This is an optional profile, not a requirement. Desktop performance and package availability depend on the hardware and architecture. On the original Raspberry Pi Zero (ARMv6, 512 MB RAM), graphical performance is limited; SphinxPi's core terminal tools are the recommended experience.

## Install the SphinxPi Debian package

SphinxPi is distributed as a normal Debian `.deb` package. The package installs
its command in `/usr/bin/sphinx` and its private helper scripts in
`/usr/lib/sphinxpi`.

Build it from a checkout:

```sh
git clone https://github.com/mogley-co/SphinxPi.git
cd SphinxPi
sh scripts/build-deb.sh
sudo apt install ./dist/sphinxpi_0.3.0_all.deb
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

Available Archive Manager dependencies are installed automatically by `sphinx update`.
You can also install or repair them separately:

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

The menu supports ZIP, AES-256 encrypted ZIP, 7Z, TAR, TAR.GZ, TAR.BZ2, TAR.ZST and TAR.LZ4 creation; extraction; content listing; and archive testing. RAR archives can be extracted, listed and tested when the optional Debian `7zip-rar` plugin is available from the configured APT repositories. RAR creation is not supported by 7-Zip. When replacing an existing archive, SphinxPi builds a temporary file first and only replaces the old archive after successful creation. It lets you choose the output path and compression level, then reports the resulting file size. It uses whiptail menus when available and a numbered text menu as a fallback. The installer and updater check package availability for the current architecture before installing core tools; optional compression tools are skipped when unavailable. Debian's 7zip package provides the `7z` command used by SphinxPi. The optional `7zip-rar` plugin is installed automatically only when it is available in the configured repositories. Extraction is restricted to an empty destination folder to reduce the risk of overwriting existing files.

**Password note:** AES-256 is used for password-protected ZIP and 7Z archives through 7-Zip. Passwords are requested interactively rather than placed directly in the command line. TAR-based formats do not support built-in password encryption. Keep your password safe; encrypted archives cannot be recovered if it is lost.

## Development Manager

Open the interactive Development Manager from the main Control Center:

```sh
sphinx dev
# or open the full SphinxPi menu:
sphinx ui
```

The manager uses the same lightweight Whiptail terminal interface as the
Archive Manager. It includes:

- **Python Manager:** install or repair Debian's Python 3, venv, pip and pipx
  packages; inspect versions; create virtual environments; and install PyPI
  packages inside an existing virtual environment.
- **Node.js Manager:** install or repair Node.js and npm from the configured
  Debian repositories; inspect versions and globally installed npm packages.
- **Developer Tools:** install or update Git, build-essential, Make, CMake,
  Nano and the OpenSSH client.
- **System Doctor:** inspect OS and kernel versions, CPU model/cores, temperature and frequency when exposed, Raspberry Pi firmware throttling flags when `vcgencmd` exists, RAM and swap, mounted storage and block devices, network interfaces/default route/DNS, APT and dpkg health, development runtime versions, and SphinxPi installation files. The report is read-only and scrollable.

You can open individual sections directly with `sphinx python`,
`sphinx node`, `sphinx tools` and `sphinx doctor`.

Python packages are installed inside virtual environments rather than into
Debian's externally managed system Python. Create an environment from the
Python Manager, then install packages into that environment. The Node.js
manager uses Debian's APT packages rather than assuming that upstream Node.js
binaries support ARMv6. It can also install npm packages locally into an existing
project directory, avoiding unnecessary global package installation. Every APT installation checks whether a package
candidate exists for the configured architecture and records newly installed
packages for SphinxPi's full-removal process. The manager does not silently
install a full compiler or runtime during a normal SphinxPi update.

**Architecture note:** runtime and package availability depends on the architecture and enabled repositories. SphinxPi checks APT candidates before installation; it cannot make an incompatible upstream binary run on an unsupported CPU architecture.

## System Manager and Install Apps

Open the System Manager from the Control Center or directly:

```sh
sphinx system
# Or open an individual tool:
sphinx monitor
sphinx backup
sphinx network
sphinx services
sphinx logs
sphinx apps
```

The System Manager includes:

- **Resource Monitor:** a lightweight system snapshot showing CPU load, temperature when exposed, RAM, swap, disk usage, top processes and network interfaces. If `btop` is installed, it opens the live monitor instead.
- **Backup Manager:** create TAR.GZ backups of a selected folder and restore into a new or empty directory. Existing backup files are never overwritten. Restore checks reject absolute and parent-directory paths.
- **Network Manager:** inspect interfaces, addresses, routes, DNS, internet reachability and SSH service state. It is diagnostic-only and does not alter network configuration.
- **Service Manager:** list services, inspect status, and start, stop, restart, enable or disable a selected systemd service after confirmation.
- **Log Viewer:** inspect recent system journal entries, boot warnings/errors or logs for a selected service.
- **Install Apps:** search a catalogue of 159 Debian package entries by package name, category or description. Installed packages are marked `[INSTALLED]` and preselected in the checklist. Select packages with SPACE and press ENTER to install. SphinxPi refreshes APT indexes, checks each selected package for an available candidate on the current architecture, skips unavailable packages and tracks newly installed packages for full removal.

The app catalogue includes development tools (Git, compilers, Python, Node.js, PHP and more), editors, terminal tools, network utilities, monitoring, archives, databases, IoT utilities, media tools and optional desktop applications. The catalogue is a list of Debian package names, not a guarantee that every package exists for every architecture or repository configuration. Packages without an APT candidate are skipped; large packages and services should be selected deliberately. SphinxPi does not automatically install the catalogue during an update.

**Architecture / resource note:** catalogue packages are not guaranteed to exist for every CPU architecture or repository configuration. Some packages may also be resource-intensive on small devices. Check package suitability before installing databases, compilers, desktop applications or server services. The Resource Monitor uses a snapshot by default to avoid a permanent background process.

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
- `sphinx update` (downloads and installs the latest GitHub version and available Archive Manager dependencies)
- `sphinx network-check`
- `sphinx desktop-install` (run as root; use `sudo` from a normal account)
- `sphinx desktop`
- `sphinx desktop-layout`
- `sphinx archive-install` (install or repair Archive Manager dependencies; run as root or use `sudo`)
- `sphinx archive`
- `sphinx dev` (open the Development Manager)
- `sphinx python`, `sphinx node`, `sphinx tools`, `sphinx doctor`
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
- `sphinx update` asks for confirmation before installing the latest GitHub version and Archive Manager dependencies.
- `sphinx uninstall` removes only the SphinxPi package.
- `sphinx uninstall -f` purges SphinxPi, removes optional packages recorded as newly installed by SphinxPi, and deletes its system state/configuration.

Full removal keeps the home directory, personal files, and a cloned `~/SphinxPi` source repository. It does not run global `apt autoremove`. Archive dependencies installed by `sphinx update` or `sphinx archive-install` are recorded in the package manifest and removed by full removal only if SphinxPi installed them. Packages that were already present are preserved. Older installs without a reliable manifest are left untouched.
