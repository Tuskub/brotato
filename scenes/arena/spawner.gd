extends Node2D
class_name Spawner

signal on_wave_complited

@export var spawn_area_size := Vector2(1000, 500)
@export var wave_data: Array[WaveDate]
@export var enemy_collection: Array[UnitStats]

@onready var spawn_timer: Timer = $SpawnTimer
@onready var wave_timer: Timer = $WaveTimer

var wave_index := 1
var current_wave_data: WaveDate
var spawned_enemies: Array[Enemy]

func find_wave_data() -> WaveDate:
	for wave in wave_data:
		if wave and wave.is_valid_index(wave_index):
			return wave
	
	return null
	
func set_spawn_timer() -> void:
	match current_wave_data.spawn_type:
		WaveDate.SpawnType.FIXED:
			spawn_timer.wait_time = current_wave_data.fixsed_spawn_time
		WaveDate.SpawnType.RANDOM:
			var min_spawn_time := current_wave_data.min_spawn_time
			var max_spawn_time := current_wave_data.max_spawn_time
			spawn_timer.wait_time = randf_range(min_spawn_time, max_spawn_time)
	
	if spawn_timer.is_stopped():
		spawn_timer.start()

func get_rand_spawn_pos() -> Vector2:
	var random_x := randf_range(-spawn_area_size.x, spawn_area_size.x)
	var random_y := randf_range(-spawn_area_size.y, spawn_area_size.y)
	return Vector2(random_x, random_y)

func spawn_enemy() -> void:
	var enemy_scene := current_wave_data.get_rand_unit_scene() as PackedScene
	if enemy_scene:
		var enemy_instance := enemy_scene.instantiate() as Enemy
		enemy_instance.global_position = get_rand_spawn_pos()
		get_parent().add_child(enemy_instance)
		spawned_enemies.append(enemy_instance)
		
	set_spawn_timer()

func udpates_enemies_new_wave() -> void:
	for stat: UnitStats in enemy_collection:
		stat.health += stat.health_increase_pre_wave
		stat.damage += stat.damege_increase_pre_wave

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
	Global.game_paused = true
	udpates_enemies_new_wave()
