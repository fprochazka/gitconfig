# fprochazka-gitconfig

Claude Code plugin for working inside [this gitconfig](https://github.com/fprochazka/gitconfig). It ships in the same repository as the commands it teaches, so a skill and the command it describes change in one commit.

The skills cover only what an agent gets wrong without them. Shortcuts such as `git cif` are left out, because a plain `git commit --fixup` costs fewer tokens than teaching the alias. Generic git rules live in the `git` plugin of [claude-code-plugins](https://github.com/fprochazka/claude-code-plugins).

## Requirements

This repository installed and included from `~/.gitconfig`, as the [main README](../../README.md#installation) describes. The skills call the commands through their git aliases.

## Installation

```bash
claude plugin marketplace add fprochazka/gitconfig --scope user
claude plugin install fprochazka-gitconfig@fprochazka-gitconfig --scope user
```

## Skills

- `git-worktrees-and-issues`: `git wt`, `git issue-branch` and `git wt-cleanup` instead of `git worktree add`, `git worktree remove` and the EnterWorktree tool. An agent cleans up its own worktree with `git -C <worktree> wt-cleanup --yes-safe`.
- `git-config-traps`: the defaults of this gitconfig that broke agents in past sessions: patches without `a/` and `b/` prefixes, rebases that move backup branches, disabled commit signing, and globally ignored files.
- `git-libs-clone`: `git libs-clone` for reading third-party sources from one shared clone under `~/devel/libs/` instead of a fresh clone in `/tmp`.
