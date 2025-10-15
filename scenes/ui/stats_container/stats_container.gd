extends Panel
class_name StatsContainer

@onready var health_label: Label = %HealthLabel
@onready var hp_regen_label: Label = %HPRegenLabel
@onready var life_steal_label: Label = %LifeStealLabel
@onready var damage_label: Label = %DamageLabel
@onready var luck_label: Label = %LuckLabel
@onready var speed_label: Label = %SpeedLabel
@onready var block_label: Label = %BlockLabel
@onready var harvesting_label: Label = %HarvestingLabel


func	 _process(delta: float) -> void:
	var player := Global.player
	if not is_instance_valid(Global.player):
		return
	
	var stast = player.stats
	health_label.text = str(stast.health)
	hp_regen_label.text = str(stast.hp_regen)
	life_steal_label.text = str(stast.life_steal) + '%'
	damage_label.text = str(stast.damage)
	luck_label.text = str(stast.luck) + '%'
	speed_label.text = str(stast.speed)
	block_label.text = str(stast.block_chance) + '%'
	harvesting_label.text = str(stast.harvesting)
