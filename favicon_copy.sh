#!/bin/sh
# favicon_copy.sh – Captive-portal favicon helper (install / uninstall)

### CONFIG ############################################################
SCRIPT_PATH="/jffs/scripts/favicon_copy.sh"

SRC_FAVICON="/jffs/scripts/favicon.ico"
DEST_DIR="/tmp/uamsrv/www"
DEST_FAVICON="$DEST_DIR/favicon.ico"

FAVICON_URL="https://raw.githubusercontent.com/ExtremeFiretop/CaptivePortal_Workaround/main/favicon.ico"

UAM_BIN="/usr/sbin/uamsrv"
UAM_CONF="/tmp/uamsrv.conf"                  # adjust if needed

SERVICES_START="/jffs/scripts/services-start"
HOOK_LINE='[ -f /jffs/scripts/favicon_copy.sh ] && sh /jffs/scripts/favicon_copy.sh &  #Captive Portal workaround#'
########################################################################

install_hook() {
    echo "Checking boot-hook in $SERVICES_START"
    touch "$SERVICES_START"
    if grep -qxF "$HOOK_LINE" "$SERVICES_START"; then
        echo "Hook already present - OK"
    else
        echo "Adding hook"
        echo "$HOOK_LINE" >> "$SERVICES_START"
    fi
    chmod +x "$SERVICES_START"
}

remove_hook() {
    [ -f "$SERVICES_START" ] || return 0
    sed -i "\|$HOOK_LINE|d" "$SERVICES_START"
}

ensure_favicon() {
    if [ -f "$SRC_FAVICON" ]; then
        echo "Local favicon already present - OK"
        return 0
    fi

    echo "Downloading favicon from GitHub"
    curl -LSs --retry 4 --retry-delay 5 --retry-connrefused \
         -o "$SRC_FAVICON" "$FAVICON_URL"
    if [ $? -ne 0 ]
    then
       return 1
    fi
    if [ -f "$SRC_FAVICON" ]; then
        echo "Download favicon succeeded"
    else
        echo "Download favicon failed"
        return 1
    fi
}

copy_favicon() {
    ensure_favicon || return 1
    echo "Copying favicon to $DEST_FAVICON"
    mkdir -p "$DEST_DIR"
    cp -f "$SRC_FAVICON" "$DEST_FAVICON"
}

restart_uamsrv() {
    echo "Restarting uamsrv"
    killall uamsrv 2>/dev/null
    sleep 1
    if [ -x "$UAM_BIN" ]; then
        "$UAM_BIN" -f "$UAM_CONF" &
        echo "uamsrv started with $UAM_CONF"
    else
        echo "$UAM_BIN not found or not executable"
    fi
}

uninstall_cleanup() {
    echo "Removing boot-hook from $SERVICES_START"
    remove_hook

    echo "Deleting source favicon at $SRC_FAVICON (if present)"
    rm -f "$SRC_FAVICON"

    echo "Deleting script itself ($SCRIPT_PATH)"
    rm -f "$SCRIPT_PATH"

    echo "Uninstall complete."
}

#######################################################################
# MAIN
case "$1" in
    uninstall)
        uninstall_cleanup
        ;;
    ""|install)
        echo "=== Installing favicon workaround ==="
        copy_favicon || exit 1
        restart_uamsrv
        install_hook
        echo "Install complete."
        ;;
    *)
        echo "Usage : $0 [install|uninstall]"
        exit 1
        ;;
esac
exit 0
