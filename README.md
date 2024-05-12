# ~/.shellrc
Comprehesive and portable environment configuration in a single file.

- [Install](#install)
- [Update](#update)
- [Conventions](#conventions)
- [Supported Tools](#supported-tools)

## Overview


The goal of this script to **predictably and safely** store and update CLI and other app configurations from a single source, without using symlinks, Git or other more complex tools.

A single run of the script *should* set the environment and any available tool's config in one go.
Configurations are only written for tools that are present in the system.

The script writes all configurations conditionally (i.e: `x in PATH`, `OS == Darwin`) and only within "fenced" sections (e.g. `BEGIN_SHELLRC [...] END_SHELLRC`).
Local changes _outside_ of a fenced section are never over-written.
Local changes _within_ a fenced section are also not overwritten if the edits are more recent than the `~/.shellrc` file's last updated timestamp.

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

All code in the script is wrapped in functions.

There are two classes of functions in the script:
- `_shellrc_*`: persistent in the session. These are utlities called throughout the script.
- `configure_*`: called once, then `unset -f` to remove them from the symbols list.

The execution flow is controlled in `main()`.

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
