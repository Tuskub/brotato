#!/usr/bin/env bash
# Run a GDScript check inside the real project (autoloads loaded), then clean up.
#
# Usage: run_harness.sh <check.gd> <prefix> [verify.sh options]
#   check.gd  a script that `extends Node`, does its checks in _ready() and ends with
#             get_tree().quit(<0 ok | 1 failed>)  (start from harness_template.gd)
#   prefix    short worker/task prefix; files are res://_tmp_<prefix>_check.{gd,tscn}
#             so parallel agents in the same checkout don't collide
#
# Why: `godot --script foo.gd` does NOT load autoloads, so anything touching Global,
# SoundManager or ProgressData fails to compile there. A scene run does load them.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"

[ $# -ge 2 ] || { sed -n '2,10p' "$0"; exit 2; }
src="$1" prefix="$2"; shift 2
[ -f "$src" ] || { echo "run_harness: no such file: $src" >&2; exit 2; }
case "$prefix" in *[!a-z0-9_]*|"") echo "run_harness: prefix must be [a-z0-9_]+" >&2; exit 2 ;; esac

name="_tmp_${prefix}_check"
gd="$ROOT/$name.gd" tscn="$ROOT/$name.tscn"
if [ -e "$gd" ] || [ -e "$tscn" ]; then
	echo "run_harness: $name.* already exists (another run in progress, or a leftover)." \
		"Delete it or pick another prefix." >&2
	exit 2
fi

cleanup() { rm -f "$gd" "$gd.uid" "$tscn"; }
trap cleanup EXIT INT TERM

cp "$src" "$gd"
printf '[gd_scene format=3]\n\n[ext_resource type="Script" path="res://%s.gd" id="1"]\n\n[node name="Check" type="Node"]\nscript = ExtResource("1")\n' \
	"$name" >"$tscn"

"$HERE/verify.sh" --no-refs "$@" "res://$name.tscn"
