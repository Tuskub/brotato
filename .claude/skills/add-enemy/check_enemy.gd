extends Node
## Temporary check scene script for the add-enemy skill. Copy into the project root as
## _tmp_check.gd, run headless as a scene (autoloads are needed), then delete.

func _ready() -> void:
	var dir := "res://scenes/units/enemies/"
	for file in DirAccess.get_files_at(dir):
		if not file.begins_with("enemy_") or not file.ends_with(".tscn") or file == "enemy_base.tscn":
			continue
		var e := (load(dir + file) as PackedScene).instantiate() as Enemy
		add_child(e)
		var tex: String = e.sprite.texture.resource_path.get_file() if e.sprite.texture else "<none>"
		var stats_name: String = e.stats.name if e.stats else "<NO STATS>"
		print(file, ": stats=", stats_name, " hp=", e.health_component.max_health, " tex=", tex,
			" children=", e.get_children().map(func(c: Node) -> String: return c.name))
		e.queue_free()

	var arena := (load("res://scenes/arena/arena.tscn") as PackedScene).instantiate()
	var spawner := arena.get_node("Spawner") as Spawner
	add_child(arena)
	for w in [1, 2, 5]:
		spawner.wave_index = w
		spawner.scale_enemies_for_wave()
		print("wave ", w, ": ", spawner.enemy_collection.map(
			func(s: UnitStats) -> String: return "%s hp=%d dmg=%.1f" % [s.name, s.health, s.damage]))
	get_tree().quit()
