#!/usr/bin/env bash
set -euo pipefail

# Directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Directory to search for scripts (change this as needed)
SCRIPTS_SUBDIR="Local Scripts"
SCRIPTS_DIR="$SCRIPT_DIR/$SCRIPTS_SUBDIR"
THIS_SCRIPT="$(basename "$0")"
PREFIX="my-"

list_scripts() {
    echo "Available scripts in: $SCRIPTS_DIR (including one subfolder level)"
    while IFS= read -r f; do
        rel="${f#$SCRIPTS_DIR/}"
        if [[ "$rel" != "$THIS_SCRIPT" ]]; then
            printf '  %s\n' "$rel"
        fi
    done < <(find "$SCRIPTS_DIR" -maxdepth 2 -type f -name "*.sh" | sort)
}

resolve_script_path() {
    local target="$1"
    local matches=()
    local match

    if [[ "$target" != *.sh ]]; then
        target="${target}.sh"
    fi

    if [[ "$target" == */* ]]; then
        if [[ -f "$SCRIPTS_DIR/$target" ]]; then
            matches+=("$SCRIPTS_DIR/$target")
        fi
    else
        while IFS= read -r match; do
            matches+=("$match")
        done < <(find "$SCRIPTS_DIR" -maxdepth 2 -type f -name "$target")
    fi

    if [[ ${#matches[@]} -eq 0 ]]; then
        return 1
    fi

    if [[ ${#matches[@]} -gt 1 ]]; then
        echo "Error: multiple matches for '$target':" >&2
        for match in "${matches[@]}"; do
            printf '  %s\n' "${match#$SCRIPTS_DIR/}" >&2
        done
        return 2
    fi

    printf '%s\n' "${matches[0]}"
    return 0
}

show_help() {
    cat <<EOF
Usage:
  $THIS_SCRIPT                    List all .sh scripts in the scripts folder
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

        # Try direct target
        script_path="$(resolve_script_path "$target" || true)"

        # If not found, try with prefix
        if [[ -z "$script_path" ]]; then
            prefixed="${PREFIX}${target}"
            script_path="$(resolve_script_path "$prefixed" || true)"
        fi

        if [[ -z "$script_path" ]]; then
            echo "Error: script '$target' or '${PREFIX}${target}' not found in $SCRIPTS_DIR" >&2
            echo
            list_scripts
            exit 1
        fi

        # Run script (bash if not executable)
        if [[ ! -x "$script_path" ]]; then
            bash "$script_path" "$@"
        else
            "$script_path" "$@"
        fi
        ;;
esac
