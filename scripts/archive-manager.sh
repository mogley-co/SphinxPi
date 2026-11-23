#!/bin/sh
set -eu

APP="SphinxPi Archive Manager"

if [ "$(id -u)" -eq 0 ]; then
    echo "Run the archive manager as your normal user, not root."
    exit 1
fi

for cmd in tar gzip xz bzip2; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Missing $cmd. Run: sudo sphinx archive-install"
        exit 1
    }
done

ask() {
    prompt=$1
    default=${2:-}
    if command -v whiptail >/dev/null 2>&1; then
        whiptail --title "$APP" --inputbox "$prompt" 10 72 "$default" 3>&1 1>&2 2>&3
    else
        printf "%s" "$prompt" >&2
        [ -z "$default" ] || printf " [%s]" "$default" >&2
        printf ": " >&2
        IFS= read -r answer
        printf "%s" "${answer:-$default}"
    fi
}

yesno() {
    prompt=$1
    if command -v whiptail >/dev/null 2>&1; then
        whiptail --title "$APP" --yesno "$prompt" 10 65
    else
        printf "%s [y/N] " "$prompt" >&2
        IFS= read -r answer
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
        IFS= read -r choice
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
        IFS= read -r _
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
        IFS= read -r f
        case "$f" in
            1) echo zip ;; 2) echo zipaes ;; 3) echo seven ;; 4) echo tar ;;
            5) echo targz ;; 6) echo tarxz ;; 7) echo tarbz2 ;;
            *) echo "" ;;
        esac
    fi
}

create_archive() {
    source=$(ask "Full path to the file or folder to compress")
    [ -n "$source" ] || return
    if [ ! -e "$source" ]; then message "Source not found: $source"; return; fi

    format=$(choose_format) || return
    [ -n "$format" ] || return
    case "$format" in
        zip) ext=".zip" ;;
        zipaes) ext=".zip" ;;
        seven) ext=".7z" ;;
        tar) ext=".tar" ;;
        targz) ext=".tar.gz" ;;
        tarxz) ext=".tar.xz" ;;
        tarbz2) ext=".tar.bz2" ;;
    esac
    base=$(basename "$source")
    output=$(ask "Output archive path" "$PWD/$base$ext")
    [ -n "$output" ] || return
    if [ -e "$output" ]; then
        yesno "The output already exists. Overwrite it?" || return
        rm -f -- "$output"
    fi

    level=$(ask "Compression level (0 = fastest/store, 9 = smallest; TAR uses format defaults)" "6")
    case "$level" in 0|1|2|3|4|5|6|7|8|9) ;; *) message "Invalid compression level."; return ;; esac

    case "$format" in
        zip)
            command -v zip >/dev/null 2>&1 || { message "Install ZIP support: sudo sphinx archive-install"; return; }
            zip "-$level" -r "$output" "$source"
            ;;
        zipaes)
            command -v 7zz >/dev/null 2>&1 || { message "Install 7-Zip support: sudo sphinx archive-install"; return; }
            message "7-Zip will securely prompt for an AES-256 password in the terminal."
            7zz a -tzip -mem=AES256 "-mx=$level" -p "$output" "$source"
            ;;
        seven)
            command -v 7zz >/dev/null 2>&1 || { message "Install 7-Zip support: sudo sphinx archive-install"; return; }
            if yesno "Protect this 7Z archive with an AES-256 password?"; then
                7zz a -t7z -mhe=on "-mx=$level" -p "$output" "$source"
            else
                7zz a -t7z "-mx=$level" "$output" "$source"
            fi
            ;;
        tar) tar -cf "$output" "$source" ;;
        targz) tar -I "gzip -$level" -cf "$output" "$source" ;;
        tarxz) tar -I "xz -$level" -cf "$output" "$source" ;;
        tarbz2) tar -I "bzip2 -$level" -cf "$output" "$source" ;;
    esac

    if [ -f "$output" ]; then
        size=$(du -h "$output" | awk '{print $1}')
        message "Archive created successfully.\n\nFile: $output\nSize: $size"
    else
        message "The archive command did not produce an output file. Check the error above."
    fi
}

get_archive() {
    ask "Full path to the archive"
}

extract_archive() {
    archive=$(get_archive)
    [ -n "$archive" ] || return
    [ -f "$archive" ] || { message "Archive not found."; return; }
    dest=$(ask "Extract into this directory" "$PWD")
    [ -n "$dest" ] || return
    mkdir -p "$dest"
    case "$archive" in
        *.zip)
            if command -v 7zz >/dev/null 2>&1; then (cd "$dest" && 7zz x "$archive"); else (cd "$dest" && unzip "$archive"); fi ;;
        *.7z) 7zz x "-o$dest" "$archive" ;;
        *.tar|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.bz2|*.tbz2) tar -xf "$archive" -C "$dest" ;;
        *) message "Unknown extension. Supported: zip, 7z, tar, tar.gz, tar.xz, tar.bz2."; return ;;
    esac
    message "Extraction finished.\nDestination: $dest"
}

list_archive() {
    archive=$(get_archive)
    [ -n "$archive" ] || return
    [ -f "$archive" ] || { message "Archive not found."; return; }
    case "$archive" in
        *.zip) unzip -l "$archive" ;;
        *.7z) 7zz l "$archive" ;;
        *.tar|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.bz2|*.tbz2) tar -tf "$archive" ;;
        *) message "Unsupported archive extension."; return ;;
    esac
    printf "\nPress Enter to return to the menu..."
    IFS= read -r _
}

test_archive() {
    archive=$(get_archive)
    [ -n "$archive" ] || return
    [ -f "$archive" ] || { message "Archive not found."; return; }
    case "$archive" in
        *.zip) unzip -t "$archive" ;;
        *.7z) 7zz t "$archive" ;;
        *.tar.gz|*.tgz) gzip -t "$archive" && tar -tzf "$archive" >/dev/null ;;
        *.tar.xz|*.txz) xz -t "$archive" && tar -tJf "$archive" >/dev/null ;;
        *.tar.bz2|*.tbz2) bzip2 -t "$archive" && tar -tjf "$archive" >/dev/null ;;
        *.tar) tar -tf "$archive" >/dev/null ;;
        *) message "Unsupported archive extension."; return ;;
    esac
    message "Archive check completed. Review the command output for errors."
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
