#!/usr/bin/env bash
set -euo pipefail

# --------- formatting ----------
if [[ -t 1 ]]; then
  BOLD="$(tput bold)"; DIM="$(tput dim)"; RED="$(tput setaf 1)"; GRN="$(tput setaf 2)"
  YEL="$(tput setaf 3)"; BLU="$(tput setaf 4)"; RST="$(tput sgr0)"
else
  BOLD=""; DIM=""; RED=""; GRN=""; YEL=""; BLU=""; RST=""
fi

ok()   { echo "${GRN}✔${RST} $*"; }
warn() { echo "${YEL}⚠${RST} $*"; }
bad()  { echo "${RED}✘${RST} $*"; }
info() { echo "${BLU}ℹ${RST} $*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || { bad "Missing command: $1"; exit 1; }; }

# --------- args ----------
DO_FIX=0
DO_RC_PURGE=0
VERBOSE=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --fix          Run safe repair steps (apt -f install) if needed
  --purge-rc     Purge leftover removed-package configs (dpkg 'rc' state)
  -v, --verbose  More output
  -h, --help     Show this help

This script does NOT run autoremove automatically.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix) DO_FIX=1; shift ;;
    --purge-rc) DO_RC_PURGE=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) bad "Unknown option: $1"; usage; exit 2 ;;
  esac
done

# --------- prerequisites ----------
need_cmd dpkg
need_cmd apt-get
need_cmd systemctl
need_cmd df
need_cmd awk
need_cmd grep
need_cmd sed
need_cmd loginctl
need_cmd pgrep
# qdbus is optional, so don't hard-require it
#need_cmd qdbus

echo "${BOLD}System health check${RST} on $(hostname)  (${DIM}$(date)${RST})"
echo

# --------- 1) dpkg audit ----------
echo "${BOLD}1) dpkg integrity${RST}"
AUDIT_OUT="$(sudo dpkg --audit || true)"
if [[ -z "${AUDIT_OUT}" ]]; then
  ok "No dpkg audit issues found."
else
  bad "dpkg reports issues:"
  echo "$AUDIT_OUT" | sed 's/^/  /'
  if [[ $DO_FIX -eq 1 ]]; then
    warn "Attempting safe repair: sudo apt -f install"
    sudo apt -f install
    ok "Repair command finished. Re-run the script to confirm."
  else
    warn "Run with --fix to attempt safe repair (apt -f install)."
  fi
fi
echo

# --------- 2) apt dependency check ----------
echo "${BOLD}2) APT dependency sanity (apt-get check)${RST}"
if sudo apt-get check >/dev/null; then
  ok "apt-get check: OK"
else
  bad "apt-get check reported problems."
  warn "Try: sudo apt -f install"
fi
echo

# --------- 3) held packages ----------
echo "${BOLD}3) Held packages${RST}"
HELD="$(apt-mark showhold || true)"
if [[ -z "$HELD" ]]; then
  ok "No held packages."
else
  warn "Held packages found:"
  echo "$HELD" | sed 's/^/  /'
fi
echo

# --------- 4) partially-installed/unusual states ----------
echo "${BOLD}4) Package state anomalies${RST}"
# show anything not "ii" (installed OK); allow "rc" (removed, config remains)
ANOM="$(dpkg -l | awk 'NR>5 && $1 !~ /^(ii|rc)$/ {print $0}' || true)"
if [[ -z "$ANOM" ]]; then
  ok "No abnormal dpkg states (beyond optional rc configs)."
else
  bad "Abnormal package states detected:"
  echo "$ANOM" | sed 's/^/  /'
fi

RC_LIST="$(dpkg -l | awk 'NR>5 && $1=="rc"{print $2}' || true)"
if [[ -n "$RC_LIST" ]]; then
  warn "There are removed packages with leftover configs (rc)."
  if [[ $DO_RC_PURGE -eq 1 ]]; then
    warn "Purging rc configs…"
    # shellcheck disable=SC2086
    sudo apt-get purge -y $RC_LIST
    ok "Purged rc configs."
  else
    info "Run with --purge-rc to purge them."
    (( VERBOSE )) && echo "$RC_LIST" | sed 's/^/  /'
  fi
else
  ok "No leftover rc configs."
fi
echo

# --------- 5) updates available ----------
echo "${BOLD}5) Updates available${RST}"
# This is safe; it just refreshes package lists.
sudo apt-get update -qq
#sudo apt-get update --no-update
UPG="$(apt list --upgradable 2>/dev/null | tail -n +2 || true)"
if [[ -z "$UPG" ]]; then
  ok "No pending upgrades."
else
  warn "Upgrades available:"
  echo "$UPG" | sed 's/^/  /'
  info "Apply with: sudo apt full-upgrade"
fi
echo

# --------- 6) systemd failures ----------
echo "${BOLD}6) Failed systemd units${RST}"
FAILED="$(systemctl --failed --no-legend || true)"
if [[ -z "$FAILED" ]]; then
  ok "No failed systemd units."
else
  bad "Failed units:"
  echo "$FAILED" | sed 's/^/  /'
  info "Inspect one with: systemctl status <unit>"
fi
echo

# --------- 7) disk space ----------
echo "${BOLD}7) Disk usage (root filesystem)${RST}"
ROOT_LINE="$(df -h / | tail -n 1)"
USED_PCT="$(echo "$ROOT_LINE" | awk '{print $5}' | tr -d '%')"
echo "  $ROOT_LINE"
if [[ "$USED_PCT" -ge 95 ]]; then
  bad "Root filesystem is ${USED_PCT}% full (critical)."
elif [[ "$USED_PCT" -ge 85 ]]; then
  warn "Root filesystem is ${USED_PCT}% full."
else
  ok "Root filesystem usage is ${USED_PCT}%."
fi
echo

# --------- 8) KDE/Plasma sanity checks (non-fatal) ----------
echo "${BOLD}8) KDE/desktop quick checks${RST}"

# Session type (Wayland/X11)
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
if [[ "$SESSION_TYPE" == "wayland" ]]; then
  ok "Session type: Wayland"
elif [[ "$SESSION_TYPE" == "x11" ]]; then
  ok "Session type: X11"
else
  warn "Session type: unknown (XDG_SESSION_TYPE not set)"
fi

if pgrep -x Xwayland >/dev/null 2>&1; then
  info "XWayland is running (legacy X11 apps supported)."
else
  info "XWayland not running (only Wayland-native apps currently)."
fi

# Confirm via logind when possible
if [[ -n "${XDG_SESSION_ID:-}" ]]; then
  LT="$(loginctl show-session "$XDG_SESSION_ID" -p Type 2>/dev/null | awk -F= '{print $2}' || true)"
  [[ -n "$LT" ]] && info "loginctl session type: $LT"
fi

# Display manager
if systemctl is-active --quiet sddm; then
  ok "SDDM is active."
else
  warn "SDDM not active (can be normal on some setups)."
fi

# KWin process check (works on Wayland + X11)
if pgrep -x kwin_wayland >/dev/null 2>&1; then
  ok "KWin Wayland compositor running (kwin_wayland)."
elif pgrep -x kwin_x11 >/dev/null 2>&1; then
  ok "KWin X11 window manager running (kwin_x11)."
else
  warn "KWin process not detected (unexpected in a Plasma session)."
fi

# Audio server check (no extra deps beyond pipewire-pulse)
if command -v pactl >/dev/null 2>&1; then
  SERVER="$(pactl info 2>/dev/null | awk -F': ' '/Server Name/ {print $2}' || true)"
  [[ -n "$SERVER" ]] && ok "Audio server: $SERVER" || warn "Could not read audio server from pactl."
else
  info "pactl not found (skipping audio server check)."
fi

# KWin (Wayland compositor)
# if command -v qdbus >/dev/null 2>&1; then
#   if qdbus org.kde.KWin /KWin org.kde.KWin.supportInformation >/dev/null 2>&1; then
#     ok "KWin D-Bus reachable (compositor running)."
#   else
#     warn "KWin D-Bus not reachable (if you're in a GUI session, this is unexpected)."
#   fi
# else
#   info "qdbus not found (skipping KWin D-Bus check)."
# fi

# --------- summary ----------
echo "${BOLD}Done.${RST}"
info "Tip: This script avoids 'autoremove' on purpose. If you're cleaning, run:"
echo "  sudo apt autoremove --purge"
exit 0
