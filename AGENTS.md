# AGENTS.md

`shellrc` is the entire product: a single-file POSIX `sh` script installed to `~/.shellrc`. There is no build or package manager; `make` runs the linters and the tests in `tests/run.sh`. Indentation is tabs; the file targets `sh` with Bash/Zsh compatibility. Plain `sh` support means the file parses and sources without errors on restricted shells (e.g. `dash`); it does not mean feature parity. Gate Bash/Zsh-only features behind `_shellrc_is_bash`/`_shellrc_is_zsh` and do not build `sh` emulations of them. See "Shell compatibility" in `README.md`.

## Verify changes
- `make` — runs everything below (`make lint`, `make test`). Shells and `shellcheck` that are not installed are skipped, so read the output.
- `sh tests/run.sh [shell ...]` — plain-`sh` tests, run under each of `dash`, `bash`, `zsh`. Unit tests source `shellrc` non-interactively (defines every function, skips `main()`) in a throwaway `$HOME`; `test_interactive_run` runs `main()` for real with `<shell> -i` and covers only the tools installed on the machine. Add a `test_*` function when changing a `_shellrc_*` helper.
- `shellcheck shellrc` — primary linter. Some shellcheck versions report SC2328/SC2327 on the `eval "$(pyenv virtualenv-init - 2>/dev/null)"` line in `configure_pyenv` (0.9.0 reports nothing). It is known; do not "fix" it blindly.
- `dash -n shellrc && bash -n shellrc && zsh -n shellrc` — syntax check. Use `dash` explicitly: `sh` is Bash on macOS, so `sh -n` there misses POSIX parse errors.
- Runtime test requires an **interactive** shell: `main()` returns immediately on non-interactive shells, so `sh -c '. ./shellrc'` is a no-op. Use `bash -i`/`zsh -i`, or set the flags below.
- Useful dev flags: `SHELLRC_DEBUG=true` (times each step), `SHELLRC_VERBOSE=true` (progress), `SHELLRC_UPDATECHECK=false` (skip auto-update).

## Structure / conventions
- Whole file is wrapped in a `{ ... }` block so a partially-downloaded file does nothing; `main` is invoked once at the very end of the file, then unset.
- All logic lives in functions:
  - `_shellrc_*` — persistent helpers, never unset.
  - `configure_*` — run once then `unset -f`.
  - `make_utility_functions` — defines the user-facing commands (`zap`, `list_all_binaries`, etc.).
- **Adding/removing a `configure_*` requires editing the ordered list (the heredoc inside `main()`).** Order matters (e.g. `configure_PATH` first). Unlisted functions never run.
- `main()` runs under `set -euf` and restores `+euf` on success. Under `set -u`, reference possibly-unset vars as `${VAR:-}`.
- Every `configure_*` starts with a guard like `_shellrc_command X || return 0` so only installed tools are configured.

## Config-writing behavior
- `_shellrc_upsert_section` only touches content between `# BEGIN_SHELLRC` / `# END_SHELLRC` fences; markers must end the line (matched by `/BEGIN_SHELLRC[ \t]*$/`).
- Each fenced section is stamped with a `shellrc-revision: <cksum>` line (CRC + byte count of `~/.shellrc`; see `_shellrc_get_revision`). A section is skipped when its stamp matches the current revision, otherwise it is rewritten. The old mtime guard (`find "$_FILE" -newer ...`) was removed, so edits inside a fence are preserved only until the revision changes.
- `_shellrc_get_revision` caches in `_SHELLRC_REVISION`; `_shellrc_update` unsets it before re-sourcing so the new content is hashed.
- `configure_bash`/`configure_zsh`/etc. append or prepend the fenced block depending on whether one already exists; existing user settings outside the fence are preserved.
- Runtime dir is `${XDG_CONFIG_HOME:-$HOME/.config}/shellrc`; snapshots go to `.../snapshots`. Auto-update runs at most every 24h.
- `shellrc update` / `shellrc revert` are the only user commands (see `shellrc()` dispatcher and `README.md`).

## Gotchas
- `_shellrc_get_version` uses `date -r`, a BSD/macOS form.
- `_shellrc_command_has_option <cmd> <opt>` caches scraped help text in `_options_cache_<cmd>`.
- `.shellrc` guards re-sourcing with `SHELLRC_SOURCED` (any non-empty value returns); the updater unsets it before re-sourcing so the new file runs `main()` in the current shell.
- `configure_darwin`/`configure_linux` are Darwin/Linux-only branches; respect OS guards rather than assuming one platform.
