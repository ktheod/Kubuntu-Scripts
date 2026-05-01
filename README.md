# ~/My Scripts – Personal Utility Scripts

This directory contains personal utility scripts and a central script runner.

Scripts are organized into:

```text
~/My Scripts/
├── my-scripts.sh
├── README.md
└── Local Scripts/
    ├── system/
    │   ├── my-installed-packages.sh
    │   ├── my-system-health.sh
    │   └── my-system-update.sh
    └── my-bg-music/
        └── my-bg-music.sh
```

---

## Purpose

The main entry point is:

```bash
my-scripts.sh
```

It acts as a central launcher for all scripts inside:

```bash
~/My Scripts/Local Scripts/
```

Features:

* List available scripts
* Run scripts by name
* Automatic subfolder lookup
* Prefix support (`my-`)
* Optional sudo execution
* Argument forwarding

---

## PATH Configuration

Add your scripts folder to the end of your `$PATH`:

Edit:

```bash
nano ~/.bashrc
```

Add:

```bash
export PATH="$PATH:$HOME/My Scripts"
```

Reload:

```bash
source ~/.bashrc
```

This ensures:

* System commands always take priority
* Personal scripts remain accessible
* No command shadowing

Check:

```bash
type -a my-scripts.sh
```

---

## Usage

### List all available scripts

```bash
my-scripts.sh
```

or:

```bash
my-scripts.sh --list
```

Example output:

```text
Available scripts in: ~/My Scripts/Local Scripts
  system/my-installed-packages.sh
  system/my-system-health.sh
  system/my-system-update.sh
  my-bg-music/my-bg-music.sh
```

---

## Run scripts

Subfolder names are **not required**.

The script runner automatically searches all supported subfolders.

### System health

```bash
my-scripts.sh system-health
```

or:

```bash
my-scripts.sh my-system-health
```

Automatically resolves to:

```bash
system/my-system-health.sh
```

---

### System update

```bash
my-scripts.sh system-update
```

or:

```bash
my-scripts.sh my-system-update
```

Automatically resolves to:

```bash
system/my-system-update.sh
```

With sudo:

```bash
my-scripts.sh --sudo system-update
```

Short form:

```bash
my-scripts.sh -s system-update
```

---

### Installed packages

```bash
my-scripts.sh installed-packages
```

or:

```bash
my-scripts.sh my-installed-packages
```

Automatically resolves to:

```bash
system/my-installed-packages.sh
```

---

### Background music

```bash
my-scripts.sh bg-music
```

or:

```bash
my-scripts.sh my-bg-music
```

Automatically resolves to:

```bash
my-bg-music/my-bg-music.sh
```

---

## Prefix Support

Scripts use the prefix:

```bash
my-
```

Examples:

```bash
my-system-health.sh
my-system-update.sh
my-installed-packages.sh
my-bg-music.sh
```

The runner automatically tries:

```bash
system-update.sh
my-system-update.sh
```

So both work:

```bash
my-scripts.sh system-update
```

and:

```bash
my-scripts.sh my-system-update
```

---

## Pass arguments

Arguments after the script name are forwarded:

```bash
my-scripts.sh system-update --checkonly
```

With sudo:

```bash
my-scripts.sh --sudo system-update --checkonly
```

---

## Make scripts executable

Make all scripts executable:

```bash
find ~/My\ Scripts -type f -name "*.sh" -exec chmod +x {} \;
```

Or only the runner:

```bash
chmod +x ~/My\ Scripts/my-scripts.sh
```

---

## Design Principles

* Safety first
* Predictable behavior
* System commands always win
* Centralized script execution
* Easy script discovery
* Minimal maintenance

---

## Notes

* Subfolder names are optional when running scripts
* The runner searches `Local Scripts` and one subfolder level deep
* Prefix `my-` is recommended
* Use sudo only when required
* If multiple scripts match, execution stops and lists all matches
