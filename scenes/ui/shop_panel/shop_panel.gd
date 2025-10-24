extends Panel
class_name ShopPanel

const SHOP_CARD_SCENE = preload("uid://3aptedc0ypht")

signal on_shop_next_wave

@export var shop_items: Array[ItemBase]

@onready var items_container: HBoxContainer = %ItemsContainer
@onready var passives_container: GridContainer = %PassivesContainer
@onready var weapons_container: GridContainer = %WeaponsContainer
@onready var combine_button: Button = %CombineButton

var contecst_card: ItemCard

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
		card_instance.on_item_purchased.connect(_on_item_purchased)
		items_container.add_child(card_instance) 
		card_instance.shop_item = shop_item
 
func create_item_card() -> ItemCard:
	var item_card := Global.ITEM_CARD_SCENE.instantiate() as ItemCard
	item_card.on_item_card_selected.connect(_on_item_card_selected)
	return item_card
	
func _on_item_card_selected(card: ItemCard) -> void:
	contecst_card = card
	
	var can_merge := false
	
	if card.item.item_type == ItemBase.ItemType.WEAPON:
		var count := 0
		for weapon: ItemWeapon in Global.equipped_weapons:
			if weapon.item_name == card.item.item_name:
				count += 1
				
			if count >= 2:
				can_merge = true
		
		combine_button.disabled = not can_merge

func _on_item_purchased(item: ItemBase) -> void:
	var item_card := create_item_card()
	
	if item.item_type == ItemBase.ItemType.WEAPON:
		weapons_container.add_child(item_card)
		var weapon := item as ItemWeapon
		Global.player.add_weapon(weapon)
		Global.equipped_weapons.append(weapon)
	
	if item.item_type == ItemBase.ItemType.PASSIVE:
		passives_container.add_child(item_card)
		var passive := item as ItemPassive
		passive.apply_passive()
	
	item_card.item = item

func _on_new_wave_button_pressed() -> void:
	on_shop_next_wave.emit()


func _on_combine_button_pressed() -> void:
	if not contecst_card: 
		return
	
	var clicked_weapon := contecst_card.item as ItemWeapon
	if not clicked_weapon.upgrade_to: 
		return
	
	var weapons_to_remove: Array[Weapon] = Global.player.current_weapons.filter(func(w: Weapon): 
		return w.data.item_name == clicked_weapon.item_name).slice(0, 2)
	var card_to_remove := weapons_container.get_children().filter(func(c: ItemCard): 
		return c.item.item_name == clicked_weapon.item_name).slice(0, 2)
		
	if weapons_to_remove.size() < 2 and card_to_remove.size() < 2:
		return
	
	# Delete weapons
	
	for weapon: Weapon in weapons_to_remove:
		Global.player.current_weapons.erase(weapon)
		Global.equipped_weapons.erase(weapon.data)
		weapon.queue_free()
		
	for card: ItemCard in card_to_remove:
		card.queue_free()
	
	# Create new weapon
	
	var upgraded_weapon: ItemWeapon = load(clicked_weapon.upgrade_to.resource_path)
	Global.player.add_weapon(upgraded_weapon)
	Global.equipped_weapons.append(upgraded_weapon)
	
	# Create new item card
	var new_card = create_item_card()
	weapons_container.add_child(new_card)
	
	new_card.item = upgraded_weapon
	
	contecst_card = null


func _on_sell_button_pressed() -> void:
	if not contecst_card:
		return
	
	var clicked_weapon := contecst_card.item as ItemWeapon
	
	var coins := int(clicked_weapon.item_cost * 0.75)
	
	var weapon_to_remove : Weapon = Global.player.current_weapons.filter(func (w: Weapon): 
		return w.data.item_name == clicked_weapon.item_name).front()
	
	if weapon_to_remove:
		Global.player.current_weapons.erase(weapon_to_remove)
		Global.equipped_weapons.erase(weapon_to_remove.data)
		weapon_to_remove.queue_free()
		
	contecst_card.queue_free()
	contecst_card = null
	
	Global.coins += coins
