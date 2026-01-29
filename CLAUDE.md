@README.md

## Project Structure

```
├── bin/                    # Executable git commands (git-<name> pattern)
│   ├── git-*               # Individual commands, invoked as `git <name>`
│   └── lib/                # Shared bash libraries
│       ├── common.sh       # Core utilities (colors, error handling, git helpers)
│       ├── issue-tracking.sh  # Issue tracker dispatcher (loads backends)
│       ├── linear.sh       # Linear API backend
│       ├── vcs-hosting.sh  # GitLab/GitHub abstraction layer
│       └── terminals.sh    # Terminal detection utilities
├── config/                 # Git configuration files
│   ├── main.gitconfig      # Main entry point (includes all others)
│   ├── commands.gitconfig  # Aliases for bin/git-* commands
│   ├── aliases.gitconfig   # Short aliases (co, ci, st, etc.)
│   └── *.gitconfig         # Other config modules (colors, diff, rebase, etc.)
├── Makefile                # Lint and test commands
└── README.md               # User-facing documentation
```

## Creating New Commands

1. Create executable script at `bin/git-<command-name>`
2. Add shebang and source common library:
   ```bash
   #!/usr/bin/env bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "${SCRIPT_DIR}/lib/common.sh"
   ```
3. Implement `usage()` function that responds to `-h`/`--help`
4. Add alias in `config/commands.gitconfig`:
   ```gitconfig
   command-name = !~/.config/gitconfig/bin/git-command-name
   ```
5. Document in `README.md` under appropriate section

## Library Pattern

Scripts source libraries from `bin/lib/`:
```bash
source "${SCRIPT_DIR}/lib/common.sh"        # Always first
source "${SCRIPT_DIR}/lib/issue-tracking.sh" # If needed
source "${SCRIPT_DIR}/lib/vcs-hosting.sh"    # If needed
```

Key functions from `common.sh`:
- `die "message"` - Print error and exit
- `warn "message"` - Print warning to stderr
- `print_red/green/yellow/bold` - Colored output
- `require_git_repo` - Exit if not in a git repo
- `get_current_branch` - Current branch name (works during rebase)
- `is_main_branch "$branch"` - Check if branch is master/main
- `find_git_repos [dir]` - Find all git repos under directory

## Development Workflow

After modifying any scripts, always run:

```bash
make lint      # shellcheck validation
make test      # bash syntax check
make test-help # verify --help works for all commands
```

## Keep In Sync

When making changes, ensure these stay consistent:

| Change | Also update |
|--------|-------------|
| New `bin/git-*` command | `config/commands.gitconfig`, `README.md` |
| New shared function | `bin/lib/common.sh` (or appropriate lib) |
| Rename/remove command | `config/commands.gitconfig`, `README.md` |
| Change command options | `usage()` in script, `README.md` |
| New library file | Document sourcing pattern in this file |

## Code Conventions

- All scripts use `set -euo pipefail` (via `common.sh`)
- Functions use `local` for all variables
- Error messages go to stderr via `die` or `warn`
- Every command must handle `--help` flag
- Use `require_git_repo` when command needs to be in a repo
