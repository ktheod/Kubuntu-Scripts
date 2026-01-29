# list-installed.sh

A small Bash utility that prints a “what I installed” inventory for Debian/Ubuntu-based systems:

- **APT**: user-installed (manually installed) packages, **excluding the OS installer baseline** when available.
- Optional **APT details**: direct installed dependencies (Depends/PreDepends) of those packages.
- Optional **Flatpak** and **Snap** inventories.

Designed for Kubuntu/Ubuntu/Debian systems where `apt-mark`, `dpkg-query`, and `apt-cache` are available.

---

## What it prints

### 1) APT user-installed packages (baseline-subtracted)
It attempts to subtract the packages present at initial OS install time using:

- `/var/log/installer/initial-status.gz` (if present)

If that file exists, it outputs:

- Packages marked as “manual” (from `apt-mark showmanual`)
- **Minus** packages listed in the installer baseline

If the file **does not** exist, it falls back to:

- `apt-mark showmanual` (no baseline subtraction)

Output is shown as a table with:
- Package
- Version
- Architecture
- Summary

### 2) Optional: direct dependencies (installed only)
With `--details`, it additionally lists the direct `Depends` and `PreDepends` of the above packages:
- Only those dependencies that are **currently installed**
- Excludes packages that are already in the user-installed list

### 3) Optional: Flatpak + Snap
By default, it prints:
- `flatpak list` (if `flatpak` exists)
- `snap list` (if `snap` exists)

You can disable each section with flags.

---

## Requirements

### APT section (required)
- Bash 4+
- `apt-mark`
- `dpkg-query`
- `apt-cache`
- `gzip`, `sed`, `awk`, `sort`, `comm`, `xargs`, `column`

### Flatpak section (optional)
- `flatpak` (only if you want Flatpak output)

### Snap section (optional)
- `snap` (only if you want Snap output)

---

## Installation

1. Save the script as `list-installed.sh`
2. Make it executable:

```bash
chmod +x list-installed.sh

3.Run it:

./list-installed.sh


Tip: if you want to run it from anywhere, move it into a folder on your PATH, e.g.:

mkdir -p ~/Scripts
mv list-installed.sh ~/Scripts/

Usage
./list-installed.sh [--details] [--no-flatpak] [--no-snap]

Options

--details
Also list direct dependencies (Depends/PreDepends) of the user-installed packages (installed only).

--no-flatpak
Skip the Flatpak section.

--no-snap
Skip the Snap section.

-h, --help
Show help.

Examples
Default output (APT + Flatpak + Snap)
./list-installed.sh

APT only
./list-installed.sh --no-flatpak --no-snap

APT + dependency details, but no Flatpak
./list-installed.sh --details --no-flatpak

Notes & behavior

If /var/log/installer/initial-status.gz is missing, the script will print a warning and fall back to apt-mark showmanual without baseline subtraction.

The dependency list is direct only (not recursive), and includes only installed packages.

Output formatting uses column, so results look best in a reasonably wide terminal.

The script uses temporary files via mktemp and cleans them up automatically via traps.
