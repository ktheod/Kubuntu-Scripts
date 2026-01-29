#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys


def try_import_qt():
    try:
        from PyQt6 import QtGui, QtWidgets
        return QtGui, QtWidgets
    except Exception:
        pass
    try:
        from PyQt5 import QtGui, QtWidgets
        return QtGui, QtWidgets
    except Exception:
        return None, None


def main():
    QtGui, QtWidgets = try_import_qt()
    if QtGui is None:
        print("PyQt not available. Install: sudo apt install python3-pyqt5")
        return 1

    parser = argparse.ArgumentParser()
    parser.add_argument("--icon", default="", help="Path to tray icon png")
    parser.add_argument("--script", required=True, help="Path to my-bg-music.sh")
    args = parser.parse_args()

    app = QtWidgets.QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    if args.icon and os.path.isfile(args.icon):
        icon = QtGui.QIcon(args.icon)
    else:
        icon = QtGui.QIcon.fromTheme("media-playback-start")

    tray = QtWidgets.QSystemTrayIcon(icon)
    tray.setToolTip("Background Music")

    menu = QtWidgets.QMenu()

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

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
