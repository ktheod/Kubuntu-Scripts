#!/usr/bin/env bash
set -euo pipefail

BEFORE_DESC="All Working - Before System Update & Upgrade"
AFTER_DESC="All Working - After System Update & Upgrade"

CHECK_ONLY=false

if [[ "${1:-}" == "--checkonly" ]]; then
    CHECK_ONLY=true
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--checkonly]"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root:"
    echo "sudo $0"
    exit 1
fi

command -v apt-get >/dev/null || {
    echo "apt-get not found."
    exit 1
}

command -v timeshift >/dev/null || {
    echo "Timeshift is not installed."
    echo "Install it with: sudo apt install timeshift"
    exit 1
}

echo "Updating package lists..."
apt-get update

echo
echo "Checking for available updates..."
UPDATES="$(apt list --upgradable 2>/dev/null | sed '1d')"

if [[ -z "$UPDATES" ]]; then
    echo "No system updates or upgrades available."
    exit 0
fi

echo
echo "Available updates:"
echo "$UPDATES"

if [[ "$CHECK_ONLY" == true ]]; then
    echo
    echo "--checkonly used. Exiting without snapshots or upgrades."
    exit 0
fi

echo
read -rp "Proceed with Timeshift snapshots and system upgrade? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo
echo "Creating BEFORE Timeshift snapshot..."
timeshift --create --comments "$BEFORE_DESC" --tags D

echo
echo "Installing updates and system upgrades..."
apt-get -y upgrade
apt-get -y full-upgrade

echo
echo "Cleaning unused packages..."
apt-get -y autoremove
apt-get autoclean

echo
echo "Creating AFTER Timeshift snapshot..."
timeshift --create --comments "$AFTER_DESC" --tags D

echo
echo "Done."
echo "Before snapshot: $BEFORE_DESC"
echo "After snapshot:  $AFTER_DESC"