#!/usr/bin/env bash
#
# Linear API functions for issue tracking
#
# Usage: source this file after common.sh
#   source "${SCRIPT_DIR}/lib/common.sh"
#   source "${SCRIPT_DIR}/lib/linear.sh"
#

readonly LINEAR_API_URL="https://api.linear.app/graphql"

# Get Linear API token from git config or environment
# Returns: token string or exits with error
linear_get_token() {
    local token

    # Try git config first
    token=$(git config --get issue-tracking.linearToken 2>/dev/null || true)

    # Fall back to environment variable
    if [[ -z "$token" ]]; then
        token="${LINEAR_API_TOKEN:-}"
    fi

    if [[ -z "$token" ]]; then
        die "Linear API token not configured. Set via:\n  git config --global issue-tracking.linearToken <token>\n  or export LINEAR_API_TOKEN=<token>"
    fi

    echo "$token"
}

# Fetch issue details from Linear API
# Usage: linear_get_issue "ISSUE-123"
# Returns: JSON with id, identifier, title, branchName fields
# Exits with error if issue not found
linear_get_issue() {
    local issue_id="$1"
    local token
    local query
    local payload
    local response
    local errors
    local issue

    token=$(linear_get_token)

    # GraphQL query - get issue by identifier
    query='query GetIssue($id: String!) {
        issue(id: $id) {
            id
            identifier
            title
            branchName
        }
    }'

    # Build JSON payload (escape quotes in query)
    payload=$(jq -n \
        --arg query "$query" \
        --arg id "$issue_id" \
        '{query: $query, variables: {id: $id}}')

    # Make API request
    response=$(curl -s -w "\n%{http_code}" \
        --connect-timeout 30 \
        --max-time 120 \
        -H "Authorization: $token" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$LINEAR_API_URL" 2>/dev/null) || die "Failed to connect to Linear API"

    # Extract HTTP status code (last line)
    local http_code
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
        die "Linear API request failed with HTTP $http_code"
    fi

    # Check for GraphQL errors
    errors=$(echo "$response" | jq -r '.errors // empty')
    if [[ -n "$errors" ]]; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"')
        die "Linear API error: $error_msg"
    fi

    # Extract issue data
    issue=$(echo "$response" | jq -r '.data.issue // empty')
    if [[ -z "$issue" || "$issue" == "null" ]]; then
        die "Issue '$issue_id' not found in Linear"
    fi

    echo "$issue"
}

# Get issue title
# Usage: linear_issue_title "$issue_json"
linear_issue_title() {
    echo "$1" | jq -r '.title'
}

# Get issue identifier (e.g., "ENG-123")
# Usage: linear_issue_identifier "$issue_json"
linear_issue_identifier() {
    echo "$1" | jq -r '.identifier'
}

# Get suggested branch name from Linear
# Usage: linear_issue_branch_name "$issue_json"
linear_issue_branch_name() {
    echo "$1" | jq -r '.branchName // empty'
}
