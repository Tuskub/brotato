extends Node
## Temporary check scene for the godot-verify skill. Copy it somewhere outside res://
## (e.g. your scratchpad), edit the "task-specific checks" section, and run it with
##   .claude/skills/godot-verify/run_harness.sh <copy>.gd <prefix>
## which places it at res://_tmp_<prefix>_check.gd, runs it headless with autoloads, and
## deletes it again. Exit code 1 (and "FAIL" lines) when any check fails.

var failures := 0


func _ready() -> void:
	# --- generic smoke test: every scene/resource/script in the project loads -------
	# load() compiles scripts and resolves every ext_resource, so a broken uid, a missing
	# file or a parse error anywhere shows up here as a null result plus an ERROR line.
	var paths := _collect("res://")
	var scenes := 0
	for path in paths:
		var res := load(path)
		check(res != null, "loads: " + path)
		if res is PackedScene:
			# instantiate() builds the node tree (catches bad node paths / inherited-scene
			# parents) without adding it to the tree, so no _ready() of game code runs.
			var node := (res as PackedScene).instantiate()
			check(node != null, "instantiates: " + path)
			if node:
				node.free()
			scenes += 1
	print("smoke: %d files loaded, %d scenes instantiated" % [paths.size(), scenes])

	# --- task-specific checks (replace with your own) --------------------------------
	# Autoloads work here: Global, SoundManager, ProgressData.
	check(Global.available_player.size() > 0, "Global.available_player is populated")
	var sword := load("res://resources/items/weapons/melee/sword/item_sword_1.tres") as ItemWeapon
	check(sword != null and sword.upgrade_to != null, "Sword I has an upgrade_to")
	# Running real game code: add the arena to the tree, then poke it.
	#   var arena := (load("res://scenes/arena/arena.tscn") as PackedScene).instantiate() as Arena
	#   add_child(arena)            # runs Arena._ready() and its children's _ready()
	#   arena.spawner.wave_index = 3
	# Remember: UnitStats resources are shared and mutated at runtime, and nothing here is
	# saved (ProgressData only saves on a window close request with the shop open).

	print("harness: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		return  # print("  ok   ", what) if you want the passing lines too
	failures += 1
	print("  FAIL ", what)


func _collect(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):  # .godot, .claude, ... (Godot ignores hidden dirs)
			out.append_array(_collect(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.begins_with("_tmp_"):
			continue  # this harness and other agents' harnesses
		if file.get_extension() in ["tscn", "tres", "gd"]:
			out.append(dir.path_join(file))
	return out
