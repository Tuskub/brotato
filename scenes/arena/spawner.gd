extends Node2D
class_name Spawner

signal on_wave_complited

@export var spawn_area_size := Vector2(1000, 500)
@export var wave_data: Array[WaveDate]
@export var enemy_collection: Array[UnitStats]
@export_group("Endless")
## Spawn time is multiplied by (1 - this) for every wave past the last defined WaveDate.
@export_range(0.0, 1.0) var endless_spawn_time_decrease := 0.05
## Lower bound for the endless spawn time multiplier.
@export_range(0.01, 1.0) var endless_min_spawn_multiplier := 0.25

@onready var spawn_timer: Timer = $SpawnTimer
@onready var wave_timer: Timer = $WaveTimer

var wave_index := 1
var current_wave_data: WaveDate
var spawned_enemies: Array[Enemy]
## Wave 1 health/damage of every UnitStats in enemy_collection, captured before any scaling.
var enemy_base_stats: Dictionary[UnitStats, Dictionary] = {}

func _ready() -> void:
	for stat: UnitStats in enemy_collection:
		enemy_base_stats[stat] = {"health": stat.health, "damage": stat.damage}

func find_wave_data() -> WaveDate:
	for wave in wave_data:
		if wave and wave.is_valid_index(wave_index):
			return wave
	
	# Endless mode: past the last defined wave, keep reusing the last one
	return get_last_wave_data()

func get_last_wave_data() -> WaveDate:
	var last_wave: WaveDate = null
	for wave in wave_data:
		if wave and (not last_wave or wave.to > last_wave.to):
			last_wave = wave
	
	return last_wave

func get_endless_wave_count() -> int:
	var last_wave := get_last_wave_data()
	if not last_wave:
		return 0
	return max(0, wave_index - last_wave.to)

func is_endless_wave() -> bool:
	return get_endless_wave_count() > 0

func get_endless_spawn_multiplier() -> float:
	var multiplier := pow(1.0 - endless_spawn_time_decrease, get_endless_wave_count())
	return max(endless_min_spawn_multiplier, multiplier)
	
func set_spawn_timer() -> void:
	match current_wave_data.spawn_type:
		WaveDate.SpawnType.FIXED:
			spawn_timer.wait_time = current_wave_data.fixsed_spawn_time
		WaveDate.SpawnType.RANDOM:
			var min_spawn_time := current_wave_data.min_spawn_time
			var max_spawn_time := current_wave_data.max_spawn_time
			spawn_timer.wait_time = randf_range(min_spawn_time, max_spawn_time)
	
	spawn_timer.wait_time *= get_endless_spawn_multiplier()
	
	if spawn_timer.is_stopped():
		spawn_timer.start()

func get_rand_spawn_pos() -> Vector2:
	var random_x := randf_range(-spawn_area_size.x, spawn_area_size.x)
	var random_y := randf_range(-spawn_area_size.y, spawn_area_size.y)
	return Vector2(random_x, random_y)

func spawn_enemy() -> void:
	var enemy_scene := current_wave_data.get_rand_unit_scene() as PackedScene
	if enemy_scene:
		var spawn_pos := get_rand_spawn_pos()
		
		var spawn_anim := Global.ENEMY_SPAWN_EFFECT_SCENE.instantiate()
		get_parent().add_child(spawn_anim)
		spawn_anim.global_position = spawn_pos
		set_spawn_timer()
		await spawn_anim.animation_player.animation_finished
		spawn_anim.queue_free()
		
		var enemy_instance := enemy_scene.instantiate() as Enemy
		enemy_instance.global_position = spawn_pos
		get_parent().add_child(enemy_instance)
		spawned_enemies.append(enemy_instance)
		


## Sets enemy stats from their wave 1 values, so it also works after loading a save mid-run.
func scale_enemies_for_wave() -> void:
	var waves_passed := wave_index - 1
	for stat: UnitStats in enemy_collection:
		var base: Dictionary = enemy_base_stats[stat]
		stat.health = base.health + int(stat.health_increase_pre_wave * waves_passed)
		stat.damage = base.damage + stat.damege_increase_pre_wave * waves_passed

func clear_enemies() -> void:
	if spawned_enemies.size() > 0:
		for enemy: Enemy in spawned_enemies:
			if is_instance_valid(enemy):
				enemy.destroy_enemy()
	
	spawned_enemies.clear()

func start_wave() -> void:
	current_wave_data = find_wave_data()
	if not current_wave_data:
		printerr('no valid wave')
		spawn_timer.stop()
		wave_timer.stop()
		return
	
	#enemy_collection = []
	#for unit: WaveUnitData in current_wave_data.units:
		#var enemy := unit.unit_scene
		#enemy_collection.append(enemy)
	scale_enemies_for_wave()
	wave_timer.wait_time = current_wave_data.wave_time
	wave_timer.start()
	
	set_spawn_timer()
	
func get_wave_text() -> String:
	return "Wave %s" % wave_index
	
func get_wave_timer_text() -> String:
	return str(max(0, int(wave_timer.time_left)))


func _on_spawn_timer_timeout() -> void:
	if not current_wave_data or wave_timer.is_stopped():
		spawn_timer.stop()
		return
	
	spawn_enemy()


func _on_wave_timer_timeout() -> void:
	spawn_timer.stop()
	on_wave_complited.emit()
	clear_enemies()
	Global.get_harvesting_coins()
	Global.game_paused = true
