extends Panel
class_name UpgradePanel

const UPGRADE_CARD = preload("uid://bfohai4xgom8w")
@onready var items_container: HBoxContainer = %ItemsContainer

@export var upgrade_list: Array[ItemUpgrade]

func load_upgrades(current_wave: int) -> void:
	for child in items_container.get_children():
		child.queue_free()
	
	var config := Global.UPGRADE_PRPBABILITY_CONFIG
	var selected_upgrades := Global.select_items_from_offer(upgrade_list, current_wave, config)
	for random_upgrade: ItemUpgrade in selected_upgrades:
		var card_instance :=  UPGRADE_CARD.instantiate() as UpgradeCard
		items_container.add_child(card_instance)
		card_instance.item_data = random_upgrade
