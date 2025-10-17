extends WeaponBehavior
class_name RangeBehavior

@onready var muzzle: Marker2D = %Muzzle

func execute_attack() -> void:
	weapon.is_attacking = true
	
	crete_projectile()
	
	var tween := create_tween()
	var attack_pos := Vector2(weapon.attack_start_position.x - weapon.data.stats.recoil, weapon.attack_start_position.y)
	tween.tween_property(weapon.sprite, "position", attack_pos, weapon.data.stats.recoil_duration)
	tween.tween_property(weapon.sprite, "position", weapon.attack_start_position, weapon.data.stats.recoil_duration)
	
	apply_life_steal()
	
	await tween.finished
	weapon.is_attacking = false
	critical = false

func crete_projectile() -> void:
	var instance := weapon.data.stats.projectile_scene.instantiate() as Projectile
	get_tree().root.add_child(instance)
	instance.global_position = muzzle.global_position
	
	var velocity := Vector2.RIGHT.rotated(weapon.rotation) * weapon.data.stats.projectile_speed
	instance.set_projectile(velocity, get_damage(), critical, weapon.data.stats.knockback, weapon.get_parent())
