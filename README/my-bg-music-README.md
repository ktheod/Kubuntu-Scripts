🎵 my-bg-music.sh

A lightweight background music daemon for Linux (PipeWire / PulseAudio) that plays shuffled MP3s, automatically fades out when other media starts, and fades back in after silence — with full manual control.

Designed and tested on Kubuntu / Plasma, but should work on most modern Linux desktops.

✨ Features

🎶 Plays all MP3 files in a folder, shuffled, looping forever

🔊 Smooth fade-in / fade-out when pausing or resuming

🛑 Automatically pauses when other media plays (VLC, browser, etc.)

🔔 Ignores system sounds (notifications, error beeps)

⏱️ Configurable resume delay after other audio stops

🧠 Robust state handling (won’t get confused mid-fade)

🔐 Single-instance safe (prevents multiple scripts running)

🖥️ Simple CLI control: pause / resume / status

🧷 Optional tray icon with hover "Now Playing" tooltip

🔄 Auto-recovers if mpg123 crashes or restarts

📦 Requirements
sudo apt install mpg123 pulseaudio-utils
sudo apt install yad python3-pyqt5   # tray support (X11 or Wayland)


PipeWire is supported automatically via pipewire-pulse.

⚙️ Configuration

Edit these variables at the top of the script:

MP3_SUBDIR="Background Music"
MUSIC_DIR="$SCRIPT_DIR/$MP3_SUBDIR"
VOLUME_PERCENT=55
FADE_SECONDS=5
FADE_STEPS=20
RESUME_DELAY_SECONDS=10

Parameter explanation
Variable	Description
MP3_SUBDIR	Subfolder under the script folder that contains MP3 files
MUSIC_DIR	Full path to the MP3 folder (auto-built from SCRIPT_DIR + MP3_SUBDIR)
VOLUME_PERCENT	Target background music volume (0–100)
FADE_SECONDS	Total duration of fade in/out
FADE_STEPS	Number of volume steps during fade
RESUME_DELAY_SECONDS	Seconds of silence required before resuming music
▶️ Usage
Start (normally via autostart)
~/Scripts/my-bg-music.sh

CLI control
my-bg-music pause
my-bg-music resume
my-bg-music status


Manual pause overrides auto-resume until you explicitly resume.

🧠 Behavior Rules

Music pauses only if another real media stream plays

System sounds (notifications, error beeps) are ignored

Music resumes only after silence lasts RESUME_DELAY_SECONDS

Fade operations are atomic (no race conditions)

Script automatically restarts playback if mpg123 dies

🚀 Autostart Setup (KDE Plasma)

System Settings → Autostart

Add script: ~/Scripts/my-bg-music.sh

Set to Run on login

🧪 Logs

Currently playing track is logged to:

~/.bg-music-nowplaying.log


Useful for debugging or status checks.

🧷 Tray Icon (KDE/Plasma)

The script auto-starts a tray icon when a desktop session is active.

Hover the tray icon to see the current track (pulled from the now-playing log).

The stream icon in the KDE Audio Volume > Applications panel is set to:
PULSE_PROP_application.icon_name=audio-volume-high

🧯 Safety Notes

Uses a lock file: /tmp/my-bg-music.lock

Prevents multiple instances fighting for volume control

Safe to restart manually

💡 Future Ideas (Optional)

Tray icon toggle

Hotkeys (play / pause / next)

Per-application pause allow/deny list

systemd --user service mode

❤️ Credits

Built with:

mpg123

pactl

PipeWire / PulseAudio

A lot of real-world edge-case testing 😉

If you want, I can:

slim this down into a man-page style README

add inline comments inside the script

or convert it into a systemd user service

Just say the word 👍


### Show mpg123 as "Background Music" in volume control applet
mkdir -p ~/.config/pipewire/pipewire-pulse.conf.d
nano ~/.config/pipewire/pipewire-pulse.conf.d/99-bg-music.conf

<paste>

pulse.rules = [
  {
    matches = [
      { application.process.binary = "mpg123.bin" }
    ]
    actions = {
      update-props = {
        node.description = "Background Music"
        media.name = "Background Music"
        application.name = "Background Music"
      }
    }
  }
]


Restart PipeWire + pipewire-pulse (user services):
systemctl --user restart pipewire pipewire-pulse

Restart your bg music script (so the stream is recreated with the new props).

Verify what KDE will show
    Run this while music is playing:
    pactl list sink-inputs | grep -E "Sink Input #|application.name =|node.description =|media.name =|application.process.binary ="


You should see the mpg123 stream with:
    node.description = "Background Music" (this is the big one for Plasma)
    media.name = "Background Music"
