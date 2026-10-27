extends Node
## Temporary check scene script for the add-character skill. Copy into the project root,
## run headless as a scene (autoloads are needed for Global.available_player), then delete.
## Exits with code 1 if any check fails.

const PLAYERS_DIR := "res://resources/units/players/"
const SELECTION_PANEL := "res://scenes/ui/selection_panel/selection_panel.tscn"
const BASE_PLAYER_SCENE := "res://scenes/units/players/player_well_rounded.tscn"

var errors := 0


func _ready() -> void:
	var panel := (load(SELECTION_PANEL) as PackedScene).instantiate() as SelectionPanel
	var selectable: Array = panel.players.map(func(s: UnitStats) -> String: return s.resource_path)
	var start_weapons: Array[ItemWeapon] = panel.start_weapon.duplicate()
	panel.free()

	# Every player stats resource: the SelectionPanel looks its name up in Global.available_player.
	var stats_paths: Array[String] = []
	for file in DirAccess.get_files_at(PLAYERS_DIR):
		if not file.ends_with(".tres"):
			continue
		var path := PLAYERS_DIR + file
		stats_paths.append(path)
		var stats := load(path) as UnitStats
		if stats == null:
			check(false, path, "is not a UnitStats resource")
			continue
		check(stats.type == UnitStats.UnitType.PLAYER, path, "type must be PLAYER (0)")
		check(stats.icon != null, path, "icon is missing (SelectionCard and the info panel show it)")
		check(path in selectable, path, "not in SelectionPanel.players, so it can't be picked")
		var has_scene := Global.available_player.has(stats.name)
		check(has_scene, path, "name \"%s\" has no Global.available_player entry" % stats.name)
		var scene_info := "<no scene>"
		if has_scene:
			scene_info = check_player_scene(stats.name, path)
		print("%s | name=\"%s\" | hp=%d dmg=%s speed=%d luck=%s block=%s regen=%s steal=%s harvest=%s +hp/wave=%s | %s" % [
			file, stats.name, stats.health, stats.damage, stats.speed, stats.luck, stats.block_chance,
			stats.hp_regen, stats.life_steal, stats.harvesting, stats.health_increase_pre_wave, scene_info])

	for path: String in selectable:
		check(path in stats_paths, path, "SelectionPanel.players entry is outside " + PLAYERS_DIR)

	# Every Global.available_player entry must be backed by a stats resource with the same name.
	for key: String in Global.available_player:
		var found := stats_paths.any(func(p: String) -> bool: return (load(p) as UnitStats).name == key)
		check(found, "Global.available_player[\"%s\"]" % key, "no UnitStats in %s has this name" % PLAYERS_DIR)

	for weapon in start_weapons:
		check(weapon != null and weapon.scene != null, SELECTION_PANEL, "start_weapon entry without a scene")
	print("start weapons (shared by all characters): ", start_weapons.map(func(w: ItemWeapon) -> String: return w.item_name))

	print("checked %d characters, %d available_player entries, %d error(s)" % [stats_paths.size(), Global.available_player.size(), errors])
	get_tree().quit(1 if errors > 0 else 0)


## Instantiates the scene registered for this name (without adding it to the tree) and checks
## that it is a Player using the very same stats resource the SelectionPanel showed.
func check_player_scene(key: String, stats_path: String) -> String:
	var scene := Global.available_player[key]
	var node := scene.instantiate()
	var info := scene.resource_path.get_file()
	if node is Player:
		var player := node as Player
		var player_stats_path := player.stats.resource_path if player.stats else "<none>"
		check(player_stats_path == stats_path, scene.resource_path,
			"stats is %s, but the selected character is %s" % [player_stats_path, stats_path])
		var base := scene.get_state().get_node_instance(0)
		var base_path := base.resource_path if base else "<not inherited>"
		check(base_path == BASE_PLAYER_SCENE or scene.resource_path == BASE_PLAYER_SCENE, scene.resource_path,
			"should inherit %s (inherits %s)" % [BASE_PLAYER_SCENE, base_path])
		var tex := player.get_node("Visuals/Sprite") as Sprite2D
		info += " tex=" + (tex.texture.resource_path.get_file() if tex.texture else "<none>")
		check(player.has_node("WeaponContainer/Six"), scene.resource_path, "WeaponContainer markers One..Six missing")
	else:
		check(false, scene.resource_path, "root node is not a Player")
	node.free()
	return info


func check(ok: bool, path: String, message: String) -> void:
	if not ok:
		errors += 1
		printerr("ERROR %s: %s" % [path, message])
