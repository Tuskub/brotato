extends Node

signal on_create_block_text(unit: Node2D)
signal on_create_damage_text(unit: Node2D, hitbox: HitboxComponent)

enum UpgradeTier {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

var player: Player
const  FLASH_MATERIAL = preload("uid://x4frie3idpxo")
const FLOATING_TEXT_SCENE = preload("uid://qkwyrg22h3gi")

func get_chance_succes(chance: float) -> bool:
	var random := randf_range(0.0, 1.0)
	return random < chance
