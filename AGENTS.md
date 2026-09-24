# AGENTS.md

`shellrc` is the entire product: a single-file POSIX `sh` script installed to `~/.shellrc`. There is no build, package manager, or test suite. Indentation is tabs; the file targets `sh` with Bash/Zsh compatibility. `sh` compatibility is a requirement for any function on the hot path, so that this script can run on more restricted shells.

## Verify changes
- `shellcheck shellrc` — primary linter. Pre-existing error SC2328/SC2327 at `shellrc:990` (`pyenv virtualenv-init` redirect) is known; do not "fix" it blindly.
- `sh -n shellrc && bash -n shellrc` — syntax check.
- Runtime test requires an **interactive** shell: `main()` returns immediately on non-interactive shells, so `sh -c '. ./shellrc'` is a no-op. Use `bash -i`/`zsh -i`, or set the flags below.
- Useful dev flags: `SHELLRC_DEBUG=true` (times each step), `SHELLRC_VERBOSE=true` (progress), `SHELLRC_UPDATECHECK=false` (skip auto-update).

## Structure / conventions
- Whole file is wrapped in a `{ ... }` block so a partially-downloaded file does nothing; `main` is invoked once at the very end (`shellrc:2489`) then unset.
- All logic lives in functions:
  - `_shellrc_*` — persistent helpers, never unset.
  - `configure_*` — run once then `unset -f`.
  - `make_utility_functions` — defines the user-facing commands (`zap`, `list_all_binaries`, etc.).
- **Adding/removing a `configure_*` requires editing the ordered list inside `main()` (`shellrc:38-79`).** Order matters (e.g. `configure_PATH` first). Unlisted functions never run.
- `main()` runs under `set -euf` and restores `+euf` on success. Under `set -u`, reference possibly-unset vars as `${VAR:-}`.
- Every `configure_*` starts with a guard like `_shellrc_command X || return 0` so only installed tools are configured.

## Config-writing behavior
- `_shellrc_upsert_section` only touches content between `# BEGIN_SHELLRC` / `# END_SHELLRC` fences; markers must end the line (matched by `/BEGIN_SHELLRC[ \t]*$/`).
- It **skips** rewriting a section if the destination file is newer than `~/.shellrc` (`find "$_FILE" -newer "$(_shellrc_get_path)"`). Editing a generated file then re-sourcing may not overwrite it until the `.shellrc` timestamp is newer.
- `configure_bash`/`configure_zsh`/etc. append or prepend the fenced block depending on whether one already exists; existing user settings outside the fence are preserved.
- Runtime dir is `${XDG_CONFIG_HOME:-$HOME/.config}/shellrc`; snapshots go to `.../snapshots`. Auto-update runs at most every 24h.
- `shellrc update` / `shellrc revert` are the only user commands (see `shellrc()` dispatcher and `README.md`).

## Gotchas
- `_shellrc_get_version` uses `date -r`, a BSD/macOS form.
- `_shellrc_command_has_option <cmd> <opt>` caches scraped help text in `_options_cache_<cmd>`.
- `.shellrc` guards re-sourcing with `SHELLRC_SOURCED`; the updater resets it to `false` before re-sourcing.
- `configure_darwin`/`configure_linux` are Darwin/Linux-only branches; respect OS guards rather than assuming one platform.
