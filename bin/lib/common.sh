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
readonly COLOR_PURPLE='\033[35m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_RESET='\033[0m'

print_red()    { echo -e "${COLOR_RED}$*${COLOR_RESET}"; }
print_green()  { echo -e "${COLOR_GREEN}$*${COLOR_RESET}"; }
print_yellow() { echo -e "${COLOR_YELLOW}$*${COLOR_RESET}"; }
print_purple() { echo -e "${COLOR_PURPLE}$*${COLOR_RESET}"; }
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

# Check if branch is merged into another branch (all commits reachable from target)
# This is the standard git definition: branch is an ancestor of target
# Usage: is_branch_merged "branch" ["target_branch"]  (default target: main branch)
is_branch_merged() {
    local branch="$1"
    local target="${2:-$(get_main_branch)}"
    git merge-base --is-ancestor "$branch" "$target" 2>/dev/null
}

# Check if branch has zero commits ahead of target
# The branch pointer sits on a commit that is directly on target's history
# Usage: is_branch_no_changes "branch" ["target_branch"]
is_branch_no_changes() {
    local branch="$1"
    local target="${2:-$(get_main_branch)}"
    local ahead
    ahead=$(git rev-list --count "${target}..${branch}" 2>/dev/null || echo 0)
    [[ "$ahead" -eq 0 ]]
}

# Check if branch had its own work that was merged into target
# True when branch is merged AND its tip is on a side branch (not on target's first-parent line)
# Usage: is_branch_merged_with_changes "branch" ["target_branch"] ["mainline_commits_file"]
# The optional mainline_commits_file is a file with first-parent commit hashes for bulk use
is_branch_merged_with_changes() {
    local branch="$1"
    local target="${2:-$(get_main_branch)}"
    local mainline_file="${3:-}"

    # Must be merged first
    is_branch_merged "$branch" "$target" || return 1

    # Must not be on target's first-parent line
    local tip
    tip=$(git rev-parse "$branch" 2>/dev/null) || return 1

    if [[ -n "$mainline_file" ]]; then
        # Use precomputed file for performance
        ! grep -qFx "$tip" "$mainline_file"
    else
        ! git log --first-parent --format='%H' "$target" | grep -qFm1 "$tip"
    fi
}

# Output first-parent commit hashes of a branch, one per line
# Use to precompute mainline commits for bulk is_branch_merged_with_changes calls
# Usage: mainline_file=$(mktemp); get_mainline_commits "main" > "$mainline_file"
get_mainline_commits() {
    local target="${1:-$(get_main_branch)}"
    git log --first-parent --format='%H' "$target"
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
    # Note: avoid 'head -1' in pipeline - causes SIGPIPE with pipefail on large output
    local line
    read -r line < <(git worktree list --porcelain)
    echo "${line#worktree }"
}

# Get the legacy worktrees directory path (old convention: sibling dir with -worktrees suffix)
# Usage: get_legacy_worktrees_dir [git_root_dir]
# Returns: /path/to/project/../project-worktrees
get_legacy_worktrees_dir() {
    local git_root="${1:-$(get_main_repo_root)}"
    local project_basename
    local parent_dir

    project_basename=$(basename "$git_root")
    parent_dir=$(dirname "$git_root")

    echo "${parent_dir}/${project_basename}-worktrees"
}

# Get the worktrees directory path for a git repository
# Usage: get_worktrees_dir [git_root_dir]
# Returns: /path/to/project/.worktrees
# Note: existing worktrees at the legacy path are found via git worktree list,
# this function only determines where NEW worktrees are created
get_worktrees_dir() {
    local git_root="${1:-$(get_main_repo_root)}"
    echo "${git_root}/.worktrees"
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

# JetBrains IDE config directories - subdirs are symlinked, files are copied
readonly JETBRAINS_CONFIG_DIRS=(.idea)

# Files/dirs inside JetBrains config dirs to skip (IDE regenerates or personal state)
readonly JETBRAINS_SKIP_ENTRIES=(workspace.xml shelf)

# Build artifact directories excluded from worktree warmup
readonly WARMUP_EXCLUDE_DIRS=(target node_modules build dist .gradle .next .nx vendor __pycache__ .mypy_cache .pytest_cache .tox .venv venv)

# Warm up a new worktree by copying gitignored files from the main repo
# JetBrains config dirs get special handling: subdirs are symlinked, files are copied
# Build artifact directories are skipped
# Usage: warmup_worktree <worktree_path> <git_root>
warmup_worktree() {
    local worktree_path="$1"
    local git_root="$2"

    # Build grep pattern for excluding build artifact directories and the worktrees dir itself
    local exclude_pattern="(^|/)\.worktrees/"
    local dir
    for dir in "${WARMUP_EXCLUDE_DIRS[@]}"; do
        exclude_pattern="${exclude_pattern}|(^|/)${dir}/"
    done

    # Get all gitignored files, excluding build artifacts
    local -a ignored_files=()
    while IFS= read -r file; do
        ignored_files+=("$file")
    done < <(git -C "$git_root" ls-files --others --ignored --exclude-standard 2>/dev/null | grep -Ev "$exclude_pattern" || true)

    [[ ${#ignored_files[@]} -gt 0 ]] || return 0

    # Process JetBrains config dirs with special handling
    local jetbrains_dir
    for jetbrains_dir in "${JETBRAINS_CONFIG_DIRS[@]}"; do
        [[ -d "${git_root}/${jetbrains_dir}" ]] || continue

        # Ensure the target .idea/ dir exists
        mkdir -p "${worktree_path}/${jetbrains_dir}"

        # Find subdirectories to symlink (unique top-level dirs inside .idea/)
        local -a symlinked_dirs=()
        local subdir
        while IFS= read -r subdir; do
            [[ -n "$subdir" ]] || continue

            # Skip entries that IDE regenerates or are personal state
            local should_skip=false
            local skip_entry
            for skip_entry in "${JETBRAINS_SKIP_ENTRIES[@]}"; do
                if [[ "$subdir" == "$skip_entry" ]]; then
                    should_skip=true
                    break
                fi
            done
            [[ "$should_skip" == false ]] || continue

            if [[ -d "${git_root}/${jetbrains_dir}/${subdir}" ]] && [[ ! -e "${worktree_path}/${jetbrains_dir}/${subdir}" ]]; then
                ln -s "${git_root}/${jetbrains_dir}/${subdir}" "${worktree_path}/${jetbrains_dir}/${subdir}"
                symlinked_dirs+=("$subdir")
            fi
        done < <(printf '%s\n' "${ignored_files[@]}" | grep "^${jetbrains_dir}/" | sed "s|^${jetbrains_dir}/||; s|/.*||" | sort -u)

        # Copy regular files (not inside symlinked subdirs)
        local file
        for file in "${ignored_files[@]}"; do
            [[ "$file" == "${jetbrains_dir}/"* ]] || continue
            local rel="${file#${jetbrains_dir}/}"
            local top_level="${rel%%/*}"

            # Skip entries that IDE regenerates or are personal state
            local should_skip=false
            local skip_entry
            for skip_entry in "${JETBRAINS_SKIP_ENTRIES[@]}"; do
                if [[ "$top_level" == "$skip_entry" ]]; then
                    should_skip=true
                    break
                fi
            done
            [[ "$should_skip" == false ]] || continue

            # Skip if this file is inside a symlinked subdir
            if [[ -d "${git_root}/${jetbrains_dir}/${top_level}" ]]; then
                continue
            fi

            # Copy the file
            local target_dir
            target_dir=$(dirname "${worktree_path}/${file}")
            mkdir -p "$target_dir"
            cp -a "${git_root}/${file}" "${worktree_path}/${file}"
        done

        print_green "${jetbrains_dir}/ settings copied" >&2
    done

    # Copy remaining gitignored files (not in JetBrains dirs)
    local file
    local copied_other=false
    for file in "${ignored_files[@]}"; do
        # Skip JetBrains config dirs (already handled)
        local skip=false
        for jetbrains_dir in "${JETBRAINS_CONFIG_DIRS[@]}"; do
            if [[ "$file" == "${jetbrains_dir}/"* ]]; then
                skip=true
                break
            fi
        done
        [[ "$skip" == false ]] || continue

        local target_dir
        target_dir=$(dirname "${worktree_path}/${file}")
        mkdir -p "$target_dir"
        cp -a "${git_root}/${file}" "${worktree_path}/${file}"

        if [[ "$copied_other" == false ]]; then
            copied_other=true
            print_green "Copying gitignored files:" >&2
        fi
        echo "  ${file}" >&2
    done
}

# Propagate mise trust from the source repo to a new worktree
#
# mise trusts config files by canonicalized absolute path, so a worktree's
# checkout of the same .mise.toml is a different trust key and would prompt
# again on first use. If the source repo's own config is trusted, trust the
# worktree's copy too.
#
# Silent no-op if mise is not installed or the source repo isn't trusted.
# Trust on parent dirs already applies to the worktree path transitively,
# so we only act when the project root itself is explicitly trusted.
#
# Usage: maybe_propagate_mise_trust <git_root> <worktree_path>
maybe_propagate_mise_trust() {
    local git_root="$1"
    local worktree_path="$2"

    command -v mise >/dev/null 2>&1 || return 0

    # `mise trust --show -C <dir>` prints "<path>: trusted|untrusted" for each
    # mise config in <dir> and its parents. Paths starting with $HOME are
    # abbreviated with a leading ~.
    local show_output
    show_output=$(mise trust --show -C "$git_root" 2>/dev/null || true)

    local found_trusted=false
    local line
    while IFS= read -r line; do
        [[ "$line" == "~"* ]] && line="${HOME}${line:1}"
        if [[ "$line" == "${git_root}: trusted" ]]; then
            found_trusted=true
            break
        fi
    done <<< "$show_output"

    [[ "$found_trusted" == true ]] || return 0

    if mise trust -C "$worktree_path" >/dev/null 2>&1; then
        print_green "mise: trusted config in worktree" >&2
    else
        warn "mise: failed to trust config in worktree: $worktree_path"
    fi
}

# Print the candidate Claude Code config files, one per line, deduped, existing only
#
# Claude Code keeps per-directory project state in a `.projects` map inside one or
# more `.claude.json` files: the default config in $HOME, an optional config under
# $CLAUDE_CONFIG_DIR, and one per auth-switch profile under $HOME/.claude-profiles/.
#
# Usage: _claude_config_files
_claude_config_files() {
    local -a candidates=()

    candidates+=("${HOME}/.claude.json")

    if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
        candidates+=("${CLAUDE_CONFIG_DIR}/.claude.json")
    fi

    # The glob may not match any profile - guard it so set -e doesn't abort
    local f
    for f in "${HOME}"/.claude-profiles/*/.claude.json; do
        [[ -e "$f" ]] && candidates+=("$f") || true
    done

    # Emit existing files, deduped, preserving first-seen order
    local -a seen=()
    for f in "${candidates[@]}"; do
        [[ -f "$f" ]] || continue
        local already=false
        local s
        for s in "${seen[@]}"; do
            [[ "$s" == "$f" ]] && { already=true; break; }
        done
        [[ "$already" == true ]] && continue
        seen+=("$f")
        printf '%s\n' "$f"
    done
}

# Keys copied from the root repo's project entry onto a new worktree's entry.
# Only trust/onboarding state and MCP/tool config inherit - never session metrics
# (last*), example files, or other per-directory bookkeeping.
readonly CLAUDE_COPY_KEYS_JSON='[
  "hasTrustDialogAccepted",
  "hasCompletedProjectOnboarding",
  "projectOnboardingSeenCount",
  "hasClaudeMdExternalIncludesApproved",
  "hasClaudeMdExternalIncludesWarningShown",
  "allowedTools",
  "enabledMcpjsonServers",
  "disabledMcpjsonServers",
  "mcpServers",
  "mcpContextUris"
]'

# Propagate Claude Code trust/config from the root repo to a new worktree
#
# Claude Code trust is per-directory (keyed by absolute path in the `.projects`
# map), so a fresh worktree is untrusted and re-prompts on first use. For each
# config file, if the root repo's entry is trusted, copy the trust/onboarding
# and MCP/tool keys onto the worktree's entry. The copy is gated per file: a
# config where the root isn't trusted contributes nothing (no blind flip).
#
# Silent no-op if jq is missing or no config trusts the root.
#
# Usage: maybe_propagate_claude_trust <git_root> <worktree_path>
maybe_propagate_claude_trust() {
    local git_root="$1"
    local worktree_path="$2"

    command -v jq >/dev/null 2>&1 || return 0

    local updated=0
    local f
    while IFS= read -r f; do
        # Gate: only inherit when the source entry exists and is trusted in this file
        local trusted
        trusted=$(jq -r --arg root "$git_root" '.projects[$root].hasTrustDialogAccepted // false' "$f" 2>/dev/null || echo false)
        [[ "$trusted" == "true" ]] || continue

        # Temp in the same directory as the target so the final mv is an atomic
        # same-filesystem rename (mktemp's default /tmp would be cross-device)
        local tmp
        tmp=$(mktemp "$(dirname "$f")/.claude.json.XXXXXX") || { warn "claude: mktemp failed for $f"; continue; }

        # Preserve original file mode for the atomic replacement
        cp -p "$f" "$tmp" 2>/dev/null || { warn "claude: cp -p failed for $f"; rm -f "$tmp"; continue; }

        if jq --arg root "$git_root" --arg wt "$worktree_path" --argjson keys "$CLAUDE_COPY_KEYS_JSON" '
                (.projects[$root]) as $src
                | ($src | with_entries(select([.key] | inside($keys)))) as $picked
                | .projects[$wt] = ((.projects[$wt] // {}) + $picked)
            ' "$f" > "$tmp" 2>/dev/null && jq empty "$tmp" >/dev/null 2>&1; then
            if mv "$tmp" "$f"; then
                updated=$((updated + 1))
            else
                warn "claude: failed to replace $f"
                rm -f "$tmp"
            fi
        else
            warn "claude: failed to update $f"
            rm -f "$tmp"
        fi
    done < <(_claude_config_files)

    if [[ "$updated" -gt 0 ]]; then
        print_green "claude: trust+config inherited from root in ${updated} config(s) for worktree" >&2
    fi
}

# Remove a directory's project entry from every Claude Code config file
#
# Symmetric cleanup for maybe_propagate_claude_trust: when a worktree is removed,
# drop its `.projects[<dir>]` entry so stale per-directory state doesn't linger.
#
# Silent no-op if jq is missing or no config has an entry for the directory.
#
# Usage: remove_claude_project_entry <dir_path>
remove_claude_project_entry() {
    local dir_path="$1"

    command -v jq >/dev/null 2>&1 || return 0

    local removed=0
    local f
    while IFS= read -r f; do
        local exists
        exists=$(jq -r --arg dir "$dir_path" 'if (.projects | has($dir)) then "true" else "false" end' "$f" 2>/dev/null || echo false)
        [[ "$exists" == "true" ]] || continue

        # Temp in the same directory as the target so the final mv is an atomic
        # same-filesystem rename (mktemp's default /tmp would be cross-device)
        local tmp
        tmp=$(mktemp "$(dirname "$f")/.claude.json.XXXXXX") || { warn "claude: mktemp failed for $f"; continue; }

        cp -p "$f" "$tmp" 2>/dev/null || { warn "claude: cp -p failed for $f"; rm -f "$tmp"; continue; }

        if jq --arg dir "$dir_path" 'del(.projects[$dir])' "$f" > "$tmp" 2>/dev/null && jq empty "$tmp" >/dev/null 2>&1; then
            if mv "$tmp" "$f"; then
                removed=$((removed + 1))
            else
                warn "claude: failed to replace $f"
                rm -f "$tmp"
            fi
        else
            warn "claude: failed to update $f"
            rm -f "$tmp"
        fi
    done < <(_claude_config_files)

    if [[ "$removed" -gt 0 ]]; then
        print_green "claude: removed project entry from ${removed} config(s)" >&2
    fi
}

# Create a worktree for a branch
# Usage: create_worktree "branch-name" [git_root_dir]
# Creates worktree at <project>/.worktrees/<sanitized-branch-name>
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
        print_green "Created worktrees directory: $worktrees_dir" >&2
    fi

    # Check if worktree already exists
    if [[ -d "$worktree_path" ]]; then
        die "Worktree already exists: $worktree_path"
    fi

    # Create the worktree (redirect output to stderr so it doesn't mix with return value)
    git worktree add "$worktree_path" "$branch_name" >&2

    # Warm up the worktree with gitignored files from main repo
    warmup_worktree "$worktree_path" "$git_root"

    # Propagate mise trust if the source repo's config is trusted
    maybe_propagate_mise_trust "$git_root" "$worktree_path"

    # Propagate Claude Code trust/config from the source repo
    maybe_propagate_claude_trust "$git_root" "$worktree_path"

    echo "$worktree_path"
}
