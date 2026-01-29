#!/usr/bin/env bash
#
# Common functions for git-* scripts
#
# Usage: source this file at the top of your script
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib/common.sh"
#

# Strict mode - applied when sourced
set -euo pipefail

#
# Colors
#

readonly COLOR_RED='\033[31m'
readonly COLOR_GREEN='\033[32m'
readonly COLOR_YELLOW='\033[33m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_RESET='\033[0m'

print_red()    { echo -e "${COLOR_RED}$*${COLOR_RESET}"; }
print_green()  { echo -e "${COLOR_GREEN}$*${COLOR_RESET}"; }
print_yellow() { echo -e "${COLOR_YELLOW}$*${COLOR_RESET}"; }
print_bold()   { echo -e "${COLOR_BOLD}$*${COLOR_RESET}"; }

#
# Error handling
#

# Print error message to stderr and exit
# Usage: die "message" [exit_code]
die() {
    echo -e "${COLOR_RED}Error: $1${COLOR_RESET}" >&2
    exit "${2:-1}"
}

# Print warning message to stderr (does not exit)
# Usage: warn "message"
warn() {
    echo -e "${COLOR_YELLOW}Warning: $1${COLOR_RESET}" >&2
}

#
# Git repository checks
#

# Exit with error if not in a git repository
require_git_repo() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        die "Not in a git repository"
    fi
}

# Exit with error if there are no commits
require_commits() {
    if ! git rev-parse HEAD >/dev/null 2>&1; then
        die "No commits found in repository"
    fi
}

# Exit with error if working tree has uncommitted changes
require_clean_worktree() {
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        die "Working tree has uncommitted changes"
    fi
}

# Check if working tree is clean (no uncommitted changes)
# Returns 0 if clean, 1 if dirty
is_worktree_clean() {
    git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null
}

#
# Git branch helpers
#

# Get the current branch name, even during rebase
get_current_branch() {
    # Check if we're in a rebase
    local git_dir
    git_dir=$(git rev-parse --git-dir)

    for location in rebase-merge rebase-apply; do
        local path="${git_dir}/${location}"
        if [[ -d "$path" ]]; then
            local revision
            revision=$(<"${path}/head-name")
            echo "${revision##refs/heads/}"
            return 0
        fi
    done

    git rev-parse --abbrev-ref HEAD
}

# Get the main branch name (master or main)
get_main_branch() {
    git get-main-branch
}

# Check if branch is main/master
# Usage: is_main_branch "branch_name"
is_main_branch() {
    local branch="$1"
    [[ "$branch" =~ ^(master|main)$ ]]
}

# Check if branch has an upstream tracking branch
# Usage: has_upstream ["branch_name"]
has_upstream() {
    local branch="${1:-HEAD}"
    git rev-parse --abbrev-ref "${branch}"'@{u}' >/dev/null 2>&1
}

# Get the remote name for a branch
# Usage: get_branch_remote "branch_name"
get_branch_remote() {
    local branch="$1"
    git config "branch.${branch}.remote"
}

# Get the remote branch name for a local branch
# Usage: get_branch_upstream "branch_name"
get_branch_upstream() {
    local branch="$1"
    git config "branch.${branch}.merge" | sed 's|refs/heads/||'
}

#
# Progress tracking (for parallel operations)
#

# Initialize a progress counter file
# Usage: progress_file=$(init_progress_counter)
init_progress_counter() {
    local progress_file
    progress_file=$(mktemp)
    echo "0" > "$progress_file"
    echo "$progress_file"
}

# Atomically increment progress counter and return new value
# Usage: current=$(increment_progress_counter "$progress_file")
increment_progress_counter() {
    local progress_file="$1"
    flock "$progress_file" bash -c "
        n=\$(cat '$progress_file' 2>/dev/null || echo 0)
        echo \$((n + 1)) > '$progress_file'
        cat '$progress_file'
    "
}

#
# Input validation
#

# Check if a value is a valid integer
# Usage: is_integer "value"
is_integer() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]]
}

# Check if a value is in a numeric range
# Usage: is_in_range "value" "min" "max"
is_in_range() {
    local value="$1"
    local min="$2"
    local max="$3"
    is_integer "$value" && (( value >= min && value <= max ))
}

#
# JSON helpers (requires jq)
#

# Safely extract a field from JSON
# Usage: json_field "$json" ".field"
json_field() {
    local json="$1"
    local field="$2"
    echo "$json" | jq -r "$field"
}

# URL encode a string
# Usage: url_encode "path/with spaces"
url_encode() {
    printf '%s' "$1" | jq -sRr @uri
}

#
# Worktree helpers
#

# Sanitize a string for use as a directory name
# Only allows alphanumeric chars and dashes, collapses repeats, trims edges
# Usage: sanitize_worktree_dirname "fp/ENG-123-some-feature"
# Returns: "fp-ENG-123-some-feature"
sanitize_worktree_dirname() {
    local text="$1"

    echo "$text" \
        | sed 's/[^a-zA-Z0-9-]/-/g' \
        | sed 's/-\+/-/g' \
        | sed 's/^-//' \
        | sed 's/-$//'
}

# Get the main repository root (works from worktrees too)
# Usage: get_main_repo_root
# Returns: /path/to/main/repo (not the worktree path)
get_main_repo_root() {
    # First worktree listed is always the main repository
    git worktree list --porcelain | head -1 | sed 's/^worktree //'
}

# Get the worktrees directory path for a git repository
# Usage: get_worktrees_dir [git_root_dir]
# Returns: /path/to/project/../project-worktrees
get_worktrees_dir() {
    local git_root="${1:-$(get_main_repo_root)}"
    local project_basename
    local parent_dir

    project_basename=$(basename "$git_root")
    parent_dir=$(dirname "$git_root")

    echo "${parent_dir}/${project_basename}-worktrees"
}

# Get list of all branches currently checked out in worktrees
# Usage: get_worktree_branches
# Returns one branch name per line (excludes detached HEAD worktrees)
get_worktree_branches() {
    git worktree list --porcelain | grep '^branch refs/heads/' | sed 's|^branch refs/heads/||'
}

#
# Repository discovery
#

# Recursive helper for find_git_repos - not meant to be called directly
# DFS traversal that stops at git repositories (doesn't descend into them)
_find_git_repos_recurse() {
    local dir="$1"

    # If this is a git repo, print and stop recursing
    if [[ -d "$dir/.git" ]]; then
        printf '%s\n' "$dir"
        return
    fi

    local entry

    # Recurse into non-hidden subdirectories
    # The || true prevents set -e from triggering when glob doesn't match
    for entry in "$dir"/*/; do
        [[ -d "$entry" ]] && _find_git_repos_recurse "${entry%/}" || true
    done

    # Hidden directories (.[!.] matches .x but not . or ..)
    for entry in "$dir"/.[!.]*/; do
        [[ -d "$entry" ]] && _find_git_repos_recurse "${entry%/}" || true
    done

    # Directories starting with .. (..? matches ..x but not ..)
    for entry in "$dir"/..?*/; do
        [[ -d "$entry" ]] && _find_git_repos_recurse "${entry%/}" || true
    done
}

# Find all git repositories under a directory
# Outputs absolute paths, one per line, sorted
# Does not descend into directories that are already git repositories
# Usage: find_git_repos [directory]
find_git_repos() {
    local dir="${1:-.}"
    local start_dir
    start_dir=$(cd "$dir" && pwd)

    _find_git_repos_recurse "$start_dir" | sort
}

# Find existing worktree path for a branch
# Usage: find_worktree_for_branch "branch-name"
# Returns the path if found, exits with 1 otherwise
find_worktree_for_branch() {
    local branch="$1"
    local worktree_path=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
            worktree_path="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$branch" ]]; then
                echo "$worktree_path"
                return 0
            fi
        fi
    done < <(git worktree list --porcelain)

    return 1
}

# Create a worktree for a branch
# Usage: create_worktree "branch-name" [git_root_dir]
# Creates worktree at <project>-worktrees/<sanitized-branch-name>
create_worktree() {
    local branch_name="$1"
    local git_root="${2:-$(get_main_repo_root)}"
    local worktrees_dir
    local dirname
    local worktree_path

    worktrees_dir=$(get_worktrees_dir "$git_root")
    dirname=$(sanitize_worktree_dirname "$branch_name")
    worktree_path="${worktrees_dir}/${dirname}"

    # Create worktrees directory if it doesn't exist
    if [[ ! -d "$worktrees_dir" ]]; then
        mkdir -p "$worktrees_dir"
        print_green "Created worktrees directory: $worktrees_dir"
    fi

    # Check if worktree already exists
    if [[ -d "$worktree_path" ]]; then
        die "Worktree already exists: $worktree_path"
    fi

    # Create the worktree (redirect output to stderr so it doesn't mix with return value)
    git worktree add "$worktree_path" "$branch_name" >&2

    echo "$worktree_path"
}
