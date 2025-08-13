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

## Custom Git Commands

This gitconfig provides many custom git commands and aliases for enhanced productivity:

### Quick Access Commands
- **`git k`** - Launch gitk GUI
- **`git cola`** - Launch git-cola GUI

### Project Initialization
- **`git start`** - Initialize repository with an initial empty commit

### Branch History & Information
- **`git h`** - Print history of current branch without pager (useful for terminal output)
- **`git get-main-branch`** - Auto-detect main branch name (`master` or `main`)
- **`git get-main-upstream-branch`** - Get upstream branch name (`upstream/main` or `origin/main`)
- **`git get-current-branch`** - Get current branch name, even during rebase

### Work-in-Progress Management
- **`git wip`** - Stage all changes and commit as "WIP [ci skip]"
- **`git unwip`** - Undo the last WIP commit (reset HEAD~1)

### Smart Commit Operations
- **`git cif`** - Commit as fixup to the latest non-fixup commit
- **`git cifi`** - Interactive fixup commit selection
- **`git slurp`** - Move staged changes to previous commit (amend with unstaging)

### Branch Management & Cleanup
- **`git com`** - Checkout main branch, pull, and also run `git cleanup`
- **`git cleanup`** - Fetch all remotes, prune, and drop merged/gone branches
- **`git branches-merged-list`** - List local branches merged into main
- **`git branches-merged-drop`** - Delete cleanly merged branches
- **`git branches-gone-list`** - List branches whose remotes are gone
- **`git branches-gone-drop`** - Delete branches with gone remotes

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
- **`git sync-all-repos [dir]`** - Recursively sync all git repositories in directory
- **`git gitlab-clone-all`** - Clone all repositories from a GitLab group
