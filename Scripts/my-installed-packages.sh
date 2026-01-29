#!/usr/bin/env bash
set -euo pipefail

SHOW_DETAILS=false

usage() {
  cat <<'EOF'
Usage:
  list-installed.sh [--details] [--no-flatpak] [--no-snap]

Options:
  --details     Also list direct dependencies (Depends/PreDepends) of the user-installed packages.
  --no-flatpak  Skip flatpak list section.
  --no-snap     Skip snap list section.
  -h, --help    Show this help.
EOF
}

SHOW_FLATPAK=true
SHOW_SNAP=true

for arg in "${1:-}"; do :; done # no-op to avoid shellcheck complaints

while [[ $# -gt 0 ]]; do
  case "$1" in
    --details) SHOW_DETAILS=true; shift ;;
    --no-flatpak) SHOW_FLATPAK=false; shift ;;
    --no-snap) SHOW_SNAP=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

get_user_installed_packages() {
  if [[ -f /var/log/installer/initial-status.gz ]]; then
    comm -23 \
      <(apt-mark showmanual | sort -u) \
      <(gzip -dc /var/log/installer/initial-status.gz | sed -n 's/^Package: //p' | sort -u)
  else
    echo "WARNING: /var/log/installer/initial-status.gz not found." >&2
    echo "Falling back to: apt-mark showmanual (no baseline subtraction)." >&2
    apt-mark showmanual | sort -u
  fi
}

print_pkg_details_table() {
  # Reads package names from stdin and prints details.
  # (If you want less output, remove Summary.)
  xargs -r dpkg-query -W -f='${binary:Package}\t${Version}\t${Architecture}\t${binary:Summary}\n' \
  | column -ts $'\t'
}

get_installed_set() {
  # Prints installed package names
  dpkg-query -W -f='${binary:Package}\t${Status}\n' \
    | awk '$2=="install" && $3=="ok" && $4=="installed" {print $1}' \
    | sort -u
}

extract_direct_deps_installed() {
  # Input: list of package names (user-installed)
  # Output: unique list of installed direct Depends/PreDepends packages (excluding the originals)
  local tmp_user tmp_installed tmp_deps
  tmp_user="$(mktemp)"
  tmp_installed="$(mktemp)"
  tmp_deps="$(mktemp)"
  trap 'rm -f "$tmp_user" "$tmp_installed" "$tmp_deps"' RETURN

  cat >"$tmp_user"
  get_installed_set >"$tmp_installed"

  # For each package, get Depends/PreDepends lines, normalize, and collect candidates
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    apt-cache depends "$pkg" 2>/dev/null \
      | awk -F': ' '/^(  Depends|  PreDepends): / {print $2}' \
      | sed -E 's/[<>]//g' \
      | tr '|' '\n' \
      | sed -E 's/^\s+|\s+$//g' \
      | awk 'NF{print}'
  done <"$tmp_user" \
  | sort -u >"$tmp_deps"

  # Keep only installed deps, and exclude packages already in user list
  comm -12 "$tmp_deps" "$tmp_installed" | comm -23 - "$tmp_user"
}

USER_PKGS="$(mktemp)"
trap 'rm -f "$USER_PKGS"' EXIT

get_user_installed_packages > "$USER_PKGS"

echo "============================================================"
echo "APT user-installed packages (manual, excluding initial baseline)"
echo "============================================================"
if [[ ! -s "$USER_PKGS" ]]; then
  echo "(none found)"
else
  print_pkg_details_table < "$USER_PKGS"
fi

if $SHOW_DETAILS; then
  echo
  echo "============================================================"
  echo "Direct dependencies of the above (installed only)"
  echo "============================================================"
  if [[ ! -s "$USER_PKGS" ]]; then
    echo "(none)"
  else
    DEPS="$(mktemp)"
    trap 'rm -f "$DEPS"' RETURN
    extract_direct_deps_installed < "$USER_PKGS" > "$DEPS"

    if [[ ! -s "$DEPS" ]]; then
      echo "(no installed direct dependencies found)"
    else
      print_pkg_details_table < "$DEPS"
    fi
  fi
fi

if $SHOW_FLATPAK; then
  echo
  echo "============================================================"
  echo "Flatpak list"
  echo "============================================================"
  if command -v flatpak >/dev/null 2>&1; then
    flatpak list
  else
    echo "flatpak is not installed."
  fi
fi

if $SHOW_SNAP; then
  echo
  echo "============================================================"
  echo "Snap list"
  echo "============================================================"
  if command -v snap >/dev/null 2>&1; then
    snap list
  else
    echo "snap is not installed."
  fi
fi
