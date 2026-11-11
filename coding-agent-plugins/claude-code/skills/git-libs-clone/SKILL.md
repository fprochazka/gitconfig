---
name: git-libs-clone
description: Use when you need to read the source code of a third-party library, tool or other repository, instead of cloning it into /tmp or the scratchpad. `git libs-clone <url>` keeps one clone per repository under ~/devel/libs/<host>/<path> and updates it when it exists.
trigger-keywords: libs-clone, clone the repo, clone the repository, library source, source code of, third-party source, upstream source
---

# git libs-clone

```bash
git libs-clone <clone-url> [git clone options]
```

The command clones into `~/devel/libs/<host>/<path>`, for example `git@github.com:owner/repo.git` into `~/devel/libs/github.com/owner/repo`. If that clone exists, it fetches and pulls instead. `--dry-run` prints the target directory without cloning.

The clones are shared between sessions. Read them in place, and do not commit, switch branches or leave changes in them unless the user asks. To read a specific version, use `git -C <dir> show <tag>:<path>` or `git -C <dir> grep <pattern> <tag>` instead of checking the tag out.
