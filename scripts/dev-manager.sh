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
    parent=$(dirname "$target")
    if ! mkdir -p "$parent"; then
        message "Could not create the parent directory:\n$parent"
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

node_install() {
    if ! has_candidate nodejs; then
        message "No Node.js package candidate is available for this system's configured architecture and repositories. The original Pi Zero uses ARMv6, so upstream Node.js binaries are not assumed to be compatible."
        return 1
    fi
    if has_candidate npm; then
        install_packages "Node.js runtime" nodejs npm
    else
        install_packages "Node.js runtime" nodejs
    fi
}

node_project_package() {
    if ! command -v npm >/dev/null 2>&1; then
        message "npm is not installed. Install Node.js and npm first."
        return
    fi
    project=$(whiptail --title "Install Node.js Package" --inputbox "Enter the project directory (it must already exist):" 9 70 "$PWD" 3>&1 1>&2 2>&3) || return 0
    package=$(whiptail --title "Install Node.js Package" --inputbox "Enter the npm package name:" 9 70 "" 3>&1 1>&2 2>&3) || return 0
    [ -n "$project" ] && [ -n "$package" ] || return 0
    case "$package" in
        *[!A-Za-z0-9._@/-]*)
            message "Invalid package name."
            return
            ;;
    esac
    if [ ! -d "$project" ]; then
        message "Project directory does not exist:\n$project"
        return
    fi
    if npm install --prefix "$project" -- "$package"; then
        message "Installed $package in:\n$project"
    else
        message "npm package installation failed. Check the project path, package name and network."
    fi
}
node_menu() {
    while :; do
        choice=$(whiptail --title "Node.js Manager" --menu "Node.js is installed from Debian's configured repositories. SphinxPi checks package availability for your CPU architecture before installing." 17 74 6 \
            install "Install / repair Node.js and npm" \
            update "Update installed Node.js and npm through APT" \
            status "Show Node.js, npm and global packages" \
            package "Install a package in a project" \
            back "Back" 3>&1 1>&2 2>&3) || return 0
        case "$choice" in
            install) node_install ;;
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
            package) node_project_package ;;
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
    report_file=$(mktemp "\${TMPDIR:-/tmp}/sphinx-doctor.XXXXXX") || {
        message "Could not create a temporary diagnostics report."
        return 1
    }
    {
        echo "SPHINXPI SYSTEM DOCTOR"
        echo "Generated: $(date 2>/dev/null || echo unavailable)"
        echo
        echo "== SYSTEM =="
        echo "Hostname: $(hostname 2>/dev/null || echo unavailable)"
        echo "OS: $(. /etc/os-release 2>/dev/null; printf '%s %s' "\${PRETTY_NAME:-unknown}" "\${VERSION_CODENAME:-}")"
        echo "Architecture: $(uname -m 2>/dev/null) / $(dpkg --print-architecture 2>/dev/null || echo unknown)"
        echo "Kernel: $(uname -r 2>/dev/null)"
        echo "Uptime: $(uptime -p 2>/dev/null || uptime 2>/dev/null || echo unavailable)"
        echo "Load average: $(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || echo unavailable)"
        echo
        echo "== RASPBERRY PI / CPU =="
        cpu_model=$(awk -F': *' '/^(Model|model name|Hardware|Processor)[[:space:]]*:/ {print $2; exit}' /proc/cpuinfo 2>/dev/null)
        echo "CPU: \${cpu_model:-not reported by kernel}"
        echo "CPU cores: $(getconf _NPROCESSORS_ONLN 2>/dev/null || echo unknown)"
        if [ -r /sys/class/thermal/thermal_zone0/temp ]; then
            temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "")
            case "$temp_raw" in
                ''|*[!0-9]*) echo "CPU temperature: unavailable" ;;
                *) echo "CPU temperature: $(awk -v t="$temp_raw" 'BEGIN {printf "%.1f C", t/1000}')" ;;
            esac
        else
            echo "CPU temperature: sensor unavailable"
        fi
        if [ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
            freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "")
            case "$freq" in
                ''|*[!0-9]*) echo "CPU frequency: unavailable" ;;
                *) echo "CPU frequency: $(awk -v f="$freq" 'BEGIN {printf "%.0f MHz", f/1000}')" ;;
            esac
        else
            echo "CPU frequency: not exposed by kernel"
        fi
        if command -v vcgencmd >/dev/null 2>&1; then
            echo "Firmware throttling flags: $(vcgencmd get_throttled 2>&1 | sed 's/^throttled=//')"
        else
            echo "Firmware throttling flags: vcgencmd unavailable"
        fi
        echo
        echo "== MEMORY =="
        awk '
            /^MemTotal:/ {total=$2}
            /^MemAvailable:/ {available=$2}
            /^SwapTotal:/ {swap_total=$2}
            /^SwapFree:/ {swap_free=$2}
            END {
                if (total) printf "RAM: %d MB total, %d MB available\n", total/1024, available/1024
                else print "RAM: unavailable"
                if (swap_total) printf "Swap: %d MB total, %d MB free\n", swap_total/1024, swap_free/1024
                else print "Swap: not configured"
            }
        ' /proc/meminfo 2>/dev/null
        echo
        echo "== STORAGE =="
        df -h -x tmpfs -x devtmpfs 2>/dev/null | sed -n '1,12p'
        echo
        if command -v lsblk >/dev/null 2>&1; then
            echo "Block devices:"
            lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null | sed -n '1,12p'
        else
            echo "Block devices: lsblk unavailable"
        fi
        echo
        echo "== NETWORK =="
        if command -v ip >/dev/null 2>&1; then
            echo "Interfaces:"
            ip -brief address 2>/dev/null | sed -n '1,8p'
            echo "Default route:"
            ip route 2>/dev/null | awk '/^default/ {print; found=1} END {if (!found) print "No default route"}'
        else
            echo "Network interfaces: ip command unavailable"
        fi
        if command -v getent >/dev/null 2>&1; then
            if command -v timeout >/dev/null 2>&1; then
                if timeout 5 getent hosts deb.debian.org >/dev/null 2>&1; then
                    echo "DNS lookup (deb.debian.org): OK"
                else
                    echo "DNS lookup (deb.debian.org): FAILED or timed out"
                fi
            elif getent hosts deb.debian.org >/dev/null 2>&1; then
                echo "DNS lookup (deb.debian.org): OK"
            else
                echo "DNS lookup (deb.debian.org): FAILED"
            fi
        else
            echo "DNS lookup: getent unavailable"
        fi
        echo
        echo "== APT / PACKAGE HEALTH =="
        if command -v dpkg >/dev/null 2>&1; then
            audit=$(dpkg --audit 2>&1)
            if [ -n "$audit" ]; then
                echo "dpkg audit: ATTENTION"
                printf '%s\n' "$audit" | sed -n '1,10p'
            else
                echo "dpkg audit: clean"
            fi
            echo "Packages awaiting configuration: $(dpkg -l 2>/dev/null | awk '$1=="iU" || $1=="iF" || $1=="iH" {n++} END {print n+0}')"
        else
            echo "dpkg: unavailable"
        fi
        echo "APT list files: $(find /var/lib/apt/lists -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
        echo
        echo "== DEVELOPMENT RUNTIMES =="
        for tool in python3 pip3 pipx node npm git gcc g++ make cmake nano ssh whiptail; do
            if command -v "$tool" >/dev/null 2>&1; then
                case "$tool" in
                    python3|node|npm|git|gcc|cmake)
                        version=$("$tool" --version 2>&1 | sed -n '1p')
                        echo "$tool: $version"
                        ;;
                    *) echo "$tool: available ($(command -v "$tool"))" ;;
                esac
            else
                echo "$tool: not installed"
            fi
        done
        echo
        echo "== SPHINXPI =="
        if [ -r /usr/share/sphinxpi/version ]; then
            echo "Installed version: $(cat /usr/share/sphinxpi/version)"
        else
            echo "Installed version: not found"
        fi
        for helper in dev-manager.sh system-manager.sh archive-manager.sh update.sh track-install.sh remove.sh; do
            if [ -r "/usr/lib/sphinxpi/$helper" ]; then
                echo "$helper: readable"
            else
                echo "$helper: MISSING"
            fi
        done
        if [ -r /usr/share/sphinxpi/apps.tsv ]; then
            echo "App catalogue: $(awk '!/^#/ && NF {n++} END {print n+0}' /usr/share/sphinxpi/apps.tsv) entries"
        else
            echo "App catalogue: MISSING"
        fi
        if command -v sphinx >/dev/null 2>&1; then
            echo "sphinx command: $(command -v sphinx)"
        else
            echo "sphinx command: not found in PATH"
        fi
        echo
        echo "== NOTES =="
        echo "- Sensor and firmware readings depend on kernel/firmware support."
        echo "- Missing optional commands are informational, not automatically errors."
        echo "- This report reads system state; it does not change settings or repair packages."
    } > "$report_file"
    if whiptail --title "SphinxPi System Doctor" --textbox "$report_file" 24 78; then
        result=0
    else
        result=$?
    fi
    rm -f "$report_file"
    return "$result"
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
