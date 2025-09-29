extends Node
class_name HealthComponent

signal on_unit_hit
signal on_health_changed(current: float, max: float)
signal on_unit_died


var max_health := 1.0
var current_health := 1.0

func setup(stat: UnitStats) -> void:
	max_health = stat.health
	current_health = max_health
	on_health_changed.emit(current_health, max_health)
	
func take_damage(value: float) -> void:
	if current_health <= 0:
		return
	
	current_health -= value
	current_health = max(current_health, 0.0)
	
	on_unit_hit.emit()
	on_health_changed.emit(current_health, max_health)
	
	if current_health == 0.0:
		on_unit_died.emit()
		die()
		
func die() -> void:
	owner.queue_free()
	
func heal(amount: float) -> void:
	if current_health <= 0:
		return
	
	current_health += amount
	current_health = min(current_health, max_health)
	on_health_changed.emit(current_health, max_health)
