extends Panel
class_name UpgradePanel

const UPGRADE_CARD = preload("uid://bfohai4xgom8w")
@onready var items_container: HBoxContainer = %ItemsContainer

@export var upgrade_list: Array[ItemUpgrade]

func _ready() -> void:
	load_upgrades()

func load_upgrades() -> void:
	for child in items_container.get_children():
		child.queue_free()
	
	for i in 4:
		var random_upgrade := upgrade_list.pick_random() as ItemUpgrade
		var card_instance :=  UPGRADE_CARD.instantiate() as UpgradeCard
		items_container.add_child(card_instance)
		card_instance.item_data = random_upgrade
