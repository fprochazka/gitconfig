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
