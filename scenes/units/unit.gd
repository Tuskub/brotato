extends Node2D
class_name Unit

@export var stats: UnitStats

@onready var visuals: Node2D = %Visuals
@onready var sprite: Node2D = %Sprite
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var health_component: HealthComponent =$HealthComponent
@onready var flash_timer: Timer = $FlashTimer

func _ready() -> void:
	health_component.setup(stats)

func set_flush_material() -> void:
	sprite.material = Global.FLASH_MATERIAL
	flash_timer.start()

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	if health_component.current_health <= 0.0:
		return
	
	set_flush_material()
	health_component.take_damage(hitbox.damage)


func _on_flash_timer_timeout() -> void:
	sprite.material = null
