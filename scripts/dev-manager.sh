#!/bin/sh
set -eu

MODE="${1:-menu}"
TRACKER="/usr/lib/sphinxpi/track-install.sh"

message() {
    whiptail --title "SphinxPi Development Manager" --msgbox "$1" 12 70
}

ask_yes() {
    whiptail --title "SphinxPi Development Manager" --yesno "$1" 10 70
}

root_command() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        message "Administrative access is required. Log in as root or install/configure sudo."
        return 1
    fi
}

has_candidate() {
    candidate=$(apt-cache policy "$1" 2>/dev/null | awk '$1 == "Candidate:" {print $2}')
    [ -n "$candidate" ] && [ "$candidate" != "(none)" ]
}

install_packages() {
    label=$1
    shift
    available=""
    missing=""
    for package in "$@"; do
        if has_candidate "$package"; then
            available="$available $package"
        else
            missing="$missing $package"
        fi
    done

    if [ -z "$available" ]; then
        message "No compatible $label packages were found in the configured APT repositories.\n\nUnavailable:$missing"
        return 1
    fi

    if [ -n "$missing" ]; then
        whiptail --title "SphinxPi Compatibility Check" --yesno "Some packages are unavailable:$missing\n\nInstall the available packages:$available ?" 12 70 || return 0
    else
        ask_yes "Install or repair $label packages:$available ?" || return 0
    fi

    if ! root_command apt-get update; then
        message "APT index refresh failed. Check your network with: sphinx network-check"
        return 1
    fi

    if [ -r "$TRACKER" ]; then
        # Track only packages that this operation will newly install.
        root_command sh "$TRACKER" $available
    fi

    if root_command apt-get install -y --no-install-recommends $available; then
        message "$label installation completed."
    else
        message "$label installation failed. Review the APT error output."
        return 1
    fi
}

python_status() {
    report=""
    if command -v python3 >/dev/null 2>&1; then
        report="Python: $(python3 --version 2>&1)"
        report="$report\nExecutable: $(command -v python3)"
    else
        report="Python 3: not installed"
    fi
    if command -v pip3 >/dev/null 2>&1; then
        report="$report\npip: $(pip3 --version 2>&1)"
    else
        report="$report\npip: not installed"
    fi
    if command -v pipx >/dev/null 2>&1; then
        report="$report\npipx: $(pipx --version 2>&1)"
    else
        report="$report\npipx: not installed"
    fi
    message "$report"
}

create_venv() {
    if ! command -v python3 >/dev/null 2>&1; then
        message "Python 3 is not installed. Install it first."
        return
    fi
    target=$(whiptail --title "Create Python Environment" --inputbox "Enter the environment directory. Example: $HOME/projects/myapp/.venv" 10 72 "$HOME/.venvs/project" 3>&1 1>&2 2>&3) || return 0
    [ -n "$target" ] || return 0
    case "$target" in
        /*) ;;
        *) target="$PWD/$target" ;;
    esac
    if [ -e "$target" ]; then
        message "That path already exists. Choose a new, empty directory."
        return
    fi
    if python3 -m venv "$target"; then
        message "Virtual environment created:\n$target\n\nActivate it with:\n. \"$target/bin/activate\""
    else
        message "Could not create the environment. Install or repair python3-venv and try again."
    fi
}

install_python_package() {
    venv=$(whiptail --title "Install Python Package" --inputbox "Enter the existing virtual environment directory:" 9 70 "$HOME/.venvs/project" 3>&1 1>&2 2>&3) || return 0
    package=$(whiptail --title "Install Python Package" --inputbox "Enter the PyPI package name:" 9 70 "" 3>&1 1>&2 2>&3) || return 0
    [ -n "$venv" ] && [ -n "$package" ] || return 0
    case "$package" in
        *[!A-Za-z0-9._-]*)
            message "Invalid package name. Use letters, numbers, dots, underscores or hyphens."
            return
            ;;
    esac
    if [ ! -x "$venv/bin/python" ]; then
        message "No Python virtual environment was found at:\n$venv"
        return
    fi
    if "$venv/bin/python" -m pip install -- "$package"; then
        message "Installed $package into:\n$venv"
    else
        message "Package installation failed. Check the network and package name."
    fi
}

python_menu() {
    while :; do
        choice=$(whiptail --title "Python Manager" --menu "Manage Python without modifying Debian's system Python packages through pip." 17 72 6 \
            install "Install / repair Python 3, venv, pip and pipx" \
            update "Update installed Python tools through APT" \
            status "Show Python and pip versions" \
            venv "Create a virtual environment" \
            package "Install a package inside a virtual environment" \
            back "Back" 3>&1 1>&2 2>&3) || return 0
        case "$choice" in
            install) install_packages "Python tooling" python3 python3-venv python3-pip pipx ;;
            update)
                packages=""
                for p in python3 python3-venv python3-pip pipx; do
                    if dpkg-query -W -f='${db:Status-Status}' "$p" 2>/dev/null | grep -qx installed; then packages="$packages $p"; fi
                done
                if [ -n "$packages" ]; then
                    root_command apt-get update && root_command apt-get install -y --only-upgrade $packages
                    message "Python package update check finished."
                else
                    message "No managed Python packages are currently installed."
                fi
                ;;
            status) python_status ;;
            venv) create_venv ;;
            package) install_python_package ;;
            back) return 0 ;;
        esac
    done
}

node_status() {
    report=""
    if command -v node >/dev/null 2>&1; then report="Node.js: $(node --version)\nExecutable: $(command -v node)"; else report="Node.js: not installed"; fi
    if command -v npm >/dev/null 2>&1; then report="$report\nnpm: $(npm --version)"; else report="$report\nnpm: not installed"; fi
    if command -v npm >/dev/null 2>&1; then report="$report\n\nGlobal packages:\n$(npm list --global --depth=0 2>&1 | sed -n '1,12p')"; fi
    message "$report"
}

node_menu() {
    while :; do
        choice=$(whiptail --title "Node.js Manager" --menu "Node.js is installed from Debian's configured repositories. SphinxPi checks package availability for your CPU architecture before installing." 16 74 5 \
            install "Install / repair Node.js and npm" \
            update "Update installed Node.js and npm through APT" \
            status "Show Node.js, npm and global packages" \
            back "Back" 3>&1 1>&2 2>&3) || return 0
        case "$choice" in
            install) install_packages "Node.js runtime" nodejs npm ;;
            update)
                packages=""
                for p in nodejs npm; do
                    if dpkg-query -W -f='${db:Status-Status}' "$p" 2>/dev/null | grep -qx installed; then packages="$packages $p"; fi
                done
                if [ -n "$packages" ]; then
                    root_command apt-get update && root_command apt-get install -y --only-upgrade $packages
                    message "Node.js update check finished."
                else
                    message "Node.js and npm are not currently installed."
                fi
                ;;
            status) node_status ;;
            back) return 0 ;;
        esac
    done
}

tools_menu() {
    while :; do
        choice=$(whiptail --title "Developer Tools" --menu "Install lightweight command-line development tools." 16 72 5 \
            install "Install / repair Git, compiler and utilities" \
            update "Update installed developer tools through APT" \
            status "Show installed developer tools" \
            back "Back" 3>&1 1>&2 2>&3) || return 0
        case "$choice" in
            install) install_packages "developer tools" git build-essential make cmake nano openssh-client ;;
            update)
                packages=""
                for p in git build-essential make cmake nano openssh-client; do
                    if dpkg-query -W -f='${db:Status-Status}' "$p" 2>/dev/null | grep -qx installed; then packages="$packages $p"; fi
                done
                if [ -n "$packages" ]; then
                    root_command apt-get update && root_command apt-get install -y --only-upgrade $packages
                    message "Developer tools update check finished."
                else
                    message "No developer tools from this list are installed."
                fi
                ;;
            status)
                report=""
                for c in git gcc make cmake nano ssh; do
                    if command -v "$c" >/dev/null 2>&1; then report="$report$c: $(command -v "$c")\n"; else report="$report$c: not installed\n"; fi
                done
                message "$report"
                ;;
            back) return 0 ;;
        esac
    done
}

doctor() {
    report="SphinxPi System Doctor\n\nArchitecture: $(uname -m) / $(dpkg --print-architecture 2>/dev/null || echo unknown)\nKernel: $(uname -r)\n\n"
    report="$report$(awk '/MemTotal|MemAvailable/ {print $1, int($2/1024) " MB"}' /proc/meminfo 2>/dev/null)\n\n"
    report="$report$(df -h / | sed -n '1,2p')\n\n"
    for c in python3 pip3 pipx node npm git gcc make cmake whiptail; do
        if command -v "$c" >/dev/null 2>&1; then report="$report$c: available\n"; else report="$report$c: missing\n"; fi
    done
    message "$report"
}

if ! command -v whiptail >/dev/null 2>&1; then
    echo "The Development Manager requires whiptail. Install it with: sudo apt install whiptail" >&2
    exit 1
fi

case "$MODE" in
    python) python_menu ;;
    node) node_menu ;;
    tools) tools_menu ;;
    doctor) doctor ;;
    menu)
        while :; do
            choice=$(whiptail --title "SphinxPi Development Manager" --menu "Lightweight development tools for Raspberry Pi Zero." 18 72 6 \
                python "Python Manager" \
                node "Node.js Manager" \
                tools "Developer Tools" \
                doctor "System Doctor" \
                back "Back to SphinxPi" 3>&1 1>&2 2>&3) || exit 0
            case "$choice" in
                python) python_menu ;;
                node) node_menu ;;
                tools) tools_menu ;;
                doctor) doctor ;;
                back) exit 0 ;;
            esac
        done
        ;;
    *) echo "Unknown Development Manager mode: $MODE" >&2; exit 2 ;;
esac
