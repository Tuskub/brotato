extends Node2D
class_name Weapon

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = %CollisionShape2D
@onready var cooldown_timer: Timer = $CooldownTimer

var data: ItemWeapon
var is_attacking := false
var attack_start_position: Vector2
var targets: Array[Enemy]
var closest_target: Enemy
var weapon_spred: float


func _ready() -> void:
	attack_start_position = sprite.position

func setup_weapon(data: ItemWeapon) -> void:
	self.data = data
	collision.shape.radius = data.stats.max_range

func gun_use_weapon() -> bool:
	return cooldown_timer.is_stopped() and closest_target


func _on_range_area_area_entered(area: Area2D) -> void:
	targets.push_back(area)


func _on_range_area_area_exited(area: Area2D) -> void:
	targets.erase(area)
	if targets.size() == 0:
		closest_target = null
