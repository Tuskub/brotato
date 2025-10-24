extends ItemBase
class_name  ItemPassive

@export var add_value: float
@export var add_stat: String

@export var remove_value: float
@export var remove_stat: String


func get_description() -> String:
	var discription:= "[code]"
	
	if add_value != 0:
		discription += "[color=green]+%s %s[/color]\n" % [add_value, add_stat]
	
	if remove_value != 0:
		discription += "[color=red]-%s %s[/color]\n" % [remove_value, remove_stat]

	discription += "[/code]"
	return discription

func apply_passive() -> void:
	if add_value != 0:
		Global.player.stats[add_stat] += add_value

	if remove_value != 0:
		Global.player.stats[remove_stat] -= remove_value
