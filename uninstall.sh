#!/bin/sh

set -u

HELPER="/usr/bin/tailscale-ap-mode"
INIT="/etc/init.d/tailscale-ap-mode"
SYSUPGRADE_CONF="/etc/sysupgrade.conf"

log() {
    printf '%s\n' "$*"
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[ "$(id -u 2>/dev/null || echo 1)" = "0" ] || fail "Run this uninstaller as root."

log "Removing Tailscale AP-mode compatibility shim..."

if [ -x "$INIT" ]; then
    "$INIT" disable >/dev/null 2>&1 || true
    "$INIT" stop >/dev/null 2>&1 || true
fi

if [ -x "$HELPER" ]; then
    "$HELPER" restore || fail "Could not restore the GL.iNet Tailscale wrapper."
    "$HELPER" remove-persistence || true
else
    if [ -f /usr/bin/gl_tailscale ] && grep -q '# tailscale-ap-mode' /usr/bin/gl_tailscale 2>/dev/null; then
        tmp="/tmp/gl_tailscale.restore.$$"
        awk '$0 !~ /# tailscale-ap-mode[[:space:]]*$/ { print $0 }' /usr/bin/gl_tailscale > "$tmp" || fail "Could not generate restored wrapper."
        /bin/sh -n "$tmp" || {
            rm -f "$tmp"
            fail "Restored wrapper failed shell syntax validation."
        }
        cp "$tmp" /usr/bin/gl_tailscale || {
            rm -f "$tmp"
            fail "Could not restore /usr/bin/gl_tailscale."
        }
        chmod 0755 /usr/bin/gl_tailscale
        rm -f "$tmp"
        /usr/bin/gl_tailscale restart >/dev/null 2>&1 || true
    fi

    if [ -f "$SYSUPGRADE_CONF" ]; then
        tmp="/tmp/sysupgrade.conf.$$"
        awk '
            $0 != "/usr/bin/tailscale-ap-mode" &&
            $0 != "/etc/init.d/tailscale-ap-mode" { print $0 }
        ' "$SYSUPGRADE_CONF" > "$tmp" && cat "$tmp" > "$SYSUPGRADE_CONF"
        rm -f "$tmp"
    fi
fi

rm -f "$INIT" "$HELPER"

log "Uninstall complete."
log "GL.iNet's stock non-router Tailscale behavior is active again."
