extends Panel
class_name UpgradeCard

@export var item_data: ItemUpgrade: set = _set_data

@onready var item_icon: TextureRect = %Icon
@onready var item_name: Label = %Name
@onready var item_description: Label = %Description

func _set_data(value: ItemUpgrade) -> void:
	item_data = value
	item_icon.texture = item_data.item_icon
	item_name.text = item_data.item_name
	item_description.text = item_data.description
	
