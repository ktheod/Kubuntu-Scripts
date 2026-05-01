# my-system-update.sh

System update automation script for Kubuntu/Linux using APT and Timeshift.

This script safely automates:

1. Checking for available package updates/upgrades
2. Creating a pre-update snapshot using Timeshift
3. Installing updates and upgrades
4. Creating a post-update snapshot

It is designed to reduce rollback risk during system maintenance.

---

## Purpose

The script helps automate regular system maintenance while preserving rollback points.

Workflow:

```text
Check updates
   ↓
Create Timeshift snapshot (Before Update)
   ↓
Install updates/upgrades
   ↓
Create Timeshift snapshot (After Update)
```

---

## Requirements

Required software:

* `apt`
* `sudo`
* Timeshift

Install Timeshift if needed:

```bash
sudo apt install timeshift
```

Verify installation:

```bash
timeshift --version
```

---

## Usage

Run normally:

```bash
my-scripts.sh --sudo system-update
```

or directly:

```bash
sudo ~/My\ Scripts/Local\ Scripts/system/my-system-update.sh
```

---

## Check updates only

Use:

```bash
my-scripts.sh system-update --checkonly
```

This will:

* Refresh package lists
* Show upgradeable packages
* Exit without creating snapshots
* Exit without installing updates

Useful for previewing changes.

---

## What the script does

### 1. Refresh package lists

Runs:

```bash
sudo apt update
```

---

### 2. Detect upgradeable packages

Runs:

```bash
apt list --upgradable
```

If nothing is available:

* exits safely
* creates no snapshots
* performs no upgrades

---

### 3. Create pre-update snapshot

Snapshot description:

```text
All Working - Before System Update & Upgrade
```

Purpose:

Rollback point if the update causes issues.

---

### 4. Install updates/upgrades

Runs:

```bash
sudo apt upgrade -y
sudo apt full-upgrade -y
```

This installs:

* package updates
* dependency changes
* package replacements/removals if required

---

### 5. Create post-update snapshot

Snapshot description:

```text
All Working - After System Update & Upgrade
```

Purpose:

Known-good recovery point after successful updates.

---

## Examples

Preview updates:

```bash
my-scripts.sh system-update --checkonly
```

Run full update:

```bash
my-scripts.sh --sudo system-update
```

Run directly:

```bash
sudo my-system-update.sh
```

---

## Snapshot Naming

Before update:

```text
All Working - Before System Update & Upgrade
```

After update:

```text
All Working - After System Update & Upgrade
```

These descriptions help identify safe restore points inside Timeshift.

---

## Recommended Usage Frequency

Suggested:

* Weekly for active systems
* Before major upgrades
* Before driver changes
* Before desktop environment upgrades

---

## Recovery

If an update causes problems:

1. Open Timeshift
2. Select the pre-update snapshot
3. Restore
4. Reboot

---

## Safety Notes

* Requires sudo privileges
* Requires Timeshift configured beforehand
* Ensure enough disk space for snapshots
* Avoid interrupting updates
* Avoid shutting down during snapshot creation

---

## Exit Behavior

Exit code `0`

* success
* no updates found
* check-only completed

Exit code `1`

* error
* missing dependencies
* failed snapshot
* failed update

---

## Design Principles

* Safety-first updates
* Automatic rollback points
* Minimal user interaction
* Predictable execution
* Fast update checks

---

## Notes

This script uses:

* `apt update`
* `apt upgrade`
* `apt full-upgrade`
* `timeshift --create`

It does **not**:

* autoremove packages
* autoclean package cache
* remove old kernels

These can be handled separately if desired.
