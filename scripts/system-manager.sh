#!/bin/sh
set -eu

MODE="${1:-menu}"
TRACKER="/usr/lib/sphinxpi/track-install.sh"
CATALOG="/usr/share/sphinxpi/apps.tsv"

message() { whiptail --title "SphinxPi" --msgbox "$1" 12 72; }
ask_yes() { whiptail --title "SphinxPi Confirmation" --yesno "$1" 10 72; }

root_command() {
    if [ "$(id -u)" -eq 0 ]; then "$@"
    elif command -v sudo >/dev/null 2>&1; then sudo "$@"
    else message "This action needs administrator access. Log in as root or configure sudo."; return 1
    fi
}

installed_package() {
    dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null | grep -qx installed
}

show_file() {
    file=$1
    title=$2
    if [ -s "$file" ]; then whiptail --title "$title" --textbox "$file" 24 80; else message "No information is available."; fi
}

resource_monitor() {
    if command -v btop >/dev/null 2>&1; then
        btop
        return
    fi
    report=$(mktemp "${TMPDIR:-/tmp}/sphinx-monitor.XXXXXX") || { message "Could not create report."; return 1; }
    {
        echo "SPHINXPI RESOURCE MONITOR — SNAPSHOT"
        echo "Generated: $(date)"
        echo "Refresh by closing this report and opening Resource Monitor again."
        echo
        echo "== CPU / LOAD =="
        echo "Model: $(awk -F': *' '/^(model name|Hardware|Processor)[[:space:]]*:/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || echo unavailable)"
        echo "Load average: $(cat /proc/loadavg 2>/dev/null || echo unavailable)"
        echo "CPU cores: $(getconf _NPROCESSORS_ONLN 2>/dev/null || echo unknown)"
        if [ -r /sys/class/thermal/thermal_zone0/temp ]; then
            raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "")
            case "$raw" in ''|*[!0-9]*) echo "Temperature: unavailable" ;; *) awk -v t="$raw" 'BEGIN {printf "Temperature: %.1f C\n",t/1000}' ;; esac
        else echo "Temperature: sensor unavailable"; fi
        echo
        echo "== MEMORY / SWAP =="
        awk '/^(MemTotal|MemAvailable|MemFree|Buffers|Cached|SwapTotal|SwapFree):/ {printf "%-14s %7.1f MB\n",$1,$2/1024}' /proc/meminfo 2>/dev/null
        echo
        echo "== STORAGE =="
        df -h -x tmpfs -x devtmpfs 2>/dev/null
        echo
        echo "== TOP PROCESSES (CPU) =="
        ps -eo pid,comm,%cpu,%mem --sort=-%cpu 2>/dev/null | sed -n '1,13p' || echo "ps unavailable"
        echo
        echo "== NETWORK =="
        if command -v ip >/dev/null 2>&1; then ip -brief address 2>/dev/null; else echo "ip command unavailable"; fi
        echo
        echo "Optional live monitor: install btop from Install Apps if an APT candidate exists."
    } > "$report"
    show_file "$report" "SphinxPi Resource Monitor"
    rm -f "$report"
}

backup_manager() {
    while :; do
        action=$(whiptail --title "Backup Manager" --menu "Create or restore a compressed backup. Restores only target an empty directory." 16 72 4 \
            create "Create a TAR.GZ backup" \
            restore "Restore a TAR.GZ backup" \
            back "Back" 3>&1 1>&2 2>&3) || return 0
        case "$action" in
            create)
                source=$(whiptail --title "Create Backup" --inputbox "Folder to back up:" 9 72 "$HOME" 3>&1 1>&2 2>&3) || continue
                dest=$(whiptail --title "Create Backup" --inputbox "New backup file path:" 9 72 "$HOME/sphinx-backup-$(date +%Y%m%d-%H%M%S).tar.gz" 3>&1 1>&2 2>&3) || continue
                [ -n "$source" ] && [ -n "$dest" ] || continue
                case "$source" in /*) ;; *) source="$PWD/$source" ;; esac
                case "$dest" in /*) ;; *) dest="$PWD/$dest" ;; esac
                [ -d "$source" ] || { message "Source folder does not exist."; continue; }
                [ ! -e "$dest" ] || { message "Backup file already exists. Choose a new filename; existing backups are never overwritten."; continue; }
                source_real=$(realpath -e -- "$source") || { message "Cannot resolve source folder."; continue; }
                dest_parent=$(dirname -- "$dest")
                [ -d "$dest_parent" ] || { message "Backup destination folder does not exist."; continue; }
                dest_parent_real=$(realpath -e -- "$dest_parent") || { message "Cannot resolve destination folder."; continue; }
                dest="$dest_parent_real/$(basename -- "$dest")"
                case "$dest" in "$source_real"/*) message "Put the backup outside the source folder to avoid including the backup in itself."; continue ;; esac
                ask_yes "Create a compressed backup?\n\nSource: $source_real\nDestination: $dest\n\nMounted filesystems below the source are excluded." || continue
                if tar --one-file-system -czf "$dest" -C "$(dirname -- "$source_real")" -- "$(basename -- "$source_real")"; then
                    message "Backup created:\n$dest\n\nSize: $(du -h "$dest" | awk '{print $1}')"
                else
                    rm -f -- "$dest"
                    message "Backup failed. The incomplete output was removed."
                fi
                ;;
            restore)
                archive=$(whiptail --title "Restore Backup" --inputbox "Path to your .tar.gz backup:" 9 72 "" 3>&1 1>&2 2>&3) || continue
                target=$(whiptail --title "Restore Backup" --inputbox "Restore into a NEW empty directory:" 9 72 "$HOME/Restored-Backup" 3>&1 1>&2 2>&3) || continue
                [ -n "$archive" ] && [ -n "$target" ] || continue
                [ -f "$archive" ] || { message "Backup file not found."; continue; }
                if [ -e "$target" ] && [ -n "$(find "$target" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
                    message "Restore is allowed only into a new or empty directory."; continue
                fi
                mkdir -p -- "$target" || { message "Could not create restore directory."; continue; }
                target_real=$(realpath -e -- "$target") || { message "Cannot resolve restore directory."; continue; }
                if ! tar -tzf "$archive" >/dev/null 2>&1; then message "This is not a readable TAR.GZ archive."; continue; fi
                unsafe=$(tar -tzf "$archive" | awk 'BEGIN{bad=0} /^\// {bad=1} {n=split($0,a,"/"); for(i=1;i<=n;i++) if(a[i]=="..") bad=1} END{print bad+0}')
                [ "$unsafe" = 0 ] || { message "Archive contains unsafe absolute or parent-directory paths. Restore blocked."; continue; }
                ask_yes "Restore this archive into:\n$target_real\n\nOnly restore backups you created or trust." || continue
                if tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$target_real"; then message "Restore completed in:\n$target_real"; else message "Restore failed. Inspect the destination before using its contents."; fi
                ;;
            *) return 0 ;;
        esac
    done
}

network_manager() {
    report=$(mktemp "${TMPDIR:-/tmp}/sphinx-network.XXXXXX") || { message "Could not create report."; return 1; }
    {
        echo "SPHINXPI NETWORK STATUS"
        echo "Generated: $(date)"
        echo
        echo "== INTERFACES / ADDRESSES =="
        if command -v ip >/dev/null 2>&1; then ip -brief address 2>&1; else echo "iproute2 is not installed."; fi
        echo
        echo "== DEFAULT ROUTE =="
        if command -v ip >/dev/null 2>&1; then ip route show default 2>&1; else echo "Unavailable"; fi
        echo
        echo "== DNS CONFIGURATION =="
        cat /etc/resolv.conf 2>/dev/null || true
        echo
        echo "== DNS TEST =="
        if command -v getent >/dev/null 2>&1; then getent ahosts deb.debian.org 2>&1 | sed -n '1,6p' || echo "DNS lookup failed"; else echo "getent unavailable"; fi
        echo
        echo "== INTERNET TEST =="
        if command -v ping >/dev/null 2>&1; then ping -c 1 -W 3 1.1.1.1 2>&1 | sed -n '1,5p' || echo "Ping failed or ICMP is blocked"; else echo "ping unavailable"; fi
        echo
        echo "== SSH SERVICE =="
        if command -v systemctl >/dev/null 2>&1; then systemctl is-active ssh 2>&1 || true; else echo "systemctl unavailable"; fi
        echo
        echo "This page is diagnostic only; it does not change network settings."
    } > "$report"
    show_file "$report" "SphinxPi Network Manager"
    rm -f "$report"
}

service_manager() {
    command -v systemctl >/dev/null 2>&1 || { message "systemd is not available on this system."; return 1; }
    while :; do
        action=$(whiptail --title "Service Manager" --menu "Inspect and manage system services." 18 72 6 \
            list "List all services" \
            status "Show service status" \
            start "Start a service" \
            stop "Stop a service" \
            restart "Restart a service" \
            enable "Enable service at boot" \
            disable "Disable service at boot" \
            back "Back" 3>&1 1>&2 2>&3) || return 0
        [ "$action" = back ] && return 0
        if [ "$action" = list ]; then
            tmp=$(mktemp "${TMPDIR:-/tmp}/sphinx-services.XXXXXX") || return 1
            systemctl list-units --type=service --all --no-pager > "$tmp" 2>&1 || true
            show_file "$tmp" "System Services"
            rm -f "$tmp"
            continue
        fi
        service=$(whiptail --title "Service Manager" --inputbox "Enter a service name (example: ssh or cron):" 9 70 "" 3>&1 1>&2 2>&3) || continue
        case "$service" in ""|*[!A-Za-z0-9_.@:-]*) message "Invalid service name."; continue ;; esac
        if [ "$action" = status ]; then
            tmp=$(mktemp "${TMPDIR:-/tmp}/sphinx-service.XXXXXX") || return 1
            systemctl status "$service" --no-pager > "$tmp" 2>&1 || true
            show_file "$tmp" "Service: $service"
            rm -f "$tmp"
            continue
        fi
        case "$action" in start|stop|restart|enable|disable) ;; *) continue ;; esac
        ask_yes "$action service '$service'?" || continue
        if root_command systemctl "$action" "$service"; then message "Command completed: systemctl $action $service"; else message "Service command failed. Check the service name and permissions."; fi
    done
}

log_viewer() {
    command -v journalctl >/dev/null 2>&1 || { message "journalctl is unavailable. This system may not use systemd journals."; return 1; }
    while :; do
        action=$(whiptail --title "Log Viewer" --menu "View recent system and service logs." 15 72 5 \
            boot "Current boot warnings and errors" \
            system "Recent system journal" \
            service "Logs for a service" \
            back "Back" 3>&1 1>&2 2>&3) || return 0
        [ "$action" = back ] && return 0
        tmp=$(mktemp "${TMPDIR:-/tmp}/sphinx-logs.XXXXXX") || return 1
        case "$action" in
            boot) journalctl -b -p warning --no-pager -n 250 > "$tmp" 2>&1 ;;
            system) journalctl --no-pager -n 250 > "$tmp" 2>&1 ;;
            service)
                service=$(whiptail --title "Service Logs" --inputbox "Service name (example: ssh):" 9 70 "" 3>&1 1>&2 2>&3) || { rm -f "$tmp"; continue; }
                case "$service" in ""|*[!A-Za-z0-9_.@:-]*) message "Invalid service name."; rm -f "$tmp"; continue ;; esac
                journalctl -u "$service" --no-pager -n 250 > "$tmp" 2>&1
                ;;
        esac
        show_file "$tmp" "SphinxPi Log Viewer"
        rm -f "$tmp"
    done
}

apps_manager() {
    [ -r "$CATALOG" ] || { message "App catalogue is missing: $CATALOG\nReinstall or update SphinxPi."; return 1; }
    while :; do
        query=$(whiptail --title "Install Apps" --inputbox "Search 100+ Debian packages by name, category or description. Leave blank to browse all." 10 76 "" 3>&1 1>&2 2>&3) || return 0
        tmp=$(mktemp "${TMPDIR:-/tmp}/sphinx-apps.XXXXXX") || return 1
        : > "$tmp"
        while IFS='|' read -r package category description; do
            case "$package" in ""|\#*) continue ;; esac
            if [ -n "$query" ]; then
                printf '%s %s %s\n' "$package" "$category" "$description" | grep -qiF -- "$query" || continue
            fi
            if installed_package "$package"; then
                state="ON"
                label="[INSTALLED] $description ($category)"
            else
                state="OFF"
                label="[not installed] $description ($category)"
            fi
            printf '%s\t%s\t%s\n' "$package" "$label" "$state" >> "$tmp"
        done < "$CATALOG"
        if [ ! -s "$tmp" ]; then
            rm -f "$tmp"
            message "No catalogue entries matched '$query'. Try another search."
            continue
        fi
        set --
        while IFS="$(printf '\t')" read -r package label state; do
            set -- "$@" "$package" "$label" "$state"
        done < "$tmp"
        rm -f "$tmp"
        selected=$(whiptail --title "Install Apps — select packages" --checklist "Installed packages are marked ON. Select one or more packages with SPACE, then press ENTER. Unavailable packages are checked against APT before installation." 24 88 15 "$@" 3>&1 1>&2 2>&3) || continue
        [ -n "$selected" ] || continue
        selected=$(printf '%s' "$selected" | tr -d '"')
        # Whiptail returns only package IDs from the fixed, trusted catalogue.
        set -- $selected
        ask_yes "Install selected packages?\n\n$selected\n\nAPT will skip packages with no candidate for this architecture." || continue
        if ! root_command apt-get update; then message "APT update failed. Check: sphinx network-check"; continue; fi
        available=""
        unavailable=""
        for package in "$@"; do
            candidate=$(apt-cache policy "$package" 2>/dev/null | awk '$1=="Candidate:" {print $2}')
            if [ -n "$candidate" ] && [ "$candidate" != "(none)" ]; then available="$available $package"
            else unavailable="$unavailable $package"
            fi
        done
        if [ -z "$available" ]; then message "None of the selected packages has an APT candidate for this system.\nUnavailable:$unavailable"; continue; fi
        if [ -n "$unavailable" ]; then
            ask_yes "These packages are unavailable and will be skipped:$unavailable\n\nInstall available packages:$available ?" || continue
        fi
        if [ -r "$TRACKER" ]; then root_command sh "$TRACKER" $available || true; fi
        if root_command apt-get install -y --no-install-recommends $available; then
            message "Installation finished.\nInstalled/requested:$available\nSkipped (no APT candidate):${unavailable:- none}"
        else
            message "APT could not install the selected packages. Review the terminal output."
        fi
    done
}

if ! command -v whiptail >/dev/null 2>&1; then
    echo "SphinxPi System Manager requires whiptail. Install it with: apt-get install whiptail" >&2
    exit 1
fi

case "$MODE" in
    monitor) resource_monitor ;;
    backup) backup_manager ;;
    network) network_manager ;;
    services) service_manager ;;
    logs) log_viewer ;;
    apps) apps_manager ;;
    menu)
        while :; do
            choice=$(whiptail --title "SphinxPi System Manager" --menu "Lightweight system tools for Raspberry Pi Zero." 20 74 8 \
                monitor "Resource Monitor" \
                backup "Backup Manager" \
                network "Network Manager" \
                services "Service Manager" \
                logs "Log Viewer" \
                apps "Install Apps (search 100+ packages)" \
                back "Back to SphinxPi" 3>&1 1>&2 2>&3) || exit 0
            case "$choice" in
                monitor) resource_monitor ;;
                backup) backup_manager ;;
                network) network_manager ;;
                services) service_manager ;;
                logs) log_viewer ;;
                apps) apps_manager ;;
                back) exit 0 ;;
            esac
        done
        ;;
    *) echo "Unknown System Manager mode: $MODE" >&2; exit 2 ;;
esac
