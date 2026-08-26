#!/bin/sh

set -u

REPO_RAW="https://raw.githubusercontent.com/GLiNet-Community-Scripts/Tailscale-on-AP-mode/main"
TMP_DIR="/tmp/tailscale-ap-mode-install.$$"
HELPER_DST="/usr/bin/tailscale-ap-mode"
INIT_DST="/etc/init.d/tailscale-ap-mode"

log() {
    printf '%s\n' "$*"
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

[ "$(id -u 2>/dev/null || echo 1)" = "0" ] || fail "Run this installer as root."
[ -f /etc/config/glconfig ] || fail "This does not look like GL.iNet firmware: /etc/config/glconfig is missing."
[ -f /usr/bin/gl_tailscale ] || fail "GL.iNet Tailscale wrapper /usr/bin/gl_tailscale was not found."
[ -x /etc/init.d/tailscale ] || fail "Tailscale service /etc/init.d/tailscale was not found."

mkdir -p "$TMP_DIR" || fail "Could not create $TMP_DIR."

download() {
    url="$1"
    dest="$2"

    if command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$dest" && return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest" && return 0
    fi

    return 1
}

log "Downloading Tailscale AP-mode helper..."
download "$REPO_RAW/files/tailscale-ap-mode" "$TMP_DIR/tailscale-ap-mode" || fail "Could not download the helper from GitHub."
download "$REPO_RAW/files/tailscale-ap-mode.init" "$TMP_DIR/tailscale-ap-mode.init" || fail "Could not download the init service from GitHub."

/bin/sh -n "$TMP_DIR/tailscale-ap-mode" || fail "Downloaded helper failed shell syntax validation."
/bin/sh -n "$TMP_DIR/tailscale-ap-mode.init" || fail "Downloaded init service failed shell syntax validation."

cp "$TMP_DIR/tailscale-ap-mode" "$HELPER_DST" || fail "Could not install $HELPER_DST."
cp "$TMP_DIR/tailscale-ap-mode.init" "$INIT_DST" || fail "Could not install $INIT_DST."
chmod 0755 "$HELPER_DST" "$INIT_DST"

log "Installing firmware-upgrade persistence..."
"$HELPER_DST" install-persistence

log "Enabling boot service..."
"$INIT_DST" enable

log "Applying AP-mode compatibility patch and enabling Tailscale..."
"$HELPER_DST" enable

log ""
log "Installation complete."
log ""
"$HELPER_DST" status || true

if command -v tailscale >/dev/null 2>&1; then
    if ! tailscale status >/dev/null 2>&1; then
        log ""
        log "If this router has not been authenticated yet, run:"
        log "  tailscale up --accept-dns=false"
    fi
fi

log ""
log "Useful commands:"
log "  tailscale-ap-mode status"
log "  tailscale-ap-mode restart"
log "  tailscale-ap-mode restore"
