#!/usr/bin/env bash
# Standard verification for this Godot 4.5 project (see SKILL.md next to this file).
#
#   1. static reference scan (check_refs.py): missing files, wrong/unknown uids
#   2. headless boot of the main scene (or of a given scene), with the known noise
#      filtered out and real errors (SCRIPT ERROR, Parse Error, ERROR:, missing
#      resources) surfaced
#
# Usage: verify.sh [--import] [--no-refs] [--no-boot] [--strict] [--raw] [--timeout SEC] [res://scene.tscn]
#   res://scene.tscn  run this scene instead of the main scene; it must end with
#                     get_tree().quit(code) itself (run_harness.sh does this)
#   --import          run `godot --import` first: needed after adding a class_name,
#                     a script or an asset (automatic when .godot/ doesn't exist yet)
#   --strict          remaining (non-noise) warnings also fail
#   --raw             print the unfiltered Godot output as well
#   --timeout SEC     wall-clock cap for the Godot process (default 90)
# Exit: 0 ok, 1 real errors / non-zero Godot exit / timeout, 2 setup problem.
# Env:  GODOT (default /Applications/Godot.app/Contents/MacOS/Godot)

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

refs=1 boot=1 strict=0 raw=0 import=0 timeout=90 scene=""
while [ $# -gt 0 ]; do
	case "$1" in
		--import) import=1 ;;
		--no-refs) refs=0 ;;
		--no-boot) boot=0 ;;
		--strict) strict=1 ;;
		--raw) raw=1 ;;
		--timeout) shift; timeout="$1" ;;
		-h|--help) sed -n '2,/^$/p' "$0"; exit 0 ;;
		res://*) scene="$1" ;;
		*) echo "verify: unknown argument '$1'" >&2; exit 2 ;;
	esac
	shift
done

[ -f "$ROOT/project.godot" ] || { echo "verify: no project.godot in $ROOT" >&2; exit 2; }
status=0

# --- 1. static reference scan -------------------------------------------------
if [ $refs -eq 1 ]; then
	echo "== check_refs"
	strict_flag=""; [ $strict -eq 1 ] && strict_flag="--strict"
	python3 "$HERE/check_refs.py" --root "$ROOT" --summary $strict_flag || status=1
fi

[ $boot -eq 1 ] || exit $status

# --- 2. headless boot -----------------------------------------------------------
[ -x "$GODOT" ] || { echo "verify: Godot not found at $GODOT (set GODOT=...)" >&2; exit 2; }

LOG="$(mktemp -t godot-verify.XXXXXX)"
trap 'rm -f "$LOG"' EXIT

# Run Godot with a wall-clock cap (macOS has no `timeout`). Sets $rc; 124 = timed out.
# Usage: run_godot <cap seconds> <abort_on_script_error 0|1> <godot args...>
# A scene run that hits a SCRIPT ERROR never reaches its quit() and would idle until the
# cap, so scene runs are cut short 5s after the first SCRIPT ERROR.
run_godot() {
	local cap=$1 abort=$2; shift 2
	"$GODOT" --path "$ROOT" --headless "$@" >"$LOG" 2>&1 &
	local pid=$! waited=0 error_at=""
	rc=""
	while kill -0 "$pid" 2>/dev/null; do
		if [ "$abort" -eq 1 ] && [ -z "$error_at" ] && grep -q '^SCRIPT ERROR' "$LOG"; then
			error_at=$waited
		fi
		if [ "$waited" -ge "$cap" ] || { [ -n "$error_at" ] && [ $((waited - error_at)) -ge 5 ]; }; then
			kill -9 "$pid" 2>/dev/null
			{ wait "$pid"; } 2>/dev/null   # also hides bash's "Killed: 9" job notice
			rc=124
			echo "verify: killed after ${waited}s$([ -n "$error_at" ] && echo ' (SCRIPT ERROR, no quit)')" >>"$LOG"
			return 0
		fi
		sleep 1; waited=$((waited + 1))
	done
	wait "$pid"; rc=$?
	return 0
}

# Every import makes Godot 4.5 add its new default keys to the committed (4.4-era) .import
# files. Restore tracked .import files whose diff is nothing but those added keys.
CHURN_KEYS='^\+(compress/uastc_level|compress/rdo_quality_loss|process/channel_remap/(red|green|blue|alpha)|keep_rounding_remainders|modulate_color_glyphs)='
restore_import_churn() {
	git -C "$ROOT" rev-parse >/dev/null 2>&1 || return 0
	local f n=0
	while IFS= read -r -d '' f; do
		if ! git -C "$ROOT" diff -U0 -- "$f" | grep -E '^[-+]' | grep -vE '^(\+\+\+|---) ' | grep -qvE "$CHURN_KEYS"; then
			git -C "$ROOT" checkout -q -- "$f" && n=$((n + 1))
		fi
	done < <(git -C "$ROOT" diff --name-only -z -- '*.import')
	[ $n -gt 0 ] && echo "verify: restored $n .import file(s) that the import only padded with Godot 4.5 default keys"
	return 0
}

do_import() {
	run_godot $((timeout > 600 ? timeout : 600)) 0 --import   # a first full import is slow
	restore_import_churn
	if [ ! -f "$ROOT/.godot/uid_cache.bin" ]; then
		cat "$LOG"; echo "verify: import failed (rc=$rc)" >&2; exit 1
	fi
}

# A fresh checkout has no .godot/ (gitignored): without the uid cache every uid:// fails
# to resolve and the boot aborts with "Unrecognized UID" -- while still exiting 0.
# A new class_name, new script (.uid file) or new asset also needs an import before a
# plain run sees it ("Identifier "X" not declared in the current scope").
if [ ! -f "$ROOT/.godot/uid_cache.bin" ]; then
	echo "== no .godot/uid_cache.bin: importing the project first (one-time)"
	do_import
elif [ $import -eq 1 ]; then
	echo "== importing (registers new class_names, .uid files and assets)"
	do_import
fi

if [ -n "$scene" ]; then
	echo "== headless run of $scene"
	run_godot "$timeout" 1 "$scene"
else
	echo "== headless boot of the main scene"
	run_godot "$timeout" 0 --quit
fi

[ $raw -eq 1 ] && { echo "-- raw output"; cat "$LOG"; echo "-- end raw output"; }

# Godot prints a message line ("ERROR: ...", "SCRIPT ERROR: ...", "WARNING: ...") followed by
# indented "at:" / backtrace lines. Group them, drop the known noise, count the rest.
# One broken file cascades into hundreds of identical messages (every scene that loads it
# repeats them), so each distinct message is printed once, the first $max_shown at most:
# the first ones are usually the root cause.
max_shown=30
counts="$(awk -v strict="$strict" -v max_shown="$max_shown" '
	function flush() {
		if (rec == "") return
		if (rec ~ /invalid UID: .* - using text path instead/) noise_uid++
		else if (rec ~ /ObjectDB instances leaked at exit|resources still in use at exit|RIDs? of type .* leaked/) noise_exit++
		else {
			if (kind == "error") errors++; else warnings++
			if (!(head in seen)) {
				seen[head] = 1; unique++
				if (unique <= max_shown) printf "%s", rec
			}
		}
		rec = ""; kind = ""; head = ""
	}
	/^(SCRIPT |USER )?ERROR:|Parse Error|^(SCRIPT |USER )?WARNING:/ {
		flush()
		kind = ($0 ~ /WARNING:/ && $0 !~ /Parse Error/) ? "warning" : "error"
		# an override in an inherited scene whose node name/parent no longer matches the base
		if ($0 ~ /was modified from inside an instance, but it has vanished/) kind = "error"
		rec = $0 "\n"; head = $0; next
	}
	/^[ \t]+|^GDScript backtrace/ { if (rec != "") { rec = rec $0 "\n"; next } }
	{ flush() }
	/^Godot Engine v[0-9]/ || /^[ \t]*$/ { next }
	{ print }   # everything else is program output (print() from a harness)
	END {
		flush()
		if (unique > max_shown) printf "... %d more distinct message(s) not shown (--raw shows everything)\n", unique - max_shown
		printf "@@COUNTS %d %d %d %d %d\n", errors, warnings, unique, noise_uid, noise_exit
	}
' "$LOG")"

printf '%s\n' "$counts" | grep -v '^@@COUNTS'
read -r _ errors warnings unique noise_uid noise_exit <<<"$(printf '%s\n' "$counts" | grep '^@@COUNTS')"

echo "== result: $errors error(s), $warnings warning(s) ($unique distinct), godot exit $rc" \
	"(hidden noise: $noise_uid invalid-UID warning(s), $noise_exit exit-leak message(s))"

[ "$errors" -gt 0 ] && status=1
[ $strict -eq 1 ] && [ "$warnings" -gt 0 ] && status=1
if [ "$rc" -eq 124 ]; then
	echo "verify: Godot did not exit by itself. A scene run must end with get_tree().quit();" \
		"a SCRIPT ERROR before that line leaves it hanging (see the errors above)." >&2
	status=1
elif [ "$rc" -ne 0 ]; then
	status=1
fi
[ $status -eq 0 ] && echo "verify: OK" || echo "verify: FAILED"
exit $status
