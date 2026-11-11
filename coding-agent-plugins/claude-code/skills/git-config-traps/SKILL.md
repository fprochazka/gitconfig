---
name: git-config-traps
description: Use before making or applying a patch from `git diff`, rebasing or backing up a branch before a rewrite, committing when signing fails, or adding a file that git reports as ignored. The user's global git config changes defaults that break the usual commands for these.
trigger-keywords: git apply, patch file, git diff, rebase, autosquash, update-refs, backup branch, gpg, signing, gitignore, ignored file, git add -f
---

# Git config traps

The user's global git config (`~/.config/gitconfig`) changes these defaults.

- **Diffs have no `a/` and `b/` prefixes** (`diff.noprefix`). A patch from `git diff > x.patch` fails in `git apply` and in `patch -p1`. Make patches with `git diff --default-prefix` or `git format-patch`. Apply a patch without prefixes with `git apply -p0`.
- **A rebase moves other branches too** (`rebase.updateRefs`). Every local branch that points into the rebased commits moves with them, a backup branch included. Back up before a rewrite with a tag: `git tag backup/<name>`. `git branches-stacked-list` shows the branches that contain the current branch's commits, and `git fpush-stack` pushes all of them with `--force-with-lease`.
- **An interactive rebase runs without an editor.** Claude Code sets `GIT_SEQUENCE_EDITOR=true`, so `git rebase -i --autosquash <base>` applies the generated todo list. To reorder or drop commits, pass a `sed` script as `GIT_SEQUENCE_EDITOR`.
- **Commits are signed** (`commit.gpgsign`). Never pass `--no-gpg-sign` or `-c commit.gpgsign=false`. If signing fails, stop and tell the user.
- **Some files are ignored globally** (`config/main.gitignore`). `.claude/plans/`, `.claude/review-report/`, `.claude/settings.local.json` and `.idea` stay out of commits on purpose: never force-add them. Archives, binaries and logs (`*.zip`, `*.jar`, `*.gz`, `*.tar`, `*.log`, `*.sqlite`) are ignored too, and `git add -A` skips them without a message. A test fixture with such an extension needs `git add -f <path>`. `git check-ignore -v <path>` names the rule that ignores a file.
