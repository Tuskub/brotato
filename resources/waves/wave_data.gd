extends Resource
class_name WaveDate

enum SpawnType {
	FIXED,
	RANDOM
}

@export var from: int
@export var to: int
@export var wave_time := 20.0
@export var spawn_type := SpawnType.RANDOM

@export var units: Array[WaveUnitData]
@export var fixsed_spawn_time := 1.0
@export var min_spawn_time := 1.0
@export var max_spawn_time := 1.0


func get_rand_unit_scene() -> PackedScene:
	if units.is_empty():
		printerr('no units')
		return null
	
	var enemies: Array[PackedScene]
	var weights: Array[float]
	
	for i in units:
		enemies.append(i.unit_scene)
		weights.append(i.weight)
		
	var rng := RandomNumberGenerator.new()
	var random_unit = enemies[rng.rand_weighted(weights)]
	return random_unit
	
func is_valid_index(index: int) -> bool:
	return index >= from and index <= to
