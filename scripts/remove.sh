#!/bin/sh
set -eu
MODE=${1:-normal}
if [ "$(id -u)" -ne 0 ]; then echo 'Run as root: sudo sphinx uninstall [-f]'; exit 1; fi
if command -v whiptail >/dev/null 2>&1; then
 if [ "$MODE" = full ]; then whiptail --title 'SphinxPi Full Removal' --yesno 'Purge SphinxPi, remove optional packages recorded as newly installed by SphinxPi, and delete its system state/configuration? Your home folder and ~/SphinxPi source checkout will NOT be deleted.' 12 72 || exit 0
 else whiptail --title 'Uninstall SphinxPi' --yesno 'Remove the SphinxPi package only? Optional desktop/archive packages and settings will remain.' 10 68 || exit 0; fi
else
 echo "SphinxPi removal mode: $MODE"; [ "$MODE" != full ] || echo 'Tracked optional packages and system state will also be removed.'
 printf 'Continue? [y/N] '; read answer; case "$answer" in y|Y|yes|YES) ;; *) echo Cancelled.; exit 0 ;; esac
fi
if [ "$MODE" = full ]; then
 manifest=/var/lib/sphinxpi/apt-packages; packages=''
 if [ -f "$manifest" ]; then packages=$(grep -E '^[a-z0-9][a-z0-9+.-]*$' "$manifest" | sort -u | tr '\n' ' '); else echo 'No install manifest: optional packages from older installs cannot be identified safely.'; fi
 apt-get purge -y sphinxpi
 if [ -n "$packages" ]; then apt-get purge -y $packages; fi
 rm -rf /etc/sphinxpi /var/lib/sphinxpi /var/cache/sphinxpi /usr/lib/sphinxpi
 echo 'Full SphinxPi system removal complete. Home files and source checkout were kept.'
else apt-get remove -y sphinxpi; echo 'SphinxPi removed. Optional packages and settings were kept.'; fi
