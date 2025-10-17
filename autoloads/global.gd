extends Node

signal on_create_block_text(unit: Node2D)
signal on_create_damage_text(unit: Node2D, hitbox: HitboxComponent)
signal on_create_heal_text(unit: Node2D, heal: float)

signal on_upgrade_selected

enum UpgradeTier {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

const UPGRADE_PRPBABILITY_CONFIG = {
	"rare": { "start_wave": 2, 'base_multi': 0.06 },
	"epic": { "start_wave": 4, 'base_multi': 0.02 },
	"legendary": { "start_wave": 7, 'base_multi': 0.0023 },
}

var player: Player
var game_paused := false
var coins: int

const FLASH_MATERIAL = preload("uid://x4frie3idpxo")
const FLOATING_TEXT_SCENE = preload("uid://qkwyrg22h3gi")

const COMMON_STYLE = preload("uid://dt8ypn0hibm80")
const EPIC_STYLE = preload("uid://ccifgx30nsp4h")
const LEGENDARY_STYLE = preload("uid://dnnhiwx3gx5h0")
const RARE_STYLE = preload("uid://ici2d08626ar")

func get_harvesting_coins() -> void:
	coins += player.stats.harvesting
	

func get_chance_succes(chance: float) -> bool:
	var random := randf_range(0.0, 1.0)
	return random < chance

func calculate_tier_probability(current_wave: int, config: Dictionary) -> Array[float]:
	var common_chance := 0.0
	var rare_chance := 0.0
	var epic_chance := 0.0
	var legendary_chance := 0.0
	
	if current_wave >= config.rare.start_wave:
		rare_chance = min(1.0, (current_wave - config.rare.start_wave + 1) * config.rare.base_multi)
		
	if current_wave >= config.epic.start_wave:
		epic_chance = min(1.0, (current_wave - config.epic.start_wave + 1) * config.epic.base_multi)
		
	if current_wave >= config.legendary.start_wave:
		legendary_chance = min(1.0, (current_wave - config.legendary.start_wave + 1) * config.legendary.base_multi)
		
	
	# Player luck incrising the chance of finding higher tier
	var luck_factor := 1.0 + (Global.player.stats.luck / 100)
	rare_chance *= luck_factor
	epic_chance *= luck_factor
	legendary_chance *= luck_factor
	
	# Normalize probabilities
	var total_non_common_chances := rare_chance + epic_chance + legendary_chance
	
	if total_non_common_chances > 1.0:
		var scale_down := 1.0 / total_non_common_chances
		rare_chance *= scale_down
		epic_chance *= scale_down
		legendary_chance *= scale_down
		total_non_common_chances = 1.0
		
	# Common takes the remaining probability
	common_chance = 1.0 - total_non_common_chances
	
	# Debug print:
	print("Wave: %d, Luck: %.1f => Chances: C:%.2f, R:%.3f, E:%.4f, L:%5f " % 
	[current_wave, Global.player.stats.luck, common_chance, rare_chance, epic_chance, legendary_chance])
	
	return [
		max(0.0, common_chance),
		max(0.0, rare_chance),
		max(0.0, epic_chance),
		max(0.0, legendary_chance)
	]

func select_items_from_offer(item_pool: Array, current_wave: int, config: Dictionary) -> Array:
	var tier_chances = calculate_tier_probability(current_wave, config)
	
	var legendary_limit = tier_chances[3]
	var epic_limit = legendary_limit + tier_chances[2]
	var rare_limit = epic_limit + tier_chances[1]
	
	var offered_items: Array = []
	while  offered_items.size() < 4:
		var roll := randf()
		var chosen_tier_index := 0
		if roll < legendary_limit:
			chosen_tier_index = 3 # Legendary
		elif roll < epic_limit:
			chosen_tier_index = 2 # Epic
		elif roll < rare_limit:
			chosen_tier_index = 1 # Rare
		else:
			chosen_tier_index = 0 # Common
			
		var potential_items: Array = []
		var current_search_tier_index := chosen_tier_index
		
		while potential_items.is_empty() and current_search_tier_index >= 0:
			potential_items = item_pool.filter(func(item: ItemBase): return item.item_tier == current_search_tier_index)
			
			if potential_items.is_empty():
				current_search_tier_index -= 1
			else:
				break
		
		if not potential_items.is_empty():
			var selected_item = potential_items.pick_random()
			
			if not offered_items.has(selected_item):
				offered_items.append(selected_item)
	
	return offered_items

func get_tier_style(tier: UpgradeTier) -> StyleBoxFlat:
	match tier:
		UpgradeTier.COMMON:
			return COMMON_STYLE
		UpgradeTier.RARE:
			return RARE_STYLE
		UpgradeTier.EPIC:
			return EPIC_STYLE
		_:
			return LEGENDARY_STYLE
