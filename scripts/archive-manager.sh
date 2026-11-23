#!/bin/sh
set -eu

APP="SphinxPi Archive Manager"

if [ "$(id -u)" -eq 0 ]; then
    echo "Run the archive manager as your normal user, not root."
    exit 1
fi

for cmd in tar gzip xz bzip2 du basename mkdir find realpath; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Missing required command: $cmd"
        exit 1
    }
done

expand_path() {
    case "$1" in
        "~") printf '%s\n' "$HOME" ;;
        "~/"*) printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

ask() {
    prompt=$1
    default=${2:-}
    if command -v whiptail >/dev/null 2>&1; then
        whiptail --title "$APP" --inputbox "$prompt" 10 72 "$default" 3>&1 1>&2 2>&3
    else
        printf "%s" "$prompt" >&2
        [ -z "$default" ] || printf " [%s]" "$default" >&2
        printf ": " >&2
        IFS= read -r answer || return 1
        printf "%s" "${answer:-$default}"
    fi
}

yesno() {
    prompt=$1
    if command -v whiptail >/dev/null 2>&1; then
        whiptail --title "$APP" --yesno "$prompt" 10 65
    else
        printf "%s [y/N] " "$prompt" >&2
        IFS= read -r answer || return 1
        case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
    fi
}

menu() {
    if command -v whiptail >/dev/null 2>&1; then
        whiptail --title "$APP" --menu "Choose an operation" 18 72 8 \
            create "Create a compressed archive" \
            extract "Extract an archive" \
            list "List archive contents" \
            test "Test archive integrity" \
            quit "Exit" 3>&1 1>&2 2>&3
    else
        echo >&2
        echo "=== $APP ===" >&2
        echo "1) Create archive" >&2
        echo "2) Extract archive" >&2
        echo "3) List contents" >&2
        echo "4) Test archive" >&2
        echo "5) Exit" >&2
        printf "Choose: " >&2
        IFS= read -r choice || return 1
        case "$choice" in
            1) echo create ;;
            2) echo extract ;;
            3) echo list ;;
            4) echo test ;;
            *) echo quit ;;
        esac
    fi
}

message() {
    if command -v whiptail >/dev/null 2>&1; then
        whiptail --title "$APP" --msgbox "$1" 10 72
    else
        printf "\n%s\n" "$1"
        printf "Press Enter to continue..."
        IFS= read -r _ || true
    fi
}

choose_format() {
    if command -v whiptail >/dev/null 2>&1; then
        whiptail --title "$APP" --menu "Select archive format" 20 72 10 \
            zip "ZIP (widely compatible)" \
            zipaes "ZIP with AES-256 password" \
            seven "7Z (high compression, AES-256 password option)" \
            tar "TAR (no compression)" \
            targz "TAR.GZ" \
            tarxz "TAR.XZ (often smaller, slower)" \
            tarbz2 "TAR.BZ2" 3>&1 1>&2 2>&3
    else
        echo "Formats: 1 ZIP | 2 ZIP AES-256 | 3 7Z | 4 TAR | 5 TAR.GZ | 6 TAR.XZ | 7 TAR.BZ2" >&2
        printf "Format: " >&2
        IFS= read -r f || return 1
        case "$f" in
            1) echo zip ;; 2) echo zipaes ;; 3) echo seven ;; 4) echo tar ;;
            5) echo targz ;; 6) echo tarxz ;; 7) echo tarbz2 ;;
            *) echo "" ;;
        esac
    fi
}

pause_output() {
    printf "\nPress Enter to return to the menu..."
    IFS= read -r _ || true
}

create_archive() {
    source=$(ask "Path to the file or folder to compress") || return 0
    source=$(expand_path "$source")
    [ -n "$source" ] || return 0
    if [ ! -e "$source" ]; then message "Source not found: $source"; return 0; fi

    format=$(choose_format) || return 0
    [ -n "$format" ] || return 0
    case "$format" in
        zip)
            if ! command -v zip >/dev/null 2>&1; then message "ZIP command missing. Run: sudo sphinx archive-install (or log in as root and run sphinx archive-install)"; return 0; fi
            ;;
        zipaes|seven)
            if ! command -v 7z >/dev/null 2>&1; then message "7-Zip command missing. Run: sudo sphinx archive-install (or log in as root and run sphinx archive-install)"; return 0; fi
            ;;
    esac
    case "$format" in
        zip|zipaes) ext=".zip" ;;
        seven) ext=".7z" ;;
        tar) ext=".tar" ;;
        targz) ext=".tar.gz" ;;
        tarxz) ext=".tar.xz" ;;
        tarbz2) ext=".tar.bz2" ;;
        *) message "Unknown format."; return 0 ;;
    esac

    base=$(basename "$source")
    output=$(ask "Output archive path" "$PWD/$base$ext") || return 0
    output=$(expand_path "$output")
    [ -n "$output" ] || return 0
    case "$output" in
        *"$ext") ;;
        *) output="$output$ext" ;;
    esac
    source_real=$(realpath -e -- "$source") || { message "Could not resolve the source path."; return 0; }
    output_real=$(realpath -m -- "$output") || { message "Could not resolve the output path."; return 0; }
    if [ "$source_real" = "$output_real" ]; then message "The archive output cannot overwrite its source."; return 0; fi
    if [ -d "$source_real" ]; then
        case "$output_real" in
            "$source_real"/*) message "Choose an output path outside the source folder so the archive does not include itself."; return 0 ;;
        esac
    fi
    output_dir=$(dirname -- "$output")
    if [ ! -d "$output_dir" ]; then message "The output directory does not exist."; return 0; fi
    if [ -d "$output" ]; then message "Output path is a directory."; return 0; fi
    if [ -e "$output" ] || [ -L "$output" ]; then
        yesno "The output already exists. Replace it only after the new archive is created?" || return 0
    fi

    final_output=$output
    tmp_output=$(mktemp --suffix="$ext" "$output_dir/.sphinxpi-archive.XXXXXX") || { message "Could not create a temporary output file."; return 0; }
    rm -f -- "$tmp_output"
    output=$tmp_output

    level=$(ask "Compression level (0 = fastest, 9 = strongest; TAR ignores this)" "4") || { rm -f -- "$tmp_output"; return 0; }
    case "$level" in 0|1|2|3|4|5|6|7|8|9) ;; *) rm -f -- "$tmp_output"; message "Invalid compression level."; return 0 ;; esac
    case "$format:$level" in
        seven:7|seven:8|seven:9|tarxz:7|tarxz:8|tarxz:9)
            yesno "This compression level can use a lot of memory and may make a 512 MB Pi Zero unresponsive. Continue?" || { rm -f -- "$tmp_output"; return 0; }
            ;;
    esac

    case "$format" in
        zip)
            if zip "-$level" -r "$output" "$source"; then :; else rm -f -- "$output"; message "ZIP creation failed."; return 0; fi
            ;;
        zipaes)
            message "7-Zip will ask for the AES-256 password in the terminal. The password is not saved in shell history."
            if 7z a -tzip -mem=AES256 "-mx=$level" -p "$output" "$source"; then :; else rm -f -- "$output"; message "Encrypted ZIP creation failed."; return 0; fi
            ;;
        seven)
            if yesno "Protect this 7Z archive with an AES-256 password?"; then
                if 7z a -t7z -mhe=on "-mx=$level" -p "$output" "$source"; then :; else rm -f -- "$output"; message "7Z creation failed."; return 0; fi
            else
                if 7z a -t7z "-mx=$level" "$output" "$source"; then :; else rm -f -- "$output"; message "7Z creation failed."; return 0; fi
            fi
            ;;
        tar)
            if tar -cf "$output" -C "$(dirname "$source")" -- "$(basename "$source")"; then :; else rm -f -- "$output"; message "TAR creation failed."; return 0; fi
            ;;
        targz)
            if tar -I "gzip -$level" -cf "$output" -C "$(dirname "$source")" -- "$(basename "$source")"; then :; else rm -f -- "$output"; message "TAR.GZ creation failed."; return 0; fi
            ;;
        tarxz)
            if tar -I "xz -$level" -cf "$output" -C "$(dirname "$source")" -- "$(basename "$source")"; then :; else rm -f -- "$output"; message "TAR.XZ creation failed."; return 0; fi
            ;;
        tarbz2)
            if tar -I "bzip2 -$level" -cf "$output" -C "$(dirname "$source")" -- "$(basename "$source")"; then :; else rm -f -- "$output"; message "TAR.BZ2 creation failed."; return 0; fi
            ;;
    esac

    if [ -f "$output" ]; then
        if mv -f -- "$output" "$final_output"; then
            size=$(du -h "$final_output" | awk '{print $1}')
            message "Archive created.\n\nFile: $final_output\nSize: $size"
        else
            rm -f -- "$output"
            message "Could not move the completed archive into place. The previous output was preserved."
        fi
    else
        rm -f -- "$output"
        message "No output archive was created. Check the error output. The previous output was preserved."
    fi
}

get_archive() {
    archive=$(ask "Path to the archive") || return 1
    expand_path "$archive"
}

extract_archive() {
    archive=$(get_archive) || return 0
    [ -n "$archive" ] || return 0
    [ -f "$archive" ] || { message "Archive not found."; return 0; }
    dest=$(ask "Extract into this directory (use a new empty folder)" "$PWD") || return 0
    dest=$(expand_path "$dest")
    [ -n "$dest" ] || return 0
    if ! mkdir -p -- "$dest"; then message "Could not create the destination directory."; return 0; fi
    if [ -L "$dest" ]; then message "For safety, choose a real directory, not a symbolic link."; return 0; fi
    dest=$(realpath -e -- "$dest") || { message "Could not resolve the destination directory."; return 0; }
    contents=$(find "$dest" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) || { message "Could not inspect the destination directory."; return 0; }
    if [ -n "$contents" ]; then
        message "For safety, extraction is allowed only into an empty directory. Create a new folder and try again."
        return 0
    fi

    case "$archive" in
        *.zip|*.7z)
            if ! command -v 7z >/dev/null 2>&1; then message "7-Zip is required. Run: sudo sphinx archive-install (or log in as root and run sphinx archive-install)"; return 0; fi
            if 7z x "-o$dest" "$archive"; then message "Extraction finished.\nDestination: $dest"; else message "Extraction failed. Check the archive and password."; fi
            ;;
        *.tar|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.bz2|*.tbz2)
            if tar --no-same-owner --no-same-permissions -xf "$archive" -C "$dest"; then message "Extraction finished.\nDestination: $dest"; else message "Extraction failed. Do not use files from an untrusted archive."; fi
            ;;
        *) message "Unknown extension. Supported: zip, 7z, tar, tar.gz, tar.xz, tar.bz2."; return 0 ;;
    esac
}

list_archive() {
    archive=$(get_archive) || return 0
    [ -n "$archive" ] || return 0
    [ -f "$archive" ] || { message "Archive not found."; return 0; }
    case "$archive" in
        *.zip|*.7z)
            if ! command -v 7z >/dev/null 2>&1; then message "7-Zip is required. Run: sudo sphinx archive-install (or log in as root and run sphinx archive-install)"; return 0; fi
            if 7z l "$archive"; then pause_output; else message "Could not list this archive."; fi
            ;;
        *.tar)
            if tar -tf "$archive"; then pause_output; else message "Could not list this archive."; fi
            ;;
        *.tar.gz|*.tgz)
            if tar -tzf "$archive"; then pause_output; else message "Could not list this archive."; fi
            ;;
        *.tar.xz|*.txz)
            if tar -tJf "$archive"; then pause_output; else message "Could not list this archive."; fi
            ;;
        *.tar.bz2|*.tbz2)
            if tar -tjf "$archive"; then pause_output; else message "Could not list this archive."; fi
            ;;
        *) message "Unsupported archive extension."; return 0 ;;
    esac
}

test_archive() {
    archive=$(get_archive) || return 0
    [ -n "$archive" ] || return 0
    [ -f "$archive" ] || { message "Archive not found."; return 0; }
    case "$archive" in
        *.zip|*.7z)
            if ! command -v 7z >/dev/null 2>&1; then message "7-Zip is required. Run: sudo sphinx archive-install (or log in as root and run sphinx archive-install)"; return 0; fi
            if 7z t "$archive"; then message "Archive integrity test passed."; else message "Archive test FAILED. The file may be damaged or the password may be incorrect."; fi
            ;;
        *.tar.gz|*.tgz)
            if gzip -t "$archive" && tar -tzf "$archive" >/dev/null; then message "Archive integrity test passed."; else message "Archive integrity test FAILED."; fi
            ;;
        *.tar.xz|*.txz)
            if xz -t "$archive" && tar -tJf "$archive" >/dev/null; then message "Archive integrity test passed."; else message "Archive integrity test FAILED."; fi
            ;;
        *.tar.bz2|*.tbz2)
            if bzip2 -t "$archive" && tar -tjf "$archive" >/dev/null; then message "Archive integrity test passed."; else message "Archive integrity test FAILED."; fi
            ;;
        *.tar)
            if tar -tf "$archive" >/dev/null; then message "TAR listing completed; TAR has no built-in checksum."; else message "TAR read failed."; fi
            ;;
        *) message "Unsupported archive extension."; return 0 ;;
    esac
}

while :; do
    action=$(menu) || exit 0
    case "$action" in
        create) create_archive ;;
        extract) extract_archive ;;
        list) list_archive ;;
        test) test_archive ;;
        *) exit 0 ;;
    esac
done
