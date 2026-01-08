#!/usr/bin/env bash
#
# VCS hosting abstraction layer (GitLab / GitHub)
#
# Usage: source this file after common.sh
#   source "${SCRIPT_DIR}/lib/common.sh"
#   source "${SCRIPT_DIR}/lib/vcs-hosting.sh"
#
# Provides unified interface for GitLab (glab) and GitHub (gh) operations.
#

#
# Host detection
#

# Detect VCS host by probing APIs (expensive, use vcs_get_host for cached version)
_vcs_detect_host_type() {
    if gh repo view --json name >/dev/null 2>&1; then
        echo "github"
    elif glab repo view -F json >/dev/null 2>&1; then
        echo "gitlab"
    else
        return 1
    fi
}

# Get VCS host for remote (cached in git config)
# Usage: vcs_get_host [remote]
# Returns: "gitlab" or "github"
# shellcheck disable=SC2120
vcs_get_host() {
    local remote="${1:-origin}"
    local config_key="remote.${remote}.vcs-host"

    # Try cached value first
    local cached
    cached=$(git config --get "$config_key" 2>/dev/null || true)

    if [[ -n "$cached" ]]; then
        echo "$cached"
        return 0
    fi

    # Detect by probing APIs
    local host_type
    if ! host_type=$(_vcs_detect_host_type); then
        die "Could not detect remote type for '$remote'"
    fi

    # Cache the result
    git config "$config_key" "$host_type"

    echo "$host_type"
}

#
# Merge/Pull Request operations
#

# Check if MR/PR exists for a branch (open only)
# Usage: vcs_mr_exists "branch-name"
# Returns: URL of existing MR/PR, or exits with 1 if not found
vcs_mr_exists() {
    local branch="$1"
    local host
    host=$(vcs_get_host)

    case "$host" in
        gitlab) _gitlab_mr_exists "$branch" ;;
        github) _github_pr_exists "$branch" ;;
        *) die "Unsupported VCS host: $host" ;;
    esac
}

# Create MR/PR for current branch
# Usage: vcs_mr_create "MR Title"
vcs_mr_create() {
    local title="$1"
    local host
    host=$(vcs_get_host)

    case "$host" in
        gitlab) _gitlab_mr_create "$title" ;;
        github) _github_pr_create "$title" ;;
        *) die "Unsupported VCS host: $host" ;;
    esac
}

# Open existing MR/PR in browser
# Usage: vcs_mr_view_web
vcs_mr_view_web() {
    local host
    host=$(vcs_get_host)

    case "$host" in
        gitlab) glab mr view --web 2>/dev/null || true ;;
        github) gh pr view --web 2>/dev/null || true ;;
        *) die "Unsupported VCS host: $host" ;;
    esac
}

# Fetch MR/PR details as JSON
# Usage: vcs_mr_view [branch]
# Returns: JSON with MR/PR details, or exits with 1 if not found
vcs_mr_view() {
    local branch="${1:-}"
    local host
    host=$(vcs_get_host)

    case "$host" in
        gitlab) _gitlab_mr_view "$branch" ;;
        github) _github_pr_view "$branch" ;;
        *) die "Unsupported VCS host: $host" ;;
    esac
}

#
# Fork/upstream detection
#

# Detect if origin is a fork and cache the result
# Usage: vcs_detect_fork
# Caches in git config: remote.origin.fork-parent and remote.origin.repo-name
vcs_detect_fork() {
    local host
    host=$(vcs_get_host)

    case "$host" in
        gitlab) _gitlab_detect_fork ;;
        github) _github_detect_fork ;;
        *) die "Unsupported VCS host: $host" ;;
    esac
}

# Get fork parent name (cached, calls vcs_detect_fork if needed)
# Usage: vcs_get_fork_parent
# Returns: parent repo name, or "-" if not a fork
vcs_get_fork_parent() {
    local config_key="remote.origin.fork-parent"
    local cached
    cached=$(git config --get "$config_key" 2>/dev/null || true)

    if [[ -z "$cached" ]]; then
        vcs_detect_fork
        cached=$(git config --get "$config_key")
    fi

    echo "$cached"
}

# Get repo name (self or parent if fork)
# Usage: vcs_get_repo_name
vcs_get_repo_name() {
    local parent
    parent=$(vcs_get_fork_parent)

    if [[ "$parent" == "-" ]]; then
        git config --get "remote.origin.repo-name" 2>/dev/null || echo "unknown"
    else
        echo "$parent"
    fi
}

#
# GitLab implementation
#

_gitlab_mr_exists() {
    local branch="$1"
    local mr_info

    mr_info=$(glab mr list --source-branch "$branch" --state opened --output json 2>/dev/null || echo "[]")

    if [[ "$mr_info" != "[]" && "$mr_info" != "" && "$mr_info" != "null" ]]; then
        local url
        url=$(echo "$mr_info" | jq -r '.[0].web_url // empty')
        if [[ -n "$url" ]]; then
            echo "$url"
            return 0
        fi
    fi

    return 1
}

_gitlab_mr_create() {
    local title="$1"

    print_bold "Creating GitLab merge request..."
    glab mr create --push --draft --remove-source-branch --assignee '@me' --title "$title" --yes
}

_gitlab_mr_view() {
    local branch="$1"

    if [[ -n "$branch" ]]; then
        glab mr view "$branch" -F json 2>/dev/null
    else
        glab mr view -F json 2>/dev/null
    fi
}

_gitlab_detect_fork() {
    local json
    if ! json=$(glab repo view -F json 2>&1); then
        die "Could not query GitLab repo"
    fi

    local self_name
    local parent_name
    self_name=$(json_field "$json" '.path_with_namespace')
    parent_name=$(json_field "$json" '.forked_from_project.path_with_namespace // empty')

    if [[ -n "$parent_name" ]]; then
        git config "remote.origin.fork-parent" "$parent_name"
    else
        git config "remote.origin.fork-parent" "-"
        git config "remote.origin.repo-name" "$self_name"
    fi
}

#
# GitHub implementation
#

_github_pr_exists() {
    local branch="$1"
    local pr_info

    pr_info=$(gh pr list --head "$branch" --state open --json url 2>/dev/null || echo "[]")

    if [[ "$pr_info" != "[]" && "$pr_info" != "" && "$pr_info" != "null" ]]; then
        local url
        url=$(echo "$pr_info" | jq -r '.[0].url // empty')
        if [[ -n "$url" ]]; then
            echo "$url"
            return 0
        fi
    fi

    return 1
}

_github_pr_create() {
    local title="$1"

    # Ensure branch is pushed first
    if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
        print_bold "Pushing branch to origin..."
        git push -u origin HEAD
    fi

    print_bold "Creating GitHub pull request..."
    gh pr create --draft --assignee '@me' --title "$title"
}

_github_pr_view() {
    local branch="$1"

    if [[ -n "$branch" ]]; then
        gh pr view "$branch" --json url,title,body,state,statusCheckRollup,headRefName,baseRefName,isCrossRepository,headRepositoryOwner 2>/dev/null
    else
        gh pr view --json url,title,body,state,statusCheckRollup,headRefName,baseRefName,isCrossRepository,headRepositoryOwner 2>/dev/null
    fi
}

_github_detect_fork() {
    local origin_url
    origin_url=$(git remote get-url origin 2>/dev/null || true)

    local origin_repo
    origin_repo=$(echo "$origin_url" | sed -E 's#.*github\.com[:/](.+)(\.git)?$#\1#' | sed 's/\.git$//')

    local json
    if ! json=$(gh repo view "$origin_repo" --json isFork,parent,nameWithOwner 2>&1); then
        die "Could not query GitHub repo '$origin_repo'"
    fi

    local is_fork
    local self_name
    local parent_name
    is_fork=$(json_field "$json" '.isFork')
    self_name=$(json_field "$json" '.nameWithOwner')
    parent_name=$(json_field "$json" '.parent.owner.login + "/" + .parent.name // empty')

    if [[ "$is_fork" == "true" && -n "$parent_name" ]]; then
        git config "remote.origin.fork-parent" "$parent_name"
    else
        git config "remote.origin.fork-parent" "-"
        git config "remote.origin.repo-name" "$self_name"
    fi
}
