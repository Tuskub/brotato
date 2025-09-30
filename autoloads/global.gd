extends Node

var player: Player
const  FLASH_MATERIAL = preload("uid://x4frie3idpxo")

func get_chance_succes(chance: float) -> bool:
	var random := randf_range(0.0, 1.0)
	return random < chance
