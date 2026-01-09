#!/usr/bin/env bash
#
# Issue tracking dispatcher - loads appropriate backend based on git config
#
# Usage: source this file after common.sh
#   source "${SCRIPT_DIR}/lib/common.sh"
#   source "${SCRIPT_DIR}/lib/issue-tracking.sh"
#
# Configuration (git config):
#   [issue-tracking]
#       system = linear    # linear | jira | github (only linear supported now)
#
# After sourcing, these functions are available:
#   issue_get "$issue_id"           - fetch issue JSON
#   issue_title "$issue_json"       - extract title
#   issue_identifier "$issue_json"  - extract identifier (e.g., "ENG-123")
#   issue_branch_name "$issue_json" - extract suggested branch name
#

# Get configured issue tracking system
# Returns: system name (default: linear)
issue_tracking_system() {
    git config --get issue-tracking.system 2>/dev/null || echo "linear"
}

# Load the appropriate backend and set up function aliases
_issue_tracking_init() {
    local system
    local script_dir

    system=$(issue_tracking_system)
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    case "$system" in
        linear)
            # shellcheck source=linear.sh
            source "${script_dir}/linear.sh"

            # Set up generic function aliases
            issue_get() { linear_get_issue "$@"; }
            issue_title() { linear_issue_title "$@"; }
            issue_identifier() { linear_issue_identifier "$@"; }
            issue_branch_name() { linear_issue_branch_name "$@"; }
            ;;
        # Future: jira, github, etc.
        *)
            die "Unsupported issue tracking system: $system\nSupported: linear"
            ;;
    esac
}

#
# Branch name utilities
#

# Generate user initials from git user.name
# Usage: issue_user_initials
# Returns: lowercase initials (e.g., "fp" for "Filip Prochazka")
issue_user_initials() {
    local name
    name=$(git config user.name 2>/dev/null || true)

    if [[ -z "$name" ]]; then
        die "Git user.name not configured"
    fi

    # Take first letter of each word, up to 4, lowercase
    echo "$name" | awk '{for(i=1;i<=NF && i<=4;i++) printf tolower(substr($i,1,1))}'
}

# Remove common stop words that don't add meaning to branch names
# Usage: issue_remove_stop_words "Add the ability to export data"
# Returns: "Add ability export data"
issue_remove_stop_words() {
    local text="$1"

    # High-confidence stop words:
    # - Articles: a, an, the
    # - Common prepositions: in, on, at, to, for, of, with, by, from, as
    # - Conjunctions: and, or, but
    # - Be verbs: is, are, was, were, be
    # - Have verbs: has, have, had
    # - Pronouns: it, its, this, that
    local stop_words="a|an|the|in|on|at|to|for|of|with|by|from|as|and|or|but|is|are|was|were|be|has|have|had|it|its|this|that"

    echo "$text" \
        | sed -E "s/\b(${stop_words})\b//gi" \
        | sed 's/  \+/ /g' \
        | sed 's/^ //' \
        | sed 's/ $//'
}

# Sanitize text for use in branch names
# Usage: issue_sanitize_branch_name "Some Title with CAPS & special!"
# Returns: "some-title-with-caps-special"
issue_sanitize_branch_name() {
    local text="$1"

    echo "$text" \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9-]/-/g' \
        | sed 's/-\+/-/g' \
        | sed 's/^-//' \
        | sed 's/-$//'
}

# Truncate text to max length, avoiding mid-word cuts
# Usage: issue_truncate "some-long-text" 20
issue_truncate() {
    local text="$1"
    local max_len="$2"

    if [[ ${#text} -le $max_len ]]; then
        echo "$text"
        return
    fi

    # Truncate and remove trailing hyphen
    echo "${text:0:$max_len}" | sed 's/-$//'
}

# Create branch name from issue
# Usage: issue_create_branch_name "$issue_json"
# Returns: "fp/ENG-123-some-sanitized-title"
issue_create_branch_name() {
    local issue_json="$1"
    local identifier
    local title
    local initials
    local sanitized_title
    local prefix
    local remaining_len

    identifier=$(issue_identifier "$issue_json")
    title=$(issue_title "$issue_json")
    initials=$(issue_user_initials)

    # Build prefix and calculate remaining space
    prefix="${initials}/${identifier}-"
    remaining_len=$((50 - ${#prefix}))

    if [[ $remaining_len -le 0 ]]; then
        echo "${initials}/${identifier}"
        return
    fi

    title=$(issue_remove_stop_words "$title")
    sanitized_title=$(issue_sanitize_branch_name "$title")
    sanitized_title=$(issue_truncate "$sanitized_title" "$remaining_len")

    echo "${prefix}${sanitized_title}"
}

# Create MR title from issue
# Usage: issue_create_mr_title "$issue_json"
# Returns: "ENG-123: Original Title"
issue_create_mr_title() {
    local issue_json="$1"
    local identifier
    local title
    local prefix
    local remaining_len

    identifier=$(issue_identifier "$issue_json")
    title=$(issue_title "$issue_json")

    prefix="${identifier}: "
    remaining_len=$((72 - ${#prefix}))

    if [[ $remaining_len -le 0 ]]; then
        echo "$identifier"
        return
    fi

    if [[ ${#title} -gt $remaining_len ]]; then
        title="${title:0:$remaining_len}"
    fi

    echo "${prefix}${title}"
}

#
# Branch-issue association (stored in git config)
#

# Get issue ID associated with a branch
# Usage: issue_get_branch_issue_id ["branch_name"]
issue_get_branch_issue_id() {
    local branch="${1:-$(get_current_branch)}"
    git config --get "branch.${branch}.issue-id" 2>/dev/null || true
}

# Set issue ID for a branch
# Usage: issue_set_branch_issue_id "ISSUE-123" ["branch_name"]
issue_set_branch_issue_id() {
    local issue_id="$1"
    local branch="${2:-$(get_current_branch)}"
    git config "branch.${branch}.issue-id" "$issue_id"
}

#
# Find existing branch for an issue
#

# Find local branch containing the issue identifier
# Usage: issue_find_existing_branch "ENG-123"
# Returns: branch name if found, empty otherwise
issue_find_existing_branch() {
    local issue_id="$1"
    local branch

    # Search through all local branches for one containing the issue ID
    # Check git config first (explicit association)
    while IFS= read -r branch; do
        local stored_id
        stored_id=$(git config --get "branch.${branch}.issue-id" 2>/dev/null || true)
        if [[ "$stored_id" == "$issue_id" ]]; then
            echo "$branch"
            return 0
        fi
    done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

    # Fall back to pattern matching in branch name
    branch=$(git for-each-ref --format='%(refname:short)' refs/heads/ \
        | grep -i "/${issue_id}-\|/${issue_id}$" \
        | head -n1 || true)

    if [[ -n "$branch" ]]; then
        echo "$branch"
        return 0
    fi

    return 1
}

# Initialize on source
_issue_tracking_init
