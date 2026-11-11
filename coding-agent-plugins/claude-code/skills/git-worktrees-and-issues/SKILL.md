---
name: git-worktrees-and-issues
description: Use when creating, switching to or removing a git worktree, or starting a branch for a ticket. Covers `git wt`, `git issue-branch` and `git wt-cleanup` from the user's gitconfig, which replace `git worktree add`, `git worktree remove`, `git checkout -b` for a ticket, and the EnterWorktree tool.
trigger-keywords: worktree, worktrees, git wt, wt-cleanup, issue-branch, branch for the ticket, branch for ticket, new branch, clean up the worktree
---

# Worktrees and ticket branches

Use these commands instead of `git worktree add`, `git worktree remove` and the EnterWorktree tool. They put the worktree at `<repo>/.worktrees/<branch-with-dashes>`, copy the main checkout's gitignored files (`.env`, `.idea/`, `.claude/settings.local.json`) into it, carry over mise and Claude Code trust, and restore files kept by an earlier cleanup.

## Create

- `git wt <branch>` checks out an existing branch into a worktree. A branch that exists only on one remote gets a tracking branch. If the branch already has a worktree, the command prints that path instead of failing; for the branch of the main checkout, that is the repo root.
- `git wt -b <branch>` creates the branch at the `HEAD` of the directory you run it in. To start from the base branch, create the branch first: `git branch <branch> origin/<base> && git wt <branch>`.
- `git issue-branch -w <ticket-id>` does the same for a ticket. It names the branch `<initials>/<ticket-id>-<title-slug>` from the tracker, or reuses the ticket's existing branch, and records the ticket in `git config branch.<branch>.issue-id`. Without `-w` it checks the branch out in the current directory.

The last line of output holds the path. When the command cannot open a terminal tab, it prints `cd <path>` and exits 1, but the worktree exists.

## Remove

Run the cleanup with `-C <worktree>`, so that it cleans up that worktree instead of asking which one:

```bash
git -C <worktree> wt-cleanup --yes-safe
```

It removes the worktree only when its branch is merged into the main branch, deletes the merged branch, and keeps untracked files worth keeping in place for a later `git wt <branch>`. It never answers a safety question: it stops instead. It also refuses while another Claude session was active in the worktree in the last 24 hours. When it stops, tell the user why and leave the worktree as it is. Pass `--force` only when the user asks to remove a worktree of an unmerged branch; the branch is then kept.

`git wt-cleanup -l` lists every worktree with its branch state, read-only. Never delete a worktree directory with `rm -rf` or `git worktree remove`.
