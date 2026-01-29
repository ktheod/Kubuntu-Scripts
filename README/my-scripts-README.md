# Script Runner (`my-` prefix aware)

A small Bash **script runner / dispatcher** that lives next to your scripts and lets you:

- List all available `.sh` scripts in a configurable scripts folder
- Include scripts in **one subfolder level**
- Run any script by name
- Automatically resolve scripts with a configurable prefix (`my-`)
- Pass arguments transparently to the target script

Think of it as a **local command launcher** for your personal scripts.

---

## What this script does

When you run this script, it:

1. Detects the directory it lives in
2. Builds a **search directory** from `SCRIPT_DIR + SCRIPTS_SUBDIR`
3. Lists or executes `.sh` scripts **from that directory and one subfolder deep**
4. Supports a **prefix fallback**:
   - If you run `backup`, it will try:
     - `backup.sh`
     - `my-backup.sh`
5. Executes scripts even if they are **not marked executable**
6. Passes all remaining arguments to the target script unchanged

---

## Requirements

- Bash 4+
- Linux / Unix-like shell
- Scripts must be located in the configured scripts directory, up to **one subfolder deep**

No external dependencies.

---

## Configuration

Edit these variables at the top of the script:

```bash
SCRIPTS_SUBDIR="Local Scripts"
SCRIPTS_DIR="$SCRIPT_DIR/$SCRIPTS_SUBDIR"
PREFIX="my-"
```

- **SCRIPTS_SUBDIR**: folder name under the script’s directory where your scripts live
- **SCRIPTS_DIR**: full path built from `SCRIPT_DIR + SCRIPTS_SUBDIR`
- **PREFIX**: optional prefix fallback used when resolving script names

---

## Installation

1. Save this script in a directory with your other scripts, e.g.:

```bash
~/Scripts/my-scripts.sh
~/Scripts/Local Scripts/my-backup.sh
~/Scripts/Local Scripts/cleanup.sh
```

Make it executable:

```bash
chmod +x my-scripts.sh
```

(Optional) Add `~/Scripts` to your PATH so you can run it from anywhere.

---

## Usage

```bash
my-scripts.sh
my-scripts.sh --list
my-scripts.sh <script> [arguments...]
```

### No arguments

```bash
my-scripts.sh
```

Lists all `.sh` scripts in the scripts folder (including one subfolder level), excluding itself.

### Listing scripts

```bash
my-scripts.sh --list
```

or

```bash
my-scripts.sh list
```

### Running a script

```bash
my-scripts.sh backup
```

Resolution order:

- `backup.sh`
- `my-backup.sh`

If found, it is executed with any extra arguments.

### Running a script in a subfolder

```bash
my-scripts.sh tools/backup
```

If you include a subfolder, it is resolved relative to `SCRIPTS_DIR`.

---

## Prefix support (`my-`)

The script uses this prefix internally:

```bash
PREFIX="my-"
```

If the requested script name does not start with `my-`, the runner will automatically try both:

- `<script>.sh`
- `my-<script>.sh`

Examples:

```bash
my-scripts.sh backup
my-scripts.sh my-backup
my-scripts.sh backup --full --dry-run
```

All arguments after the script name are forwarded as-is.

---

## Executable vs non-executable scripts

- If the target script is executable, it is run directly
- If it is not executable, it is run via `bash`

So this works even if you forgot:

```bash
chmod +x my-script.sh
```

---

## Help

```bash
my-scripts.sh --help
```

Displays usage instructions and examples.

---

## Error handling

If a script cannot be found, the runner:

- Prints a clear error message
- Shows the list of available scripts

Uses:

```bash
set -euo pipefail
```

to fail fast and safely.

---

## Typical use case

This is ideal if you:

- Keep many personal scripts in one folder
- Want short, memorable command names
- Prefer `my-` prefixed scripts without typing the prefix every time
- Don’t want to clutter `/usr/local/bin`
