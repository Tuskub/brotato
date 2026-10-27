extends Node
## Temporary check scene script for the add-item skill. Copy into the project root,
## run headless as a scene (autoloads are needed: ItemBase uses Global.UpgradeTier), then delete.
## Exits with code 1 if any check fails.

const ITEMS_DIR := "res://resources/items/"
const UPGRADE_PANEL := "res://scenes/ui/upgrade_panel/upgrage_panel.tscn"
const SHOP_PANEL := "res://scenes/ui/shop_panel/shop_panel.tscn"

var errors := 0


func _ready() -> void:
	var stat_names := get_numeric_stat_names()
	print("UnitStats numeric stats: ", stat_names)

	var upgrade_panel := (load(UPGRADE_PANEL) as PackedScene).instantiate() as UpgradePanel
	var shop_panel := (load(SHOP_PANEL) as PackedScene).instantiate() as ShopPanel
	var upgrade_pool: Array = upgrade_panel.upgrade_list.map(func(i: ItemBase) -> String: return i.resource_path)
	var shop_pool: Array = shop_panel.shop_items.map(func(i: ItemBase) -> String: return i.resource_path)
	upgrade_panel.free()
	shop_panel.free()

	var count := 0
	for path in find_tres(ITEMS_DIR):
		var item := load(path) as ItemBase
		if item == null or item is ItemWeapon:
			continue
		count += 1
		var pools: Array[String] = []
		if path in upgrade_pool:
			pools.append("upgrade_list")
		if path in shop_pool:
			pools.append("shop_items")

		var effect := ""
		if item is ItemUpgrade:
			var upgrade := item as ItemUpgrade
			effect = "%s +%s" % [upgrade.stat_id, upgrade.value]
			check_stat(path, "stat_id", upgrade.stat_id, upgrade.value, stat_names)
			check(item.item_type == ItemBase.ItemType.UPGRADE, path, "item_type must be UPGRADE (1)")
			check(pools == ["upgrade_list"], path, "ItemUpgrade must be in upgrade_list only (ShopPanel can't buy upgrades)")
			check(upgrade.description != "", path, "description is empty (UpgradeCard shows only this text)")
		elif item is ItemPassive:
			var passive := item as ItemPassive
			effect = "+%s %s" % [passive.add_value, passive.add_stat]
			if passive.remove_value != 0.0:
				effect += " / -%s %s" % [passive.remove_value, passive.remove_stat]
			check_stat(path, "add_stat", passive.add_stat, passive.add_value, stat_names)
			check_stat(path, "remove_stat", passive.remove_stat, passive.remove_value, stat_names)
			check(item.item_type == ItemBase.ItemType.PASSIVE, path, "item_type must be PASSIVE (2)")
			check(pools == ["shop_items"], path, "ItemPassive must be in shop_items only")
			check(item.item_cost > 0, path, "item_cost is 0, the passive is free in the shop")
		else:
			check(false, path, "unknown ItemBase subclass")

		check(item.item_name != "", path, "item_name is empty")
		check(item.item_icon != null, path, "item_icon is missing")
		print("%s | %s | %s | %s | cost=%d | pools=%s" % [path.trim_prefix(ITEMS_DIR), item.get_script().get_global_name(),
			Global.UpgradeTier.keys()[item.item_tier], effect, item.item_cost, pools])

	for path in upgrade_pool + shop_pool:
		check(ResourceLoader.exists(path), path, "pool references a missing resource")

	print("checked %d upgrade/passive items, %d error(s)" % [count, errors])
	get_tree().quit(1 if errors > 0 else 0)


## Names of the int/float script properties of UnitStats: the only valid targets for
## ItemUpgrade.stat_id and ItemPassive.add_stat / remove_stat.
func get_numeric_stat_names() -> Array[String]:
	var names: Array[String] = []
	for prop in (load("res://resources/units/unit_stats.gd") as Script).get_script_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.type in [TYPE_INT, TYPE_FLOAT]:
			names.append(prop.name)
	return names


func check_stat(path: String, field: String, stat: String, value: float, stat_names: Array[String]) -> void:
	if stat == "" and value == 0.0:
		return
	check(stat in stat_names, path, "%s = \"%s\" is not a numeric UnitStats property" % [field, stat])
	check(value != 0.0, path, "%s = \"%s\" but its value is 0, so it is never applied" % [field, stat])
	check(stat != "type", path, "%s = \"type\" is the UnitType enum, not a gameplay stat" % field)
	# Same arithmetic as ItemUpgrade.apply_upgrade(), on a throwaway UnitStats.
	if stat in stat_names:
		var stats := UnitStats.new()
		var before := float(stats.get(stat))
		stats.set(stat, before + value)
		var applied := float(stats.get(stat)) - before
		if not is_equal_approx(applied, value):
			print("TRUNCATED %s: %s is an int stat, %s applies as %s" % [path, stat, value, applied])


func check(ok: bool, path: String, message: String) -> void:
	if not ok:
		errors += 1
		printerr("ERROR %s: %s" % [path, message])


func find_tres(dir: String) -> Array[String]:
	var result: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		result.append_array(find_tres(dir + sub + "/"))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			result.append(dir + file)
	return result
