extends WeaponBehavior
class_name RangeBehavior

@onready var muzzle: Marker2D = %Muzzle

func execute_attack() -> void:
	weapon.is_attacking = true
	
	print('shoot')
	
	var tween := create_tween()
	var attack_pos := Vector2(weapon.attack_start_position.x - weapon.data.stats.recoil, weapon.attack_start_position.y)
	tween.tween_property(weapon.sprite, "position", attack_pos, weapon.data.stats.recoil_duration)
	tween.tween_property(weapon.sprite, "position", weapon.attack_start_position, weapon.data.stats.recoil_duration)
	
	await tween.finished
	weapon.is_attacking = false
	critical = false
