---
name: git-config-traps
description: Load before patching, rebasing, committing, force-adding an ignored file, or running tests through git, to learn which of the user's git settings and git's own environment make the usual commands for these misbehave, and what to run instead.
trigger-keywords: git apply, patch file, git diff, rebase, autosquash, update-refs, backup branch, gpg, signing, gitignore, ignored file, git add -f, rebase --exec, GIT_DIR, core.bare
---

# Git config traps

The user's global git config (`~/.config/gitconfig`) changes the defaults below. The last entry is not a setting but the environment git gives to the commands it runs.

- **Diffs have no `a/` and `b/` prefixes** (`diff.noprefix`). A patch from `git diff > x.patch` fails in `git apply` and in `patch -p1`. Make patches with `git diff --default-prefix` or `git format-patch`. Apply a patch without prefixes with `git apply -p0`.
- **A rebase moves other branches too** (`rebase.updateRefs`). Every local branch that points into the rebased commits moves with them, a backup branch included. Back up before a rewrite with a tag: `git tag backup/<name>`. `git branches-stacked-list` shows the branches that contain the current branch's commits, and `git fpush-stack` pushes all of them with `--force-with-lease`.
- **An interactive rebase runs without an editor.** Claude Code sets `GIT_SEQUENCE_EDITOR=true`, so `git rebase -i --autosquash <base>` applies the generated todo list. To reorder or drop commits, pass a `sed` script as `GIT_SEQUENCE_EDITOR`.
- **Commits are signed** (`commit.gpgsign`). Never pass `--no-gpg-sign` or `-c commit.gpgsign=false`. If signing fails, stop and tell the user.
- **Some files are ignored globally** (`config/main.gitignore`). `.claude/plans/`, `.claude/review-report/`, `.claude/settings.local.json` and `.idea` stay out of commits on purpose: never force-add them. Archives, binaries and logs (`*.zip`, `*.jar`, `*.gz`, `*.tar`, `*.log`, `*.sqlite`) are ignored too, and `git add -A` skips them without a message. A test fixture with such an extension needs `git add -f <path>`. `git check-ignore -v <path>` names the rule that ignores a file.
- **A test suite run by git can write into the real repo.** A command that git runs, such as a hook or a `git rebase --exec` step, inherits `GIT_DIR` and related variables, and every `git` call in it, a test's `git init` in a temp dir included, then acts on the real repo. That has turned the main checkout into `core.bare = true` (`fatal: this operation must be run in a work tree`) and left stray branches and worktrees in it. Test a commit by checking it out instead of through `rebase --exec` or a hook, or strip the variables first: `env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_COMMON_DIR -u GIT_OBJECT_DIRECTORY <cmd>`. A test suite that calls git should drop the variables `git rev-parse --local-env-vars` lists. To repair a checkout that became bare, run `git --git-dir=<repo>/.git config core.bare false`, then check `git worktree list` and `git branch` for entries the tests created.
