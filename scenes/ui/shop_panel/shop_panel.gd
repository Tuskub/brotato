extends Panel
class_name ShopPanel

const SHOP_CARD_SCENE = preload("uid://3aptedc0ypht")

signal on_shop_next_wave

@export var shop_items: Array[ItemBase]

@onready var items_container: HBoxContainer = %ItemsContainer
@onready var passives_container: GridContainer = %PassivesContainer
@onready var weapons_container: GridContainer = %WeaponsContainer

func _ready() -> void:
	for child in passives_container.get_children():
		child.queue_free()

	for child in weapons_container.get_children():
		child.queue_free()
	
func load_shop(current_wave: int) -> void:
	for child in items_container.get_children():
		child.queue_free()
	
	var config := Global.SHOP_PRPBABILITY_CONFIG
	var selected_items := Global.select_items_from_offer(shop_items, current_wave, config)
	
	for shop_item: ItemBase in selected_items:
		var card_instance := SHOP_CARD_SCENE.instantiate() as ShopCard
		items_container.add_child(card_instance) 
		card_instance.shop_item = shop_item
 

func _on_new_wave_button_pressed() -> void:
	on_shop_next_wave.emit()
