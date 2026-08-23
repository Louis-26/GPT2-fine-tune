cd "$(git rev-parse --show-toplevel)"

# 1. Stage all changes
git add .

# 2. Check staged and untracked files for large files (>100MB)
# Use -c to temporarily disable path escaping without altering gitconfig
LARGE_FILES=$(git -c core.quotepath=false ls-files --cached --others --exclude-standard | while IFS= read -r file; do
    if [ -f "$file" ] && [ "$(stat -c%s "$file" 2>/dev/null || echo 0)" -gt 104857600 ]; then
        echo "$file"
    fi
done)

# 3. Unstage large files
if [ -n "$LARGE_FILES" ]; then
    echo "WARNING: The following files are 100MB or larger and will NOT be committed:"
    echo "$LARGE_FILES"
    echo "$LARGE_FILES" | while IFS= read -r file; do
        clean_file="${file#./}"
        git restore --staged "$clean_file" 2>/dev/null || true
    done
    echo "Large files have been unstaged. Use git_lfs_push.sh for large files."
fi

# 4. Safely exit if no staged changes remain after unstaging
if git diff --cached --quiet; then
    echo "No other changes to commit."
    exit 0
fi

# 5. Commit and push
commit_msg="${1:-update}"
git commit -m "$commit_msg"

branch_name=$(git rev-parse --abbrev-ref HEAD)
git push origin "$branch_name"