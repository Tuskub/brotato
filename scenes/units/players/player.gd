extends Unit
class_name Player

@export var dash_duration := 0.5
@export var dash_speed_multi := 1.5
@export var dash_cooldown := 0.5

@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var collission: CollisionShape2D = $CollisionShape2D
@onready var trail: Trail = %Trail
@onready var weapon_container: WeaponContainer = $WeaponContainer

var current_weapons: Array[Weapon] = []

var move_dir: Vector2
var is_dashing := false
var is_dash_available := true 


func _ready() -> void:
	super._ready()
	dash_timer.one_shot = true
	dash_timer.wait_time = dash_duration
	
	dash_cooldown_timer.one_shot = true
	dash_cooldown_timer.wait_time = dash_cooldown
	
	#add_weapon(preload("uid://imimryc45lel"))
	#add_weapon(preload("uid://xa5yx3ou1hck"))
	#add_weapon(preload("uid://4sxp5j11l8yy"))
	#add_weapon(prelosad("uid://cus7cp8qtvf2x"))
	#add_weapon(preload("uid://d2iqgdh5dol7e"))


func _process(delta: float) -> void:
	if Global.game_paused:
		return
	
	move_dir = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	
	var current_velocity := move_dir * stats.speed
	
	if is_dashing:
		current_velocity *= dash_speed_multi
	
	position += current_velocity * delta
	position.x = clamp(position.x, -1000, 1000)
	position.y = clamp(position.y, -500, 500)
	
	if can_dash():
		start_dash()
	
	update_animations()
	update_rotation()


func update_animations() -> void:
	if move_dir.length() > 0:
		animation.play('move')
	else:
		animation.play('idle')


func update_rotation() -> void:
	if move_dir == Vector2.ZERO || move_dir.x == 0.0:
		return
	
	var direction = -1 if move_dir.x >= 0.1 else 1
	visuals.scale = Vector2(direction * 0.5, 0.5)
	

func start_dash() -> void:
	is_dashing = true
	dash_timer.start()
	trail.start_trail()
	visuals.modulate.a = 0.5
	collission.set_deferred("disabled", true)
	
func can_dash() -> bool:
	return not is_dashing and\
	dash_cooldown_timer.is_stopped() and\
	Input.is_action_just_pressed('dash') and\
	move_dir != Vector2.ZERO

func add_weapon(data: ItemWeapon) -> void:
	var weapon := data.scene.instantiate() as Weapon
	add_child(weapon)
	
	weapon.setup_weapon(data)
	current_weapons.append(weapon)
	weapon_container.update_weapons_position(current_weapons)

func is_facing_right() -> bool:
	return visuals.scale.x == -0.5
	
func update_player_new_wave() -> void:
	stats.health += stats.health_increase_pre_wave
	health_component.setup(stats)

func _on_dash_timer_timeout() -> void:
	is_dashing = false
	visuals.modulate.a = 1.0
	move_dir = Vector2.ZERO
	collission.set_deferred("disabled", false)
	dash_cooldown_timer.start()


func _on_hp_regen_timer_timeout() -> void:
	if health_component.current_health <= 0.0:
		return
	
	if health_component.current_health >= stats.health:
		return
	
	if (stats.hp_regen > 0.0):
		health_component.heal(stats.hp_regen)
		Global.on_create_heal_text.emit(self, stats.hp_regen)
		
