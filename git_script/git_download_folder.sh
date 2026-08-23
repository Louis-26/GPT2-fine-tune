#!/bin/bash
# Description: Download one or more folders from a git repository (sparse checkout).
# Usage:  bash download_folders.sh
# Default save location = root of the git repo you run this script from
# (git rev-parse --show-toplevel); falls back to the current directory.
# ~/TMP_DOWNLOADS is only a temporary workspace: it is created for the download
# and removed automatically after the folders are moved out.
# https urls are auto-converted to ssh (git@host:user/repo) so that your ssh key
# is used instead of typing a token every time. Set USE_SSH=false to disable.

main() {
    local REPO_URL BRANCH_NAME SAVE_DIR WORK_DIR FOLDER_NAME DEST ANSWER
    local -a FOLDER_NAMES
    local DEFAULT_SAVE_DIR DEFAULT_REPO_URL=""
    local TMP_ROOT="$HOME/TMP_DOWNLOADS"
    local USE_SSH=true                   # false = keep https urls as-is

    # default save dir = toplevel of the repo you are currently in
    if DEFAULT_SAVE_DIR=$(git rev-parse --show-toplevel 2>/dev/null); then
        DEFAULT_REPO_URL=$(git config --get remote.origin.url)
    else
        DEFAULT_SAVE_DIR="$PWD"          # not inside a repo -> save to where you run it
    fi

    read -r -p "Enter the url of the target repo
(e.g., https://github.com/Louis-26/personal_note), press Enter to use current repo [$DEFAULT_REPO_URL]: " REPO_URL
    read -r -p "Enter the folder name(s) from git repo
(multiple folders separated by spaces, e.g., folder1 docs/folder2): " -a FOLDER_NAMES
    read -r -p "Enter the branch name (default is main): " BRANCH_NAME
    read -r -p "Enter the local directory to save into
(press Enter to use: $DEFAULT_SAVE_DIR): " SAVE_DIR

    # set variables
    BRANCH_NAME=${BRANCH_NAME:-main}
    REPO_URL=${REPO_URL:-$DEFAULT_REPO_URL}
    REPO_URL="${REPO_URL%/}"             # drop trailing slash
    REPO_URL="${REPO_URL%.git}"          # strip trailing .git to avoid "xxx.git.git"
    # https://github.com/user/repo  ->  git@github.com:user/repo   (ssh key auth, no token)
    if [ "$USE_SSH" = true ] && [[ "$REPO_URL" =~ ^https?://([^/@]+@)?([^/]+)/(.+)$ ]]; then
        REPO_URL="git@${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
        echo "Using SSH url: ${REPO_URL}.git"
    fi
    SAVE_DIR="${SAVE_DIR:-$DEFAULT_SAVE_DIR}"
    SAVE_DIR="${SAVE_DIR//\\//}"         # windows style path -> unix style

    if [ -z "$REPO_URL" ]; then
        echo "Error: no repo url entered and current directory is not a git repo." >&2
        return 1
    fi
    if [ ${#FOLDER_NAMES[@]} -eq 0 ]; then
        echo "Error: no folder name entered." >&2
        return 1
    fi

    if ! mkdir -p "$SAVE_DIR"; then
        echo "Error: cannot create save directory: $SAVE_DIR" >&2
        return 1
    fi
    SAVE_DIR=$(cd "$SAVE_DIR" && pwd)    # normalize to absolute path

    # temp workspace lives inside ~/TMP_DOWNLOADS
    mkdir -p "$TMP_ROOT" || return 1
    WORK_DIR=$(mktemp -d "$TMP_ROOT/git_dl.XXXXXX") || return 1
    cd "$WORK_DIR" || return 1

    git init -q
    git remote add origin "${REPO_URL}.git"
    git sparse-checkout init --no-cone
    git sparse-checkout set "${FOLDER_NAMES[@]}"    # all folders in one shot
    if ! git pull "$REPO_URL" "$BRANCH_NAME"; then
        echo "Error: git pull failed. Check repo url / branch name / network." >&2
        cd "$SAVE_DIR" && rm -rf "$WORK_DIR"
        rmdir "$TMP_ROOT" 2>/dev/null
        return 1
    fi

    # move each target folder to the save directory
    for FOLDER_NAME in "${FOLDER_NAMES[@]}"; do
        if [ ! -e "$FOLDER_NAME" ]; then
            echo "Warning: folder '$FOLDER_NAME' not found in repo (check spelling / branch)." >&2
            continue
        fi
        DEST="$SAVE_DIR/$(basename "$FOLDER_NAME")"
        if [ -e "$DEST" ]; then
            read -r -p "'$DEST' already exists. Overwrite? [y/N]: " ANSWER
            if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
                rm -rf "$DEST"
            else
                echo "Skipped: $FOLDER_NAME"
                continue
            fi
        fi
        mv "$FOLDER_NAME" "$SAVE_DIR/"
        echo "Downloaded: $DEST"
    done

    # cleanup: delete the workspace, then remove TMP_DOWNLOADS itself.
    # rmdir only deletes an EMPTY directory, so if you keep anything of your
    # own inside ~/TMP_DOWNLOADS it will never be touched.
    cd "$SAVE_DIR" && rm -rf "$WORK_DIR"
    rmdir "$TMP_ROOT" 2>/dev/null
    echo "Done! Folders saved under $SAVE_DIR"
}

main "$@"