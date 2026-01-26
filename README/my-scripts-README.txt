# Script Runner (`my-` prefix aware)

A small Bash **script runner / dispatcher** that lives in a folder with other `.sh` scripts and lets you:

- List all available scripts in that folder
- Run any script by name
- Automatically resolve scripts with a configurable prefix (`my-`)
- Pass arguments transparently to the target script

Think of it as a **local command launcher** for your personal scripts.

---

## What this script does

When you run this script, it:

1. Detects the directory it lives in
2. Lists or executes `.sh` scripts **from that same directory**
3. Supports a **prefix fallback**:
   - If you run `backup`, it will try:
     - `backup.sh`
     - `my-backup.sh`
4. Executes scripts even if they are **not marked executable**
5. Passes all remaining arguments to the target script unchanged

---

## Requirements

- Bash 4+
- Linux / Unix-like shell
- Scripts must be located in the **same directory** as the runner

No external dependencies.

---

## Installation

1. Save this script in a directory with your other scripts, e.g.:

```bash
~/Scripts/run.sh
~/Scripts/my-backup.sh
~/Scripts/cleanup.sh

Make it executable:

chmod +x run.sh


(Optional) Add ~/Scripts to your PATH so you can run it from anywhere.

Usage
run.sh
run.sh --list
run.sh <script> [arguments...]

No arguments
run.sh


Lists all .sh scripts in the same directory (excluding itself).

Listing scripts
run.sh --list


or

run.sh list

Running a script
run.sh backup


Resolution order:

backup.sh

my-backup.sh

If found, it is executed with any extra arguments.

Prefix support (my-)

The script uses this prefix internally:

PREFIX="my-"


If the requested script name does not start with my-, the runner will automatically try both:

<script>.sh

my-<script>.sh

Examples
run.sh backup
run.sh my-backup
run.sh backup --full --dry-run


All arguments after the script name are forwarded as-is.

Executable vs non-executable scripts

If the target script is executable, it is run directly

If it is not executable, it is run via bash

So this works even if you forgot:

chmod +x my-script.sh

Help
run.sh --help


Displays usage instructions and examples.

Error handling

If a script cannot be found, the runner:

Prints a clear error message

Shows the list of available scripts

Uses:

set -euo pipefail


to fail fast and safely

Typical use case

This is ideal if you:

Keep many personal scripts in one folder

Want short, memorable command names

Prefer my- prefixed scripts without typing the prefix every time

Don’t want to clutter /usr/local/bin
