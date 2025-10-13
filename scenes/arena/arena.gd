extends Node2D
class_name Arena

@export var player: Player
@export var normal_color: Color
@export var block_color: Color
@export var critical_color: Color
@export var hp_color: Color

@onready var wave_index_label: Label = %WaveIndexLabel
@onready var wave_time_label: Label = %WaveTimeLabel
@onready var spawner: Spawner = $Spawner

func _ready() -> void:
	Global.player = player
	Global.on_create_block_text.connect(_on_create_block_text)
	Global.on_create_damage_text.connect(_on_create_damage_text)

func _process(delta: float) -> void:
	if Global.game_paused:
		return
	wave_index_label.text = spawner.get_wave_text()
	wave_time_label.text = spawner.get_wave_timer_text()

	
func create_floating_text(unit: Node2D) -> FloatingText:
	var instance := Global.FLOATING_TEXT_SCENE.instantiate() as FloatingText
	get_tree().root.add_child(instance)
	var random_position := randf_range(0, TAU) * 35
	var spawn_position := unit.global_position + Vector2.RIGHT.rotated(random_position)
	instance.global_position = spawn_position
	return instance
	

func _on_create_block_text(unit: Node2D) -> void:
	var text := create_floating_text(unit)
	text.setup("Blocked!", block_color)
	
func _on_create_damage_text(unit: Node2D, hitbox: HitboxComponent) -> void:
	var text := create_floating_text(unit)
	var color := critical_color if hitbox.critical else normal_color
	text.setup(str(hitbox.damage), color)
	
