-- system-health.sh --

A safe system health check for Kubuntu / KDE / Wayland.

Checks:

- dpkg integrity
- APT dependency consistency
- held packages
- leftover config states (rc)
- available updates
- failed systemd units
- disk usage
- KDE / Wayland session status
- KWin compositor
- PipeWire audio
- XWayland availability

Supported options:
--fix        Attempt safe dependency repair (apt -f install)
--purge-rc   Remove leftover removed-package configs
-v, --verbose
-h, --help

Note: The script does NOT run autoremove or upgrades automatically.
