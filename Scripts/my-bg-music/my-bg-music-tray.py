#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys


def try_import_qt():
    try:
        from PyQt6 import QtCore, QtGui, QtWidgets
        return QtCore, QtGui, QtWidgets
    except Exception:
        pass
    try:
        from PyQt5 import QtCore, QtGui, QtWidgets
        return QtCore, QtGui, QtWidgets
    except Exception:
        return None, None, None


def main():
    QtCore, QtGui, QtWidgets = try_import_qt()
    if QtGui is None:
        print("PyQt not available. Install: sudo apt install python3-pyqt5")
        return 1

    parser = argparse.ArgumentParser()
    parser.add_argument("--icon", default="", help="Path to tray icon png (play)")
    parser.add_argument("--icon-pause", default="", help="Path to tray icon png (pause)")
    parser.add_argument("--script", required=True, help="Path to my-bg-music.sh")
    args = parser.parse_args()

    app = QtWidgets.QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    icon_play = args.icon if args.icon and os.path.isfile(args.icon) else ""
    icon_pause = args.icon_pause if args.icon_pause and os.path.isfile(args.icon_pause) else ""

    if icon_play:
        icon = QtGui.QIcon(icon_play)
    else:
        icon = QtGui.QIcon.fromTheme("media-playback-start")

    tray = QtWidgets.QSystemTrayIcon(icon)
    tray.setToolTip("Background Music")

    menu = QtWidgets.QMenu()
    now_playing_log = os.path.expanduser("~/.bg-music-nowplaying.log")
    state_file = "/tmp/my-bg-music.state"

    def run_cmd(cmd):
        try:
            subprocess.Popen([args.script, cmd])
        except Exception:
            pass

    act_pause = menu.addAction("Pause")
    act_pause.setIcon(QtGui.QIcon.fromTheme("media-playback-pause"))
    act_pause.triggered.connect(lambda: run_cmd("pause"))

    act_resume = menu.addAction("Resume")
    act_resume.setIcon(QtGui.QIcon.fromTheme("media-playback-start"))
    act_resume.triggered.connect(lambda: run_cmd("resume"))

    act_next = menu.addAction("Next song")
    act_next.setIcon(QtGui.QIcon.fromTheme("media-skip-forward"))
    act_next.triggered.connect(lambda: run_cmd("next"))

    menu.addSeparator()

    act_quit = menu.addAction("Quit tray")
    act_quit.setIcon(QtGui.QIcon.fromTheme("application-exit"))
    act_quit.triggered.connect(app.quit)

    tray.setContextMenu(menu)
    tray.show()

    def update_tooltip():
        track = ""
        try:
            with open(now_playing_log, "r", encoding="utf-8", errors="ignore") as f:
                lines = f.readlines()
            for line in reversed(lines):
                line = line.strip()
                if line.startswith("Now playing: "):
                    track = line[len("Now playing: "):]
                    break
        except Exception:
            track = ""

        state = ""
        try:
            with open(state_file, "r", encoding="utf-8", errors="ignore") as f:
                state_line = f.read().strip()
            if "state=paused" in state_line:
                state = "paused"
            elif "state=playing" in state_line:
                state = "playing"
        except Exception:
            state = ""

        if state == "paused" and icon_pause:
            tray.setIcon(QtGui.QIcon(icon_pause))
        elif state == "playing" and icon_play:
            tray.setIcon(QtGui.QIcon(icon_play))

        if track:
            track_no_ext = os.path.splitext(track)[0]
            tray.setToolTip(f"Background Music\nNow Playing: {track_no_ext}")
        else:
            tray.setToolTip("Background Music")

    update_tooltip()
    timer = QtCore.QTimer()
    timer.timeout.connect(update_tooltip)
    timer.start(2000)

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
