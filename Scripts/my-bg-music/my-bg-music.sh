#!/bin/bash

# Instructions
# sudo apt install mpg123 pulseaudio-utils yad python3-pyqt5
#
# Make it executable:
# chmod +x ~/Scripts/my-bg-music.sh
#
# Set to Autostart

# --- CLI / IPC files ---
PID_FILE="/tmp/my-bg-music.pid"
STATE_FILE="/tmp/my-bg-music.state"
TRAY_PID_FILE="/tmp/my-bg-music.tray.pid"

# --- CLI mode: pause|resume|next|tray-quit|status ---
cmd="${1:-}"
if [[ -n "$cmd" ]]; then
  if [[ ! -f "$PID_FILE" ]]; then
    echo "my-bg-music: not running"
    exit 1
  fi

  pid="$(cat "$PID_FILE" 2>/dev/null)"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    echo "my-bg-music: not running (stale pidfile)"
    rm -f "$PID_FILE" "$STATE_FILE"
    exit 1
  fi

  case "$cmd" in
    pause)
      echo "Tray action: pause"
      kill -USR1 "$pid"
      exit 0
      ;;
    resume)
      echo "Tray action: resume"
      kill -USR2 "$pid"
      exit 0
      ;;
    next)
      if pgrep -x "mpg123" >/dev/null; then
        echo "Tray action: next"
        pkill -INT -x "mpg123"
        exit 0
      fi
      echo "mpg123 not running"
      exit 1
      ;;
    tray-quit)
      if [[ -f "$TRAY_PID_FILE" ]]; then
        echo "Tray action: quit"
        tray_pid="$(cat "$TRAY_PID_FILE" 2>/dev/null)"
        if [[ -n "$tray_pid" ]] && kill -0 "$tray_pid" 2>/dev/null; then
          kill "$tray_pid" 2>/dev/null || true
        fi
        rm -f "$TRAY_PID_FILE" 2>/dev/null || true
        exit 0
      fi
      echo "tray not running"
      exit 1
      ;;
    status)
      # read state if present
      if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
      else
        echo "running pid=$pid"
      fi
      exit 0
      ;;
    *)
      echo "Usage: $0 {pause|resume|next|tray-quit|status}"
      exit 2
      ;;
  esac
fi


# --- Single instance guard (prevents multiple scripts fighting) ---
LOCK_FILE="/tmp/my-bg-music.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "my-bg-music: already running"
  exit 0
fi

# --- Daemon bookkeeping ---
echo "$$" > "$PID_FILE"

cleanup() {
  rm -f "$PID_FILE" 2>/dev/null || true
  # keep STATE_FILE if you want; I usually remove it too:
  rm -f "$STATE_FILE" 2>/dev/null || true
  if [[ -f "$TRAY_PID_FILE" ]]; then
    tray_pid="$(cat "$TRAY_PID_FILE" 2>/dev/null)"
    if [[ -n "$tray_pid" ]] && kill -0 "$tray_pid" 2>/dev/null; then
      kill "$tray_pid" 2>/dev/null || true
    fi
    rm -f "$TRAY_PID_FILE" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM


# --- Glob handling (include .MP3, avoid literal *.mp3 when no matches) ---
shopt -s nullglob nocaseglob

# --- Configuration ---
STREAM_NAME="Background Music"
# Directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Directory to search for mp3 files (change this as needed)
MP3_SUBDIR="Background Music"
MUSIC_DIR="$SCRIPT_DIR/$MP3_SUBDIR"
VOLUME_PERCENT=37  # 0-100
SHOW_TRAY=1        # 1 = show tray icon, 0 = disable tray icon

# Fade config
FADE_SECONDS=10
FADE_STEPS=10

# Resume background music only after other audio has been silent for X seconds
RESUME_DELAY_SECONDS=30   # ← change this to whatever you want

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ICON_PLAY_PATH="$SCRIPT_DIR/my-bg-music.png"
ICON_PAUSE_PATH="$SCRIPT_DIR/my-bg-music-pause.png"
ICON_PATH="$ICON_PLAY_PATH"
TRAY_HELPER="$SCRIPT_DIR/my-bg-music-tray.py"

SCALE=$((32768 * VOLUME_PERCENT / 100))

# Simple self-action ignore (volume changes + STOP/CONT generate sink-input events)
IGNORE_UNTIL=0
IGNORE_SECONDS=2
ignore_events() { IGNORE_UNTIL=$(( $(date +%s) + IGNORE_SECONDS )); }
should_ignore() { (( $(date +%s) < IGNORE_UNTIL )); }

# --- State / locking ---
PAUSED_BY_US=0   # 1 = we paused mpg123, 0 = we consider it playing
FADE_LOCK=0      # 1 = fade in progress
OTHER_AUDIO_LAST_SEEN=0
MANUAL_PAUSE=0   # 1 = user forced pause; do not auto-resume


lock_fade()   { FADE_LOCK=1; }
unlock_fade() { FADE_LOCK=0; }
fade_busy()   { [ "$FADE_LOCK" -eq 1 ]; }

wait_for_pactl() {
  for _ in {1..100}; do
    pactl info >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}

start_tray() {
  if [[ "$SHOW_TRAY" -ne 1 ]]; then
    return 0
  fi

  if [[ -f "$TRAY_PID_FILE" ]]; then
    tray_pid="$(cat "$TRAY_PID_FILE" 2>/dev/null)"
    if [[ -n "$tray_pid" ]] && kill -0 "$tray_pid" 2>/dev/null; then
      return 0
    fi
  fi

  local script_path
  script_path="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"

  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    if [[ -x "$TRAY_HELPER" ]]; then
      "$TRAY_HELPER" --icon "$ICON_PLAY_PATH" --icon-pause "$ICON_PAUSE_PATH" --script "$script_path" &
      echo "$!" > "$TRAY_PID_FILE"
      echo "Tray shown"
      return 0
    fi
    return 0
  fi

  command -v yad >/dev/null 2>&1 || return 0
  [[ -n "${DISPLAY:-}" ]] || return 0

  local icon_arg
  if [[ -n "$ICON_PATH" ]] && [[ -f "$ICON_PATH" ]]; then
    icon_arg="--image=$ICON_PATH"
  else
    icon_arg="--image=media-playback-start"
  fi

  yad --notification \
    $icon_arg \
    --text="Background Music" \
    --menu="Pause!$script_path pause|Resume!$script_path resume|Next song!$script_path next|Quit tray!$script_path tray-quit" &

  echo "$!" > "$TRAY_PID_FILE"
  echo "Tray shown"
}

# Return FIRST sink-input id for mpg123
get_mpg123_sink_id() {
  pactl list sink-inputs 2>/dev/null | awk -v stream="$STREAM_NAME" '
    BEGIN { RS="Sink Input #"; FS="\n" }
    NR>1 {
      id=$1
      app=""
      bin=""
      for (i=1; i<=NF; i++) {
        if ($i ~ /^[[:space:]]*application.name = /) app=$i
        if ($i ~ /^[[:space:]]*application.process.binary = /) bin=$i
      }
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
      gsub(/.*application.name = /, "", app); gsub(/"/, "", app)
      gsub(/.*application.process.binary = /, "", bin); gsub(/"/, "", bin)

      if (app=="mpg123" || app==stream || bin=="mpg123.bin") { print id; exit }
    }
  '
}

wait_for_mpg123_sink() {
  for _ in {1..50}; do
    sid="$(get_mpg123_sink_id)"
    [ -n "$sid" ] && { echo "$sid"; return 0; }
    sleep 0.1
  done
  return 1
}

set_sink_input_vol_percent() {
  local sid="$1"
  local pct="$2"

  [ -z "$sid" ] && sid="$(get_mpg123_sink_id)"
  [ -z "$sid" ] && return 0

  pactl set-sink-input-volume "$sid" "${pct}%" >/dev/null 2>&1 && return 0

  # If PipeWire recreated the stream, re-resolve and try once more
  sid="$(get_mpg123_sink_id)"
  [ -z "$sid" ] && return 0
  pactl set-sink-input-volume "$sid" "${pct}%" >/dev/null 2>&1 || true
}

set_stream_icon() {
  local icon_path="$1"
  local sid="${2:-}"

  [ -z "$sid" ] && sid="$(get_mpg123_sink_id)"
  [ -z "$sid" ] && return 0

  pactl set-sink-input-properties "$sid" \
    "application.icon_name=$icon_path" \
    "media.icon_name=$icon_path" >/dev/null 2>&1 || true
}

lock_volume_for_startup() {
  # For ~3 seconds, keep re-applying the target volume (stream-restore race)
  local i
  for i in {1..15}; do
    set_sink_input_vol_percent "" "$VOLUME_PERCENT"
    sleep 0.2
  done
}

wait_for_mpg123_sink_quick() {
  # wait up to ~3 seconds for mpg123 sink-input to appear/reappear
  local sid
  for _ in {1..30}; do
    sid="$(get_mpg123_sink_id)"
    [ -n "$sid" ] && { echo "$sid"; return 0; }
    sleep 0.1
  done
  return 1
}

fade_to() {
  local target="$1"   # 0..VOLUME_PERCENT
  local sid="${2:-}"
  local sleep_s i pct

  [ -z "$sid" ] && sid="$(get_mpg123_sink_id)"
  [ -z "$sid" ] && return 0

  sleep_s=$(LC_ALL=C awk -v s="$FADE_SECONDS" -v n="$FADE_STEPS" 'BEGIN{printf "%.3f", s/n}')

  if [ "$target" -gt 0 ]; then
    set_sink_input_vol_percent "$sid" 0
    sleep "$sleep_s"

    echo "Fade in"

    for ((i=1; i<=FADE_STEPS; i++)); do
      sid="$(get_mpg123_sink_id)"
      [ -z "$sid" ] && { sleep "$sleep_s"; continue; }
      pct=$(( target * i / FADE_STEPS ))
      set_sink_input_vol_percent "$sid" "$pct"
      sleep "$sleep_s"
    done
  else
    echo "Fade out"

    for ((i=FADE_STEPS-1; i>=0; i--)); do
      sid="$(get_mpg123_sink_id)"
      [ -z "$sid" ] && { sleep "$sleep_s"; continue; }
      pct=$(( VOLUME_PERCENT * i / FADE_STEPS ))
      set_sink_input_vol_percent "$sid" "$pct"
      sleep "$sleep_s"
    done

    sid="$(get_mpg123_sink_id)"
    [ -n "$sid" ] && set_sink_input_vol_percent "$sid" 0
  fi
}

start_music() {
  if pgrep -x "mpg123" >/dev/null; then
    return 0
  fi

  files=( "$MUSIC_DIR"/*.mp3 )
  if (( ${#files[@]} == 0 )); then
    echo "No mp3 files found in: $MUSIC_DIR"
    return 0
  fi

  echo "Found ${#files[@]} mp3 files. Starting shuffle playlist (repeat forever)."

  LOG_FILE="$HOME/.bg-music-nowplaying.log"
  : > "$LOG_FILE"

  (
    while true; do
      stdbuf -oL -eL env \
      "PULSE_PROP_application.name=$STREAM_NAME" \
      "PULSE_PROP_application.icon_name=$ICON_PLAY_PATH" \
      "PULSE_PROP_media.icon_name=$ICON_PLAY_PATH" \
      "PULSE_PROP_media.role=music" \
      mpg123 -Z -f "$SCALE" -- "${files[@]}" 2>&1 | \
      while IFS= read -r line; do
        echo "$line" >> "$LOG_FILE"

        if [[ "$line" == *".mp3"* ]] && ([[ "$line" == *"Playing"* ]] || [[ "$line" == *"Reader"* ]] || [[ "$line" == *@*"@"* ]]); then
          track="$(echo "$line" | sed -n 's/.*: \(.*\.mp3\).*/\1/p')"
          if [ -z "$track" ]; then
            track="$(echo "$line" | sed -n 's/.*\(\(\/[^"]*\)\.mp3\).*/\1.mp3/p')"
          fi
          if [ -z "$track" ]; then
            track="$(echo "$line" | sed -n 's/.*\([^ ]*\.mp3\).*/\1/p')"
          fi
          if [ -n "$track" ]; then
            msg="Now playing: $(basename "$track")"
            echo "$msg"
            echo "$msg" >> "$LOG_FILE"
          fi
        fi
      done
      sleep 0.2
    done
  ) &

  echo "Background music started at $VOLUME_PERCENT% volume."

  wait_for_pactl || return 0
  sid="$(wait_for_mpg123_sink)" || return 0

  # Start silent, fade up
  set_sink_input_vol_percent "$sid" 0
  sleep 0.2
  lock_fade
  fade_to "$VOLUME_PERCENT" "$sid"
  unlock_fade

  lock_volume_for_startup
  ignore_events

  PAUSED_BY_US=0
  set_stream_icon "$ICON_PLAY_PATH" "$sid"
  write_status
}

write_status

stop_music() {
  pgrep -x "mpg123" >/dev/null || return 0
  [ "$PAUSED_BY_US" -eq 1 ] && return 0
  fade_busy && return 0

  lock_fade
  fade_to 0
  set_stream_icon "$ICON_PAUSE_PATH"
  pkill -STOP -x "mpg123"
  unlock_fade

  PAUSED_BY_US=1
  write_status
  echo "Background music paused."
  ignore_events
}

resume_music() {
  pgrep -x "mpg123" >/dev/null || return 0
  [ "$PAUSED_BY_US" -eq 0 ] && return 0
  fade_busy && return 0

  pkill -CONT -x "mpg123"

  # Wait until PipeWire recreates the sink-input (fixes "resumed but volume 0")
  sid="$(wait_for_mpg123_sink_quick)" || {
    # If it still hasn't appeared, we'll just try again next loop
    echo "Background music resumed (sink not ready yet, will fade when ready)."
    ignore_events
    return 0
  }

  echo "Background music resumed."
  ignore_events

  lock_fade
  # Start from 0 then fade up (using the *fresh* sid)
  set_sink_input_vol_percent "$sid" 0
  set_stream_icon "$ICON_PLAY_PATH" "$sid"
  sleep 0.1
  fade_to "$VOLUME_PERCENT" "$sid"
  unlock_fade

  PAUSED_BY_US=0
  write_status
}

write_status() {
  local state="playing"
  [[ "$PAUSED_BY_US" -eq 1 ]] && state="paused"
  echo "running pid=$$ state=$state volume=${VOLUME_PERCENT}% resume_delay=${RESUME_DELAY_SECONDS}s" > "$STATE_FILE"
}

manual_pause() {
  MANUAL_PAUSE=1
  stop_music
  write_status
}

manual_resume() {
  MANUAL_PAUSE=0
  # reset last seen so we don't immediately re-pause/resume weirdly
  OTHER_AUDIO_LAST_SEEN=0
  resume_music
  write_status
}

trap manual_pause USR1
trap manual_resume USR2



# TRUE if there is any OTHER active audio stream (ignores system sounds + muted)
other_audio_active() {
  pactl list sink-inputs 2>/dev/null | awk -v stream="$STREAM_NAME" '
    function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }

    BEGIN { RS="Sink Input #"; FS="\n"; other=0 }
    NR>1 {
      corked=""; app=""; mute=""; role=""; evid=""; mfile=""; bin=""
      for (i=1; i<=NF; i++) {
        if ($i ~ /^[[:space:]]*Corked:/) corked=$i
        if ($i ~ /^[[:space:]]*Mute:/)   mute=$i
        if ($i ~ /^[[:space:]]*application.name = /) app=$i
        if ($i ~ /^[[:space:]]*application.process.binary = /) bin=$i
        if ($i ~ /^[[:space:]]*media.role = /) role=$i
        if ($i ~ /^[[:space:]]*event.id = /) evid=$i
        if ($i ~ /^[[:space:]]*media.filename = /) mfile=$i
      }

      gsub(/.*Corked:[[:space:]]*/, "", corked)
      gsub(/.*Mute:[[:space:]]*/, "", mute)
      gsub(/.*application.name = /, "", app)
      gsub(/.*application.process.binary = /, "", bin)
      gsub(/.*media.role = /, "", role)
      gsub(/.*event.id = /, "", evid)
      gsub(/.*media.filename = /, "", mfile)

      gsub(/"/, "", app);   gsub(/\r/, "", app);   app=trim(app)
      gsub(/"/, "", bin);   gsub(/\r/, "", bin);   bin=trim(bin)
      gsub(/"/, "", role);  gsub(/\r/, "", role);  role=trim(role)
      gsub(/"/, "", evid);  gsub(/\r/, "", evid);  evid=trim(evid)
      gsub(/"/, "", mfile); gsub(/\r/, "", mfile); mfile=trim(mfile)

      # ignore system sounds
      if (role=="event" || role=="notification") next
      if (evid!="") next
      if (mfile ~ /^\/usr\/share\/sounds\//) next

      # Active other audio = corked no, not OUR bg music, not muted
      if (corked=="no") {
        if (mute!="no") next
        if (app=="mpg123" || app==stream || bin=="mpg123.bin") next
        other=1
      }
    }
    END { exit(other ? 0 : 1) }
  '
}

reconcile_audio_state() {
  # Ignore reactions during our own volume/STOP/CONT actions
  if should_ignore; then
    return 0
  fi

  #If user manually paused, never auto-resume
  if [ "$MANUAL_PAUSE" -eq 1 ]; then
    # still allow auto-pausing logic? (doesn't matter; we're already paused)
    return 0
  fi

  now=$(date +%s)

  if other_audio_active; then
    # Remember the last moment other audio was active
    OTHER_AUDIO_LAST_SEEN="$now"
    stop_music
  else
    # No other audio right now
    # Resume only if enough time has passed
    if [ "$PAUSED_BY_US" -eq 1 ]; then
      if [ "$OTHER_AUDIO_LAST_SEEN" -eq 0 ] || \
         [ $((now - OTHER_AUDIO_LAST_SEEN)) -ge "$RESUME_DELAY_SECONDS" ]; then
        resume_music
      fi
    fi
  fi
}

# --- Start after login ---
sleep 8
start_music
start_tray

# --- Main polling loop (robust: never misses VLC stop/start edge cases) ---
while true; do
  # Restart if mpg123 dies
  if ! pgrep -x "mpg123" >/dev/null; then
    start_music
    ignore_events
    sleep 1
    continue
  fi

  reconcile_audio_state
  sleep 0.5
done
