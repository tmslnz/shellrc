#!/bin/sh
#
# Tests for shellrc. Plain sh, no framework.
#
#   sh tests/run.sh             # every installed shell out of: dash bash zsh
#   sh tests/run.sh bash        # only the named shell(s)
#
# Each test_* function below runs in its own subshell with a throwaway $HOME
# that holds a copy of shellrc as ~/.shellrc, already sourced. Sourcing in a
# non-interactive shell defines every function and skips main().
#
# To add a test, write a test_* function that calls `fail` or `assert_*`.
#
# shellcheck disable=SC1090,SC1091,SC2013,SC2016,SC2030,SC2031,SC2034,SC2329

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
SRC=$ROOT/shellrc

# ******************************************************************************
# Outer runner: re-run this file under each shell
# ******************************************************************************

if test -z "${SHELLRC_TEST_SHELL:-}"; then
	test "$#" -gt 0 || set -- dash bash zsh
	ran=0
	rc=0
	for s in "$@"; do
		if ! command -v "$s" >/dev/null 2>&1; then
			echo "== $s: not installed, skipped"
			continue
		fi
		echo "== $s"
		ran=1
		SHELLRC_TEST_SHELL=$s "$s" "$0" || rc=1
	done
	test "$ran" = 1 || { echo "no shell to test with" >&2; exit 1; }
	exit "$rc"
fi

# ******************************************************************************
# Helpers
# ******************************************************************************

fail() {
	printf '    %s\n' "$*"
	FAILED=1
}

# assert_eq <expected> <actual> [label]
assert_eq() {
	test "$1" = "$2" && return 0
	fail "${3:-assert_eq}:"
	printf '%s\n' "$1" | sed 's/^/      expected | /'
	printf '%s\n' "$2" | sed 's/^/      actual   | /'
}

# assert_contains <haystack> <needle> [label]
assert_contains() {
	case "$1" in
	*"$2"*) ;;
	*) fail "${3:-assert_contains}: '$2' not found" ;;
	esac
}

# A fenced section with the given body
section() {
	printf '# BEGIN_SHELLRC\n%s\n# END_SHELLRC' "$1"
}

# Checksums of every file shellrc wrote a fenced section to
fenced_files_sum() {
	grep -rl 'BEGIN_SHELLRC' "$HOME" | grep -v '/\.shellrc$' | sort | xargs cksum
}

run_test() (
	FAILED=0
	HOME=$T_HOME
	export HOME
	unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME
	unset SHELLRC_SOURCED SHELLRC_DEBUG SHELLRC_VERBOSE SHELLRC_FILE SHELLRC_CONFIG_DIR
	SHELLRC_UPDATECHECK=false
	cp "$SRC" "$HOME/.shellrc" || exit 1
	cd "$HOME" || exit 1
	# main() runs the configure_* functions under set -u, so test under it too
	set -u
	. "$HOME/.shellrc"
	"$1"
	test "$FAILED" = 0
)

# ******************************************************************************
# Structure
# ******************************************************************************

test_main_list_matches_defined_functions() {
	listed=$(awk '
		/^main\(\) \{/ { m = 1 }
		m && /<<-.EOF.$/ { h = 1; next }
		h && /^[ \t]*EOF$/ { exit }
		h { print $1 }' "$SRC")
	test -n "$listed" || fail "could not read the function list in main()"
	undefined=$(printf '%s\n' "$listed" | while read -r f; do
		grep -q "^$f() {" "$SRC" || echo "$f"
	done)
	assert_eq "" "$undefined" "listed in main() but not defined"
	unlisted=$(grep -oE '^configure_[A-Za-z0-9_]+' "$SRC" | while read -r f; do
		printf '%s\n' "$listed" | grep -qx "$f" || echo "$f"
	done)
	assert_eq "" "$unlisted" "defined but missing from the list in main()"
}

# ******************************************************************************
# _shellrc_upsert_section
# ******************************************************************************

test_upsert_creates_missing_file() {
	_SHELLRC_REVISION=rev1
	_shellrc_upsert_section "$(section one)" "$HOME/a/b/conf" append
	assert_eq "$(printf '# BEGIN_SHELLRC\n# shellrc-revision: rev1\none\n# END_SHELLRC')" \
		"$(cat "$HOME/a/b/conf")"
}

test_upsert_appends_and_prepends() {
	_SHELLRC_REVISION=rev1
	echo user >"$HOME/app"
	echo user >"$HOME/pre"
	_shellrc_upsert_section "$(section one)" "$HOME/app" append
	_shellrc_upsert_section "$(section one)" "$HOME/pre" prepend
	assert_eq "$(printf 'user\n# BEGIN_SHELLRC\n# shellrc-revision: rev1\none\n# END_SHELLRC')" \
		"$(cat "$HOME/app")" append
	assert_eq "$(printf '# BEGIN_SHELLRC\n# shellrc-revision: rev1\none\n# END_SHELLRC\nuser')" \
		"$(cat "$HOME/pre")" prepend
}

test_upsert_rewrites_only_inside_the_fence() {
	_SHELLRC_REVISION=rev1
	echo before >"$HOME/conf"
	_shellrc_upsert_section "$(section one)" "$HOME/conf" append
	echo after >>"$HOME/conf"
	_SHELLRC_REVISION=rev2
	_shellrc_upsert_section "$(section two)" "$HOME/conf" append
	assert_eq "$(printf 'before\n# BEGIN_SHELLRC\n# shellrc-revision: rev2\ntwo\n# END_SHELLRC\nafter')" \
		"$(cat "$HOME/conf")"
}

test_upsert_skips_section_at_current_revision() {
	_SHELLRC_REVISION=rev1
	_shellrc_upsert_section "$(section one)" "$HOME/conf" append
	sed 's/^one$/edited/' "$HOME/conf" >"$HOME/conf.tmp" && mv "$HOME/conf.tmp" "$HOME/conf"
	_shellrc_upsert_section "$(section two)" "$HOME/conf" append
	assert_contains "$(cat "$HOME/conf")" edited "same revision keeps local edit"
	_SHELLRC_REVISION=rev2
	_shellrc_upsert_section "$(section two)" "$HOME/conf" append
	case "$(cat "$HOME/conf")" in
	*edited*) fail "new revision should overwrite the local edit" ;;
	esac
}

test_upsert_stamp_uses_comment_syntax_of_the_fence() {
	_SHELLRC_REVISION=rev1
	_shellrc_upsert_section "$(printf '" BEGIN_SHELLRC\nset nu\n" END_SHELLRC')" "$HOME/vimrc" append
	assert_eq '" shellrc-revision: rev1' "$(sed -n 2p "$HOME/vimrc")"
}

test_upsert_rejects_missing_args() {
	if _shellrc_upsert_section "$(section one)" 2>/dev/null; then
		fail "expected a non-zero status"
	fi
}

# ******************************************************************************
# Other helpers
# ******************************************************************************

test_get_revision_is_cached_content_hash() {
	_shellrc_get_revision >/dev/null
	r1=$_SHELLRC_REVISION
	assert_eq "$(cksum <"$HOME/.shellrc" | awk '{ print $1 "-" $2 }')" "$r1"
	echo "# changed" >>"$HOME/.shellrc"
	_shellrc_get_revision >/dev/null
	assert_eq "$r1" "$_SHELLRC_REVISION" "cached value survives a file change"
	unset _SHELLRC_REVISION
	_shellrc_get_revision >/dev/null
	test "$r1" != "$_SHELLRC_REVISION" || fail "revision should change with the content"
}

test_restore_options_reapplies_all_of_them() {
	_SHELLRC_OPTIONS=euf
	set +u +f
	_shellrc_restore_options
	opts=$-
	set +e +f
	case "$opts" in *e*) ;; *) fail "-e not restored" ;; esac
	case "$opts" in *u*) ;; *) fail "-u not restored" ;; esac
	case "$opts" in *f*) ;; *) fail "-f not restored" ;; esac
	# After main() the saved options are gone and user commands change nothing
	unset _SHELLRC_OPTIONS
	_shellrc_restore_options
	opts=$-
	set +e +f
	case "$opts" in *[ef]*) fail "options set without saved state: $opts" ;; esac
}

test_config_dir_defaults_to_dot_config() {
	_shellrc_set_SHELLRC_CONFIG_DIR
	assert_eq "$HOME/.config/shellrc" "$SHELLRC_CONFIG_DIR"
	test -d "$SHELLRC_CONFIG_DIR" || fail "directory not created"
}

test_config_dir_honours_xdg_and_migrates_old_snapshots() {
	XDG_CONFIG_HOME=$HOME/xdg
	mkdir -p "$XDG_CONFIG_HOME/snapshots"
	echo "# old" >"$XDG_CONFIG_HOME/snapshots/.shellrc-2020-01-01T000000"
	_shellrc_set_SHELLRC_CONFIG_DIR
	assert_eq "$HOME/xdg/shellrc" "$SHELLRC_CONFIG_DIR"
	test -f "$HOME/xdg/shellrc/snapshots/.shellrc-2020-01-01T000000" || fail "snapshot not moved"
	test ! -d "$HOME/xdg/snapshots" || fail "old snapshots directory left behind"
}

test_locale_hint_keeps_the_sed_backreference() {
	locale() { :; } # pretend no UTF-8 locale is installed
	assert_contains "$(configure_locale)" '/\1/' "sed hint"
}

test_append_and_prepend_PATH() {
	mkdir "$HOME/x" "$HOME/y"
	base=$PATH
	_shellrc_append_PATH "$HOME/x"
	assert_eq "$base:$HOME/x" "$PATH" append
	_shellrc_append_PATH "$HOME/x"
	assert_eq "$base:$HOME/x" "$PATH" "append twice keeps one entry"
	_shellrc_prepend_PATH "$HOME/y"
	assert_eq "$HOME/y:$base:$HOME/x" "$PATH" prepend
	_shellrc_prepend_PATH "$HOME/x"
	assert_eq "$HOME/x:$HOME/y:$base" "$PATH" "prepend moves an existing entry"
	_shellrc_append_PATH "$HOME/missing"
	assert_eq "$HOME/x:$HOME/y:$base" "$PATH" "missing directory is ignored"
}

test_command_detection() {
	_shellrc_command sh || fail "sh should be found"
	if _shellrc_command shellrc-no-such-command; then fail "unknown command found"; fi
	if _shellrc_command; then fail "no argument should be an error"; fi
}

test_command_has_option() {
	mkdir "$HOME/fakebin"
	printf '#!/bin/sh\necho "usage: fakecmd [--colour]"\n' >"$HOME/fakebin/fakecmd"
	chmod +x "$HOME/fakebin/fakecmd"
	PATH="$HOME/fakebin:$PATH"
	_shellrc_command_has_option fakecmd --colour || fail "--colour should be found"
	if _shellrc_command_has_option fakecmd --nope; then fail "--nope should be absent"; fi
	assert_contains "${_options_cache_fakecmd:-}" "usage: fakecmd" "help text cache"
}

test_shellrc_dispatcher() {
	assert_contains "$(shellrc help)" "shellrc update" help
	case "$(shellrc version)" in
	????-??-??T??:??:??Z) ;;
	*) fail "unexpected version: $(shellrc version)" ;;
	esac
	shellrc help >/dev/null
	assert_eq false "$SHELLRC_VERBOSE" "SHELLRC_VERBOSE restored"
}

test_revert_restores_last_snapshot() {
	mkdir -p "$HOME/.config/shellrc/snapshots"
	echo "# old" >"$HOME/.config/shellrc/snapshots/.shellrc-2020-01-01T000000"
	_shellrc_revert >/dev/null
	assert_eq "# old" "$(cat "$HOME/.shellrc")"
}

# ******************************************************************************
# Smoke test: a real interactive run of main() against the throwaway $HOME.
# Covers whichever tools are installed on this machine.
# ******************************************************************************

test_interactive_run() {
	script='. ~/.shellrc
		echo "rc=$? sourced=${SHELLRC_SOURCED:-} agent=${SSH_AGENT_PID:-}"
		case $- in *[euf]*) echo "options-not-restored=$-" ;; esac
		test -n "${_SHELLRC_OPTIONS:-}" && echo "leftover=_SHELLRC_OPTIONS"
		for f in main configure_PATH configure_git make_utility_functions; do
			command -v "$f" >/dev/null 2>&1 && echo "leftover=$f"
		done
		command -v shellrc >/dev/null 2>&1 && echo dispatcher=ok'
	smoke() {
		env -i HOME="$HOME" PATH="$PATH" TERM=xterm SHELLRC_UPDATECHECK=false \
			"$SHELLRC_TEST_SHELL" -i -c "$script" </dev/null 2>&1
	}
	out=$(smoke)
	sum1=$(fenced_files_sum)
	out2=$(smoke)
	sum2=$(fenced_files_sum)
	# configure_ssh may start an agent; do not leave it behind
	printf '%s\n%s\n' "$out" "$out2" | sed -n 's/.* agent=\([0-9][0-9]*\)$/\1/p' | sort -u |
		while read -r pid; do kill "$pid" 2>/dev/null; done

	assert_contains "$out" "rc=0 sourced=true" "first run"
	assert_contains "$out2" "rc=0 sourced=true" "second run"
	assert_contains "$out" "dispatcher=ok" "shellrc command defined"
	case "$out" in
	*options-not-restored=* | *leftover=*) fail "main() left state behind" ;;
	esac
	test -n "$sum1" || fail "no config file received a fenced section"
	assert_eq "$sum1" "$sum2" "second run must not rewrite fenced sections"
	test "$FAILED" = 0 || printf '%s\n' "$out" | sed 's/^/      output   | /'
}

# ******************************************************************************
# Inner runner
# ******************************************************************************

passed=0
failed=0
for t in $(grep -oE '^test_[A-Za-z0-9_]+' "$0"); do
	T_HOME=$(mktemp -d "${TMPDIR:-/tmp}/shellrc-test.XXXXXX") || exit 1
	if out=$(run_test "$t" 2>&1); then
		passed=$((passed + 1))
		echo "  ok    $t"
	else
		failed=$((failed + 1))
		echo "  FAIL  $t"
		test -z "$out" || printf '%s\n' "$out"
	fi
	rm -rf "$T_HOME"
done
echo "  $passed passed, $failed failed"
test "$failed" = 0
