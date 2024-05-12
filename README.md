# ~/.shellrc
Comprehesive and portable environment configuration in a single file.

- [Install](#install)
- [Update](#update)
- [Conventions](#conventions)
- [Supported Tools](#supported-tools)
- [Utility Functions](#utility-functions)

## Overview
The goal of this script to **safely(1)** and **predictably(2)** store and update CLI and other app configurations from a single source, without using symlinks, Git or other more complex tools.

A single `source ~/.shellrc` *should* configure the shell environment and any supported (and installed) tools.

**(1) Safely:**
Configuration values coming from `.shellrc` are either appended or prepended to existing config files, in such a way that pre-existing user settings are preserved.

`.shellrc`'s `main()` runs only under interactive shells and with `set -euf` for additional safety. These values are restored to `set +euf` on success.

**(2) Predictably:**
Configurations are only written for the tools that are already present in the system to minimise clobbering the `~/` and `~/.config` dirs.

## Install
```
curl -fsSL https://raw.githubusercontent.com/tmslnz/shellrc/main/shellrc -o ~/.shellrc
. ~/.shellrc
```

## Update
`.shellrc` automatically checks for updates.

The last snapshot can be restored using:
```
shellrc revert
```

Updates can be manually requested using:
```
shellrc update
```

The updater saves previous versions in `~/.config/shellrc/snapshots`

## Conventions

All code in the script is wrapped in funsctions.

There are two classes of functions in the script:
- `_shellrc_*`: persistent in the session. These are utilities called throughout the script.
- `configure_*`: called once, then `unset -f` to remove them from the symbols list.

The execution flow is controlled in `main()`.

The script writes all configurations conditionally (i.e: `x in PATH`, `OS == Darwin`) and only within "fenced" sections (e.g. `BEGIN_SHELLRC [...] END_SHELLRC`).
Local changes _outside_ of a fenced section are never over-written.
Local changes _within_ a fenced section are also not overwritten if the edits are more recent than the `~/.shellrc` file's last updated timestamp.

## Supported Tools

### Bash
https://www.gnu.org/software/bash/

### Bash Completion
https://github.com/scop/bash-completion

### Z shell
https://www.zsh.org

### ssh
https://github.com/sharkdp/fd

### grep
https://en.wikipedia.org/wiki/Grep

### Emacs
https://www.gnu.org/software/emacs/

### Vim
https://www.vim.org/

### Nano
https://www.nano-editor.org

### NPM
https://www.npmjs.com

### Git
https://git-scm.com

### Wget
https://www.gnu.org/software/wget/

### fd
https://github.com/sharkdp/fd

### fzf
https://github.com/junegunn/fzf

### Zoxide
https://github.com/ajeetdsouza/zoxide

### Perlbrew
https://perlbrew.pl

### SDKMAN!
https://sdkman.io

### pyenv
https://github.com/pyenv/pyenv

### python
https://www.python.org

### python argcomplete
https://kislyuk.github.io/argcomplete/

### direnv
https://direnv.net

### broot
https://dystroy.org/broot/

### ncdu - NCurses Disk Usage
https://dev.yorhel.nl/ncdu

### automysqlbackup
https://sourceforge.net/projects/automysqlbackup/

### GoAccess
https://goaccess.io

### Composer
https://getcomposer.org

### shdotenv
https://github.com/ko1nksm/shdotenv

## Utility Functions

#### `get_user_home <username>`

#### `remove_host_key_at_line <line>`

#### `list_all_binaries`

#### `zap <dir>`

#### `git_lf <dir>`

#### `git_freeze_submodule <path>`

#### `configure_nebula`
