# My opinionated gitconfig

## Installation

```bash
cd ~/.config
git clone git@github.com:fprochazka/gitconfig.git
```

Include configs using a `~/.gitconfig`

```.gitconfig
[include]
    path = /home/fprochazka/.config/gitconfig/config/main.gitconfig

[user]
    name = your-name
    email = your-email
    signingkey = 123456789123456798123456789

[init]
    defaultBranch = main

[includeIf "gitdir:/home/fprochazka/devel/my-company/"]
    path = /home/fprochazka/devel/my-company/.gitconfig
```

### Installation of `diff-highlight`

1. `git clone git@github.com:git/git.git`
2. `cd git/contrib/diff-highlight`
3. `make`
4. `sudo mv diff-highlight /usr/local/bin/diff-highlight`

### Issue Tracking Configuration

To use `git issue-branch` and `git issue-mr` commands, configure your issue tracking system:

```gitconfig
[issue-tracking]
    system = linear                    # Supported: linear (more coming)
    linearToken = lin_api_xxxxxxxxxx   # Or use LINEAR_API_TOKEN env var
```

Per-company configuration works via `includeIf`:

```gitconfig
# In /home/user/devel/my-company/.gitconfig
[issue-tracking]
    linearToken = lin_api_company_token
```

## Custom Git Commands

This gitconfig provides many custom git commands and aliases for enhanced productivity:

### Project Initialization
- **`git start`** - Initialize repository with an initial empty commit

### Branch History & Information
- **`git h`** - Print history of current branch without pager (useful for terminal output)
- **`git get-main-branch`** - Auto-detect main branch name (`master` or `main`)
- **`git get-main-upstream-branch`** - Get tracking branch of main (fails if not configured)
- **`git get-main-ref-for-rebase`** - Get tracking branch of main (falls back to local main)
- **`git get-current-branch`** - Get current branch name, even during rebase

### Work-in-Progress Management
- **`git wip`** - Stage all changes and commit as "WIP [ci skip]"
- **`git unwip`** - Undo the last WIP commit (reset HEAD~1)

### Smart Commit Operations
- **`git cif`** - Commit as fixup to the latest non-fixup commit
- **`git cifi`** - Interactive fixup commit selection
- **`git slurp`** - Move staged changes to previous commit (amend with unstaging)
- **`git aiu`** - Track AI usage in commits by managing author and Co-authored-by metadata

### Branch Management & Cleanup
- **`git com`** - Checkout main branch, pull, and also run `git cleanup`
- **`git cleanup`** - Fetch all remotes, prune, and drop merged/gone branches
- **`git branches-gc [--merged] [--gone] [--drop]`** - List/delete stale branches (merged or gone), excludes worktree branches

### Stacked Branch Workflows
- **`git branches-stacked-list`** - List branches containing commits from current branch
- **`git fpush-stack`** - Force-push all branches updated by rebase --update-refs

### Advanced Operations
- **`git up`** - Stash changes, fetch, and pull from upstream
- **`git pu`** - Run `up` command then push main branch to upstream
- **`git permission-reset`** - Reset file permissions to match repository

### File & Content Search
- **`git find <pattern>`** - Find files in repository by name pattern
- **`git cf <commit>`** - Show files changed in a commit

### Repository Management
- **`git list-repos [dir]`** - List all git repositories as relative paths (does not descend into repos)
- **`git sync-all-repos [dir]`** - Recursively sync all git repositories in directory
- **`git gitlab-clone-all`** - Clone all repositories from a GitLab group (uses `glab` CLI for auth)
- **`git github-clone-all --org=ORG`** - Clone all repositories from a GitHub organization including wikis (uses `gh` CLI for auth)
- **`git libs-clone <url>`** - Clone a repository into libs directory organized by `<hostname>/<path>` (configurable via `clone.libs-dir`, default `~/devel/libs`)
- **`git remote-host-provider [remote]`** - Detect if remote is GitHub or GitLab (cached)
- **`git upstream-info [--name-only]`** - Show if origin is a fork and what the parent repo is

### Merge/Pull Request Operations
- **`git mr-status [branch]`** - Show MR/PR status for current branch (GitLab and GitHub)
- **`git pr-status [branch]`** - Alias for `mr-status`
- **`git get-branch-mr-id [branch]`** - Get cached MR/PR ID from git config (`branch.<name>.gitlab-mr-id` or `github-pr-id`)

### Issue Tracking Integration
- **`git issue-branch <issue-id>`** - Create or checkout a branch for an issue (e.g., `fp/ENG-123-fix-login-bug`)
- **`git issue-branch -w <issue-id>`** - Same as above but creates a git worktree at `<project>/.worktrees/<branch-dir>`
- **`git issue-mr [issue-id]`** - Push branch and create GitLab MR / GitHub PR with issue title

These commands integrate with issue tracking systems (currently Linear) to:
- Fetch issue title for branch naming and MR/PR titles
- Auto-detect GitLab vs GitHub and use appropriate CLI (`glab` / `gh`)
- Check for existing open MR/PR before creating duplicates
- Create as draft with "remove source branch after merge" and auto-assign to you

### Worktree Management
- **`git wt <branch>`** - Checkout branch into a worktree (like `git checkout` but for worktrees, doesn't touch current workdir)
- **`git wt -b <branch>`** - Create new branch and checkout into a worktree
- **`git wt-cleanup`** - Interactive worktree removal with branch info (upstream status, commit message). A worktree with unversioned files worth keeping (e.g. `.claude/` plans) can be removed with those files kept at their original path; the dir gets a `.worktree-archived` marker, orphan cleanup skips it, and a later `git wt <branch>` checks out into it again and restores the files (a checked-out file is never overwritten, the archived one is kept as `<name>.archived`). Kept files are hard-linked during the removal, so a worktree whose kept files belong to another user (e.g. written by docker as root), or with a mount inside it, is refused
- **`git wt-cleanup`** then `3 7 12-40` - Remove several worktrees at once; the selection is validated and confirmed once, and the keep-files prompt accepts `a` (yes for all)
- **`git wt-cleanup`** refuses up front, before touching anything, to remove a locked worktree or one with a directory you cannot write, read or search (git would otherwise stop halfway)
- **`git wt-cleanup -l`** - Only print the worktree list; each entry shows its unversioned files worth keeping (count, newest) and its Claude Code sessions (count, last), `--no-signals` skips that scan
- **`git wt-cleanup`** shows every MR/PR of the removed worktree's branch and deletes a branch git history calls unmerged when one of its MRs/PRs into the main branch is merged and the branch has no commit beyond that MR's head (squash and rebase merges); an open MR/PR or a failed lookup never counts as merged
- **`git wt-cleanup`** from inside a worktree cleans it up only when its branch is merged into the main branch (git history, or a merged MR/PR into it whose head contains the branch tip, and no MR/PR still open); otherwise it stops before touching anything. **`--force`** overrides only that refusal (the branch is then kept); every other safety stop still applies
- **`git wt-cleanup`** removes a worktree with submodules (which git refuses without `--force`) only after checking every submodule recursively: its working tree is this directory; clean status, no untracked files, ignored files only build output or IDE state without a repository inside; nothing in progress, no stash, no assume-unchanged or skip-worktree files, no linked worktrees of the submodule repo; every commit reachable from its refs and HEAD is on a remote-tracking ref or on a ref its remote has by the same name and object (asked with `git ls-remote` only when needed; what is left is refused by name, a shallow clone that cannot be verified is refused); a gitlink dir that is not a checked-out submodule is empty; no deinitialized submodule git dir is left. `--yes-safe` then forces the removal, interactively the force question shows the result first
- **`git wt-cleanup --yes-safe`** - From inside a worktree: clean it up without questions (remove it, keep its unversioned files in place, keep an unmerged branch, skip orphaned directories); any safety question (unsaved changes, recently written files, git refusing a plain removal) stops the run instead of being answered; it also refuses a worktree with Claude session activity in the last 24 hours (the last timestamp in its session transcripts), which `--force` does not override
- **`git wt-cleanup -n`** - Dry run: print every removal and move instead of doing it (orphaned directories, worktrees, branches)

### Other aliases & shortcuts

See [config/aliases.gitconfig](https://github.com/fprochazka/gitconfig/blob/master/config/aliases.gitconfig)

## Development

### Linting

Run `shellcheck` on all scripts:

```bash
make lint        # Check with warning severity
make lint-all    # Check with style severity (stricter)
```

### Testing

```bash
make test        # Bash syntax check on all scripts
make test-help   # Verify all scripts respond to --help
```

### Requirements

- [shellcheck](https://github.com/koalaman/shellcheck) - Install via `apt install shellcheck` or `brew install shellcheck`
