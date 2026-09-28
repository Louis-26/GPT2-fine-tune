#!/usr/bin/env bash
# git_update_script.sh
#
# Replace a local folder (default: git_script) with the same-named folder
# pulled fresh from a remote git repo's specific branch. Intended to sync
# shared tooling (like git_script/) across many repos from one source of truth.
#
# Any flag you don't provide silently falls back to the default — there are
# no interactive prompts. This makes the script safe to call from other
# scripts (like git_search.sh) and keeps bare-no-args invocation fast.
# Works from a terminal (any cwd inside the repo) and when double-clicked
# in Explorer.
#
# Usage:
#   git_update_script.sh                              # all defaults
#   git_update_script.sh --target-repo URL --folder-name NAME ...   # override any subset
#
# Flags:
#   --target-repo / --target_repo   URL       Remote repo URL, no trailing .git required
#   --folder-name / --folder_name   NAME      Folder inside the repo to grab
#   --branch-name / --branch_name   NAME      Branch to pull from
#   --save-folder / --save_folder   PATH      Scratch dir to stage the download
#   -h / --help                               Show this message

set -euo pipefail

# Remember where this script file lives and what it was called with, BEFORE
# any cd (a relative script path would resolve wrongly afterwards). Both are
# needed by the self-relocation step in section 0.
SELF="$(realpath -- "${BASH_SOURCE[0]}")"
ORIG_ARGS=("$@")

# Work on the repo that contains the current directory. If we're not inside
# one (e.g. double-clicked and Git Bash started in $HOME), fall back to the
# repo that contains this script.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null ||
            (cd "$(dirname -- "$SELF")" && git rev-parse --show-toplevel))"
cd "$REPO_ROOT"

# -------- defaults --------

DEFAULT_REPO_URL="https://github.com/Louis-26/git_script_template"
DEFAULT_FOLDER_NAME="git_script"
DEFAULT_BRANCH_NAME="main"
DEFAULT_SAVE_DIR="${HOME//\\//}/Downloads"

# -------- cli parsing --------

REPO_URL="$DEFAULT_REPO_URL"
FOLDER_NAME="$DEFAULT_FOLDER_NAME"
BRANCH_NAME="$DEFAULT_BRANCH_NAME"
SAVE_DIR="$DEFAULT_SAVE_DIR"

print_help() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

need_value() {
    local flag="$1"
    local value="${2:-}"

    if [ -z "$value" ] || [[ "$value" == --* ]]; then
        echo "ERROR: $flag requires a value." >&2
        exit 2
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --target-repo|--target_repo)
            need_value "$1" "${2:-}"
            REPO_URL="$2"
            shift 2
            ;;

        --folder-name|--folder_name)
            need_value "$1" "${2:-}"
            FOLDER_NAME="$2"
            shift 2
            ;;

        --branch-name|--branch_name)
            need_value "$1" "${2:-}"
            BRANCH_NAME="$2"
            shift 2
            ;;

        --save-folder|--save_folder)
            need_value "$1" "${2:-}"
            SAVE_DIR="$2"
            shift 2
            ;;

        -h|--help)
            print_help
            ;;

        *)
            echo "Unknown argument: $1" >&2
            echo "Run with --help for usage." >&2
            exit 2
            ;;
    esac
done

# Normalize Windows-style backslashes to forward slashes
SAVE_DIR="${SAVE_DIR//\\//}"

# -------- sanity checks --------

if [ ! -d "$SAVE_DIR" ]; then
    echo "Creating scratch directory: $SAVE_DIR"
    mkdir -p "$SAVE_DIR" || {
        echo "Failed to create $SAVE_DIR" >&2
        exit 1
    }
fi

ORIGINAL_DIR="$(pwd)"
TARGET_DIR="$(realpath -m -- "$ORIGINAL_DIR/$FOLDER_NAME")"

# -------- 0. stage dir, and make sure we're not running from inside the target --------

# A relocated copy of this script (see below) reuses the stage dir it was
# handed via the environment instead of creating a second one.
if [ -n "${UPDATE_SCRIPT_TMP_DIR:-}" ] && [ -d "$UPDATE_SCRIPT_TMP_DIR" ]; then
    TMP_DIR="$UPDATE_SCRIPT_TMP_DIR"
else
    TMP_DIR="$(mktemp -d "$SAVE_DIR/update_script_XXXXXX")"
fi

# bash keeps this script file open for as long as it runs, and Windows refuses
# to rename/move a directory that contains an open file. So when this script
# lives inside the very folder it is about to replace (the normal case:
# git_script/git_update_script.sh), the `mv` in section 2 fails with
# "Permission denied". Fix: copy ourselves into the stage dir and re-exec from
# there, so nothing inside $FOLDER_NAME is held open anymore. The copy is not
# inside $FOLDER_NAME, so this branch is not taken a second time.
case "$SELF" in
    "$TARGET_DIR"/*)
        cp -- "$SELF" "$TMP_DIR/self.sh"
        UPDATE_SCRIPT_TMP_DIR="$TMP_DIR" exec "$BASH" "$TMP_DIR/self.sh" "${ORIG_ARGS[@]}"
        ;;
esac

cleanup() {
    # Delayed, and run from a fresh `bash -c` rather than a subshell: a subshell
    # would inherit the open handle to self.sh (which lives in $TMP_DIR) and
    # could keep Windows from deleting the directory.
    "$BASH" -c 'sleep 1; rm -rf -- "$1"' _ "$TMP_DIR" >/dev/null 2>&1 &

    # If we are the top-level shell of this window (the script was
    # double-clicked in Explorer, or run from cmd/PowerShell), the window
    # would vanish the moment we exit. Give the user a chance to read.
    if [ "${SHLVL:-1}" -le 1 ] && [ -t 0 ]; then
        read -rp "Press Enter to close..." _ || true
    fi
}
trap cleanup EXIT

echo
echo "Update plan:"
echo "  From:   $REPO_URL  (branch: $BRANCH_NAME)"
echo "  Folder: $FOLDER_NAME"
echo "  Stage:  $SAVE_DIR"
echo "  Target: $TARGET_DIR"
echo

# -------- 1. sparse-checkout the folder into the stage dir --------

cd "$TMP_DIR"

git init -q
git remote add origin "${REPO_URL%.git}.git"
git sparse-checkout init --no-cone
git sparse-checkout set "$FOLDER_NAME"

echo "Fetching $FOLDER_NAME from $BRANCH_NAME ..."

if ! git pull --quiet "${REPO_URL%.git}.git" "$BRANCH_NAME"; then
    echo "Pull failed. Check the URL/branch and try again." >&2
    exit 1
fi

if [ ! -d "$FOLDER_NAME" ]; then
    echo "The folder '$FOLDER_NAME' was not found at the top level of $BRANCH_NAME." >&2
    exit 1
fi

# -------- 2. replace the local folder with the downloaded one --------

cd "$ORIGINAL_DIR"

NEW_DIR="$TMP_DIR/$FOLDER_NAME"

if [ ! -d "$TARGET_DIR" ]; then
    # First install: nothing to replace.
    mv -- "$NEW_DIR" "$TARGET_DIR"

elif mv -- "$TARGET_DIR" "$TMP_DIR/old_folder" 2>/dev/null; then
    # Normal case: swap the whole folder in one go.
    mv -- "$NEW_DIR" "$TARGET_DIR"

else
    # Windows refuses to rename a folder that some process holds open — usually
    # a terminal cd'd into it (including the Git Bash window that appears when
    # you double-click this script inside the folder), or an Explorer window
    # showing it. Files *inside* such a folder can still be added and deleted,
    # so replace the contents instead of the folder: copy the new files in
    # first, then delete whatever is not part of the new version. That order
    # means nothing goes missing if a step fails halfway.
    echo "'$FOLDER_NAME' is held open by another program (a terminal cd'd into it, or an Explorer window),"
    echo "so its contents are being replaced in place instead."

    case "$SELF" in
        "$TARGET_DIR"/*)
            # Should not happen (section 0 relocates us), but never overwrite
            # the script bash is currently reading from.
            echo "Refusing to overwrite the running script in place. Run it from outside '$FOLDER_NAME'." >&2
            exit 1
            ;;
    esac

    if ! cp -Rf -- "$NEW_DIR/." "$TARGET_DIR/"; then
        echo "Some files in '$FOLDER_NAME' could not be overwritten — something still has them open." >&2
        echo "Close it and run again." >&2
        exit 1
    fi

    (cd "$TARGET_DIR" && find . -mindepth 1 -depth -print0) |
    while IFS= read -r -d '' entry; do
        [ -e "$NEW_DIR/$entry" ] ||
            rm -rf -- "$TARGET_DIR/$entry" ||
            echo "Warning: could not delete stale '$FOLDER_NAME/${entry#./}'." >&2
    done
fi

echo
echo "Done! '$FOLDER_NAME' was updated in $TARGET_DIR"