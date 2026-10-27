---
name: godot-verify
description: Verify any change to this Godot 4.5 project before calling it done. Runs the static reference scan (missing files, wrong or unknown uid://, undeclared ExtResource/SubResource, typo'd signal handlers) and a headless boot with the known noise filtered out, so real SCRIPT ERROR / Parse Error / missing-resource lines stand out. Also covers the temporary-scene harness for testing game code with autoloads (Global, SoundManager, ProgressData), running the game and exporting. Use after editing any .gd, .tscn, .tres or project.godot file, when asked to test, check, validate, smoke-test, boot or run the game headless, debug "invalid UID", "Identifier not declared", "Failed loading resource" or parse errors, or before reporting a task as finished.
---

# Verifying a change

This project has no test suite. Verification means a static scan, a headless boot and, when game logic changed, a temporary harness scene. All three are scripted here:

| file | what it does |
|---|---|
| [verify.sh](verify.sh) | the standard check: `check_refs.py`, then a headless boot of the main scene (or of a given scene) with the noise filtered out. Exits 0 when OK, 1 on real errors |
| [check_refs.py](check_refs.py) | static scan of every `.tscn`/`.tres`/`.gd` plus `project.godot`. Needs no Godot and takes about 0.2s |
| [baseline.txt](baseline.txt) | pre-existing scan errors that are accepted, so only **new** problems fail |
| [run_harness.sh](run_harness.sh) | runs a check script as `res://_tmp_<prefix>_check.tscn` with autoloads loaded, then deletes it |
| [harness_template.gd](harness_template.gd) | starting point for a harness: loads and instantiates everything, then your asserts |

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot     # default in the scripts; override with GODOT=...
```

## 1. Run the standard check

```sh
.claude/skills/godot-verify/verify.sh                  # ~1–2s once .godot/ exists
.claude/skills/godot-verify/verify.sh --import         # after adding a class_name, a .gd file or an asset
```

Baseline on a clean `master` (recorded 2026-10-28, Godot 4.5.stable.official.876b29033). Anything beyond this comes from your change:

```
== check_refs
check_refs: 250 files, 316 uids known: 0 error(s), 1 known (baseline), 99 warning(s), 5 info (--verbose lists every line)
== headless boot of the main scene
== result: 0 error(s), 0 warning(s) (0 distinct), godot exit 0 (hidden noise: 48 invalid-UID warning(s), 2 exit-leak message(s))
verify: OK
```

Options: `--import`, `--no-refs`, `--no-boot`, `--strict` (warnings fail too), `--raw` (adds the unfiltered Godot log), `--timeout SEC` (default 90), or a `res://….tscn` to run instead of the main scene.

What verify.sh does for you, so you don't have to rediscover it:

- **It never trusts Godot's exit code.** `--headless --quit` exits 0 even when the boot aborts with `Unrecognized UID` or a script fails to compile, so verify.sh parses the output instead. Every `ERROR:`, `SCRIPT ERROR:`, `USER ERROR:` or `Parse Error` record (the line plus its indented `at:`/backtrace lines) counts as an error. A `WARNING:` counts as a warning, with one exception: `Node 'X' was modified from inside an instance, but it has vanished` counts as an error. It means an inherited-scene override no longer matches any node in the base.
- **It hides the known noise and counts it:**
  - `WARNING: res://…tres:4 - ext_resource, invalid UID: uid://… - using text path instead: …` and its `at: load (scene/resources/resource_format_text.cpp:444)` line. These are the 48 stale uids listed in section 2, and the load still works through the path.
  - `WARNING: ObjectDB instances leaked at exit` and `ERROR: 1 resources still in use at exit`. Both come from the exit-time leak and show up on every boot.
- **It dedupes cascades.** One broken scene repeats the same error for every scene that loads it, and a single broken projectile produced 817 errors in testing. Each distinct message prints once, at most 30 of them, in first-seen order, so the **first lines are the root cause**.
- **It imports a fresh checkout.** `.godot/` is gitignored. Without `.godot/uid_cache.bin`, every `uid://` fails (`ERROR: Unrecognized UID: "uid://kfh6ooeul77g"`, then `Couldn't detect whether to run the editor…`), so verify.sh runs `godot --headless --import` first.
- **It cleans up `.import` churn.** Every import makes Godot 4.5 add `compress/uastc_level`, `compress/rdo_quality_loss` and `process/channel_remap/*` to all 60 committed `.import` files (they are 4.4-era). verify.sh restores the tracked `.import` files whose diff contains only those keys and keeps real changes. If you ran `--import` or the editor yourself, use `git diff --name-only -z -- '*.import' | xargs -0 git checkout --` to drop the churn, but not a new asset's `.import`.
- **It has a time cap.** macOS has no `timeout`, so verify.sh uses a polling watchdog. A scene run is killed 5s after its first `SCRIPT ERROR`, because an errored `_ready()` never reaches `quit()` and would otherwise idle until the cap.

## 2. Read the static scan

`python3 .claude/skills/godot-verify/check_refs.py` (add `--verbose` for every line, or `--no-baseline` to include the accepted errors).

- **ERROR** (fails the run):
  - an `ext_resource` path that doesn't exist, or that differs only in letter case. macOS doesn't care about case, but exported `.pck` files do.
  - a uid that belongs to a *different* file than its `path`. Godot trusts the uid and loads the other file without any warning.
  - an undeclared or duplicate `ExtResource("id")` / `SubResource("id")`.
  - two files declaring the same uid.
  - a `preload("uid://…")` or `"res://…"` in a `.gd` file or in `project.godot` that doesn't resolve.
- **WARN**:
  - an unknown uid. Godot falls back to the path, and this is exactly the "invalid UID" boot noise.
  - a `metadata/_custom_type_script` uid that is unknown. This is editor metadata only.
  - a `[connection] method="…"` that no `func` in the project defines. Built-in targets such as `queue_free` would also show up here.
- **INFO**: an `ext_resource` without a uid (resolved by path, which is fine) and a `load_steps` value that doesn't match. `load_steps` is only a progress hint.

Known baseline warnings (pre-existing; leave them unless that's your task):

- 46 upgrade `.tres` files use `uid://cr0po024cxfg5` or `uid://0kfyb4qfa66q` for `item_upgrade.gd`, whose real uid is `uid://ti87pqqmd7ro`. These produce all 46 boot "invalid UID" warnings for `item_upgrade.gd`.
- `item_mace_2.tres` and `item_mace_4.tres` reference their stats with nonexistent uids. These are the other 2 boot warnings.
- 26 weapon `.tres` files have a stale `metadata/_custom_type_script` (`c7dropxg1o1hb`, `dt7tu5wgsfk5f`, `ru8ftjhq0b3f`).

The baseline error is in `item_mace_1.tres`: its uid points to `stats_mece_1.tres` while its path says `stats_mace_1.tres`, and Godot loads the **mece** file (damage 10, cooldown 2.0), as a harness confirmed. Fixing only the uid would silently drop Mace I to `stats_mace_1.tres` damage 1.0.

When you fix a baseline item, delete its line from `baseline.txt`. Stale lines are reported as INFO.

## 3. Test game code with a harness scene

Use a harness whenever the change has logic or data a boot doesn't exercise: an item's effect, a resource's values, spawner scaling, an `upgrade_to` chain.

**Why not `--script`?** `godot --headless --script foo.gd` does **not** load autoloads, so any script that touches `Global` (`enemy.gd`, `item_base.gd` with `Global.UpgradeTier`, and most of the game) fails with `Identifier "Global" not declared in the current scope`. A *scene* run loads autoloads. `--script` with `extends SceneTree` is still fine for engine-only snippets.

1. Copy the template outside the project, for example to your scratchpad: `cp .claude/skills/godot-verify/harness_template.gd "$SCRATCH/check.gd"`.
2. Keep or drop its generic smoke test. The smoke test `load()`s every `.tscn`/`.tres`/`.gd` (249 files) and `instantiate()`s every scene (50) without adding it to the tree. Then write your asserts with `check(cond, "what")`. The script must end with `get_tree().quit(1 if failures > 0 else 0)`.
3. Run it under a unique prefix. Parallel agents share this checkout, so use your task prefix:
   ```sh
   .claude/skills/godot-verify/run_harness.sh "$SCRATCH/check.gd" <prefix>
   ```
   This writes `res://_tmp_<prefix>_check.gd` and `.tscn`, runs `verify.sh --no-refs res://_tmp_<prefix>_check.tscn`, and deletes both files (plus any `.gd.uid`) on exit. It refuses to start if those files already exist. Exit 0 means the run was clean and every check passed.
4. Confirm that no `_tmp_<prefix>_*` files are left: `ls _tmp_*`. Never commit `_tmp_*` files.

Harness rules:

- `add_child(arena_instance)` runs the real `_ready()` chain. `Arena` shows `StartMenu` when `use_save_data` is on and `user://data.sav` exists, and otherwise shows `SelectionPanel`. Nothing is saved: `ProgressData.save_game()` runs only on `NOTIFICATION_WM_CLOSE_REQUEST` while the shop is open.
- `UnitStats` resources are shared and mutated in place (`Spawner.scale_enemies_for_wave()`, upgrades). A harness that mutates them affects every later load *within that run* only. Files on disk aren't touched unless you call `ResourceSaver.save`, so don't.
- `print()` output passes through the filter unchanged. `push_error()` counts as an error.
- Don't print to `user://` from a harness. It is the real game's data dir (`~/Library/Application Support/Godot/app_userdata/brotato/`, which holds the player's `data.sav`).
- Skill-specific harnesses already exist: `.claude/skills/add-enemy/check_enemy.gd` and the checks of the other `add-*` skills. Run them with `run_harness.sh <that file> <prefix>`.

Example: the check that confirmed the Mace I finding:

```gdscript
extends Node
func _ready() -> void:
	var m := load("res://resources/items/weapons/melee/mace/item_mace_1.tres") as ItemWeapon
	print("mace_1 stats -> ", m.stats.resource_path, " damage=", m.stats.damage)
	get_tree().quit(0)
# prints: mace_1 stats -> res://resources/items/weapons/melee/mace/stats_mece_1.tres damage=10.0
```

## 4. Import when Godot needs to learn about new files

A plain run reads the class and uid caches in `.godot/` and does not rescan the project. Run `verify.sh --import` (or `$GODOT --path . --headless --import`) after you:

- add a `class_name` or a new `.gd` file. Until you import, other scripts fail with `Parse Error: Identifier "NewClass" not declared in the current scope`, and the class isn't in `.godot/global_script_class_cache.cfg`.
- add a `.gd` file that needs a `.uid` file. Only the import or the editor writes `foo.gd.uid`, and you must commit that file with the script.
- add a PNG, audio file or font. The import writes `<asset>.import` with its `uid=`, which hand-written scenes need, and that file is committed too.

`--headless --quit` does none of this. A hand-written `.tres`/`.tscn` without a `uid=` stays without one after an import. The editor adds the uid when it re-saves the file. See the `godot-scene-editing` skill for writing uids yourself.

## 5. Run the game and export (needs the user or a GUI)

```sh
$GODOT --path .                                   # play the main scene (uid://dy355015qgab6 = scenes/arena/arena.tscn)
$GODOT --path . res://path/to/scene.tscn          # play one scene instead of the main scene
$GODOT --path . --editor                          # open the editor
$GODOT --path . --headless --export-release "macOS" ./brotato.dmg   # presets: "macOS", "Linux"
```

- Headless runs can't verify input, visuals, animations, tweens, enemy behaviors or the feel of combat. After those changes, ask the user to playtest and say exactly what to look at.
- `export_presets.cfg` is gitignored and **absent in a fresh checkout**, so the export fails until someone creates the presets in the editor (Project → Export). Export templates for `4.5.stable` are installed in `~/Library/Application Support/Godot/export_templates/`. `brotato.dmg` is a build artifact (`*.dmg` is gitignored), so don't commit it.

## Gotchas

- Godot's exit code is 0 for a broken boot. Read the output, or use verify.sh.
- In a scene run, the scene must call `get_tree().quit()`. A `SCRIPT ERROR` before that line leaves Godot idling (verify.sh reports `killed after Ns (SCRIPT ERROR, no quit)`).
- Several agents may run Godot in this checkout at the same time. Plain runs are safe, but give every temp file your own `_tmp_<prefix>_` name. check_refs and the template skip `_tmp_*` files, so another agent's harness can't fail your scan.
- Godot ignores hidden directories (`.claude/`, `.godot/`), so `.gd` files under `.claude/skills/` are not part of the project until they are copied into `res://`.
- Don't "fix" the noise by mass-editing uids during an unrelated task. Changing a uid can switch which file loads (see Mace I). Treat it as a separate, verified change.
