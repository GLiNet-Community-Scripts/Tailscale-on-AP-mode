# Tailscale on GL.iNet AP Mode

Run the GL.iNet built-in Tailscale client while the router is operating in **Access Point mode**.

GL.iNet firmware intentionally stops Tailscale when `glconfig.general.mode` is not `router`. This project applies a small, reversible compatibility patch to `/usr/bin/gl_tailscale` so that **AP mode (`ap`) is treated as router mode only for that Tailscale mode check**. Normal AP networking remains unchanged.

> [!IMPORTANT]
> This is an unofficial community workaround. GL.iNet does not officially support its Tailscale GUI integration in Access Point mode.

## What this does

- Keeps the stock GL.iNet Tailscale package and daemon.
- Does **not** replace the Tailscale binaries.
- Changes only the GL wrapper behavior that stops Tailscale outside router mode.
- Limits the workaround to **Access Point mode**; Extender/Relay modes are left alone.
- Re-applies the patch automatically at boot.
- Survives GL.iNet firmware upgrades without preserving an old copy of `gl_tailscale` over a newer firmware version.
- Provides `status`, `apply`, and `restore` commands.
- Includes a clean uninstaller that restores the firmware copy from `/rom` when available.

## Why this is needed

GL.iNet's `/usr/bin/gl_tailscale` wrapper contains logic equivalent to:

```sh
sys_mode=$(uci -q get glconfig.general.mode)
if [ "$sys_mode" != "router" ]; then
    /etc/init.d/tailscale stop
    modify_dns_resolv 0
    exit 0
fi
```

GL.iNet staff previously published a workaround that removes this non-router check. This project takes a narrower approach by inserting:

```sh
[ "$sys_mode" = "ap" ] && sys_mode="router" # tailscale-ap-mode
```

immediately after GL.iNet reads `glconfig.general.mode`. The rest of the vendor script remains intact.

References:

- GL.iNet forum: https://forum.gl-inet.com/t/tailscale-app-no-longer-running-in-ap-mode/35493
- GL.iNet Tailscale docs: https://docs.gl-inet.com/router/en/4/interface_guide/tailscale/

## Requirements

- GL.iNet firmware 4.x
- A model with GL.iNet's native Tailscale package
- SSH access as `root`
- `/usr/bin/gl_tailscale`
- `/etc/init.d/tailscale`

## Install

SSH into the GL.iNet router and run:

```sh
wget -qO- https://raw.githubusercontent.com/GLiNet-Community-Scripts/Tailscale-on-AP-mode/main/install.sh | sh
```

The installer:

1. verifies that this looks like a GL.iNet firmware installation;
2. installs the AP-mode helper and init service;
3. adds the helper files to `/etc/sysupgrade.conf`;
4. patches the current firmware's `gl_tailscale` wrapper;
5. enables GL.iNet's Tailscale UCI setting;
6. enables the Tailscale service and restarts the GL wrapper.

### Authenticate Tailscale

If the router has never been authenticated, run:

```sh
tailscale up --accept-dns=false
```

Open the authentication URL printed by Tailscale, then verify:

```sh
tailscale status
tailscale ip -4
```

## Usage

```sh
# Show GL mode, patch state, daemon state, and Tailscale status
tailscale-ap-mode status

# Re-apply the AP-mode compatibility patch
tailscale-ap-mode apply

# Restore the stock GL wrapper from /rom
tailscale-ap-mode restore
```

## Firmware upgrades

The project intentionally **does not preserve the modified `/usr/bin/gl_tailscale` file** during sysupgrade. Preserving that file could overwrite a newer GL.iNet wrapper after a firmware upgrade.

Instead, only these helper files are preserved:

```text
/usr/bin/tailscale-ap-mode
/etc/init.d/tailscale-ap-mode
```

On the first boot after an upgrade, the init service patches the **new firmware's** copy of `/usr/bin/gl_tailscale` and restarts Tailscale if GL's Tailscale setting is enabled.

## Uninstall

```sh
wget -qO- https://raw.githubusercontent.com/GLiNet-Community-Scripts/Tailscale-on-AP-mode/main/uninstall.sh | sh
```

Or, if the helper is already installed:

```sh
tailscale-ap-mode restore
/etc/init.d/tailscale-ap-mode disable
rm -f /etc/init.d/tailscale-ap-mode /usr/bin/tailscale-ap-mode
```

## AP mode and subnet routing

This project only enables the Tailscale daemon/integration while the GL.iNet device is an AP. It does not automatically advertise your LAN as a Tailscale subnet.

If you intentionally want the AP to be a subnet router, configure Tailscale separately, for example:

```sh
tailscale set --advertise-routes=192.168.1.0/24
```

Then approve the advertised route in the Tailscale admin console.

Do not copy the example subnet blindly; use the actual subnet attached to the AP.

## Troubleshooting

### Check the GL.iNet network mode

```sh
uci -q get glconfig.general.mode
```

Expected in Access Point mode:

```text
ap
```

### Check whether the patch is present

```sh
grep -n 'tailscale-ap-mode' /usr/bin/gl_tailscale
```

### Check the daemon

```sh
ps w | grep '[t]ailscaled'
tailscale status
```

### Reapply after a firmware change

```sh
tailscale-ap-mode apply
/usr/bin/gl_tailscale restart
```

### Restore stock behavior

```sh
tailscale-ap-mode restore
```

## Safety design

The helper validates the patched vendor script with `sh -n` before replacing `/usr/bin/gl_tailscale`. If it cannot identify GL.iNet's `sys_mode` assignment or the resulting shell script is invalid, it refuses to install the modified file.

The patch is tagged with `# tailscale-ap-mode`, making it easy to detect and remove.

## License

MIT
