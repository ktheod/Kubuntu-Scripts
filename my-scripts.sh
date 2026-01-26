#!/usr/bin/env bash
set -euo pipefail

# Directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THIS_SCRIPT="$(basename "$0")"
PREFIX="my-"

list_scripts() {
    shopt -s nullglob
    echo "Available scripts in: $SCRIPT_DIR"
    for f in "$SCRIPT_DIR"/*.sh; do
        base="$(basename "$f")"
        if [[ "$base" != "$THIS_SCRIPT" ]]; then
            printf '  %s\n' "$base"
        fi
    done
}

show_help() {
    cat <<EOF
Usage:
  $THIS_SCRIPT                    List all .sh scripts in this folder
  $THIS_SCRIPT --list             List all .sh scripts
  $THIS_SCRIPT <script> [...]     Run <script> (with optional arguments)

Prefix Support:
  If <script> does not start with '${PREFIX}', the runner will try both:
      <script>.sh
      ${PREFIX}<script>.sh

Examples:
  $THIS_SCRIPT backup
  $THIS_SCRIPT my-backup
  $THIS_SCRIPT backup --full
EOF
}

# No arguments: list scripts
if [[ $# -eq 0 ]]; then
    list_scripts
    exit 0
fi

case "$1" in
    -h|--help|help)
        show_help
        exit 0
        ;;
    -l|--list|list)
        list_scripts
        exit 0
        ;;
    *)
        target="$1"
        shift

        # Add .sh extension if missing
        if [[ "$target" != *.sh ]]; then
            target="${target}.sh"
        fi

        # Try direct path
        script_path="$SCRIPT_DIR/$target"

        # If not found, try with prefix
        if [[ ! -f "$script_path" ]]; then
            prefixed="${PREFIX}${target}"
            script_prefixed_path="$SCRIPT_DIR/$prefixed"
            if [[ -f "$script_prefixed_path" ]]; then
                script_path="$script_prefixed_path"
            else
                echo "Error: script '$target' or '${PREFIX}${target}' not found in $SCRIPT_DIR" >&2
                echo
                list_scripts
                exit 1
            fi
        fi

        # Run script (bash if not executable)
        if [[ ! -x "$script_path" ]]; then
            bash "$script_path" "$@"
        else
            "$script_path" "$@"
        fi
        ;;
esac
