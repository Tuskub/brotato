extends Node
## Temporary check scene script for the add-weapon skill. Copy into the project root as
## _tmp_wpn_check.gd, run headless as a scene (autoloads are needed), then delete.
## With no user args it checks every item_*.tres under res://resources/items/weapons/.
## Pass specific files after `--`: ... res://_tmp_wpn_check.tscn -- res://resources/items/weapons/melee/sword/item_sword_1.tres

const WEAPONS_DIR := "res://resources/items/weapons/"
const SHOP_PANEL_SCENE := "res://scenes/ui/shop_panel/shop_panel.tscn"
const SELECTION_PANEL_SCENE := "res://scenes/ui/selection_panel/selection_panel.tscn"
const PLAYER_HITBOX_LAYER := 16   # layer 5 HitboxPlayer
const ENEMY_HURTBOX_MASK := 8     # layer 4 HurtboxEnemy

var errors := 0
var warnings := 0
var range_shapes: Array[Shape2D] = []


func _ready() -> void:
	Global.game_paused = true   # Weapon._process reads Global.player, which is null here

	var paths := Array(OS.get_cmdline_user_args())
	if paths.is_empty():
		paths = find_items(WEAPONS_DIR)
	paths.sort()

	var shop_panel := (load(SHOP_PANEL_SCENE) as PackedScene).instantiate() as ShopPanel
	var selection_panel := (load(SELECTION_PANEL_SCENE) as PackedScene).instantiate() as SelectionPanel
	var names := {}

	for path: String in paths:
		var item := load(path) as ItemWeapon
		if item == null:
			fail(path, "does not load as ItemWeapon")
			continue
		if names.has(item.item_name):
			fail(path, "item_name '%s' is also used by %s (combining matches by name)" % [item.item_name, names[item.item_name]])
		names[item.item_name] = path

		check_item(path, item)
		check_chain(path, item)
		check_registration(path, item, shop_panel, selection_panel)

	if range_shapes.size() > 1 and range_shapes.all(func(s: Shape2D) -> bool: return s == range_shapes[0]):
		warn("all weapons", "RangeArea CircleShape2D is shared between instances; setup_weapon() radius of the last weapon wins")

	shop_panel.free()
	selection_panel.free()
	print("checked %d items: %d errors, %d warnings" % [paths.size(), errors, warnings])
	get_tree().quit(1 if errors > 0 else 0)


func find_items(dir: String) -> Array:
	var result := []
	for sub in DirAccess.get_directories_at(dir):
		result.append_array(find_items(dir + sub + "/"))
	for file in DirAccess.get_files_at(dir):
		if file.begins_with("item_") and file.ends_with(".tres"):
			result.append(dir + file)
	return result


func check_item(path: String, item: ItemWeapon) -> void:
	var s := item.stats
	if item.item_type != ItemBase.ItemType.WEAPON:
		fail(path, "item_type is %s, must be WEAPON (0)" % ItemBase.ItemType.keys()[item.item_type])
	if item.item_icon == null:
		fail(path, "item_icon is not set")
	if item.item_cost <= 0:
		warn(path, "item_cost is %d" % item.item_cost)
	if s == null:
		fail(path, "stats is not set")
		return
	if item.scene == null:
		fail(path, "scene is not set")
		return

	if s.damage <= 0.0 or s.max_range <= 0.0:
		fail(path, "damage and max_range must be > 0")
	if s.cooldown <= 0.0:
		fail(path, "cooldown must be > 0 (CooldownTimer.wait_time)")
	if s.accuracy < 0.0 or s.accuracy > 1.0 or s.crit_chance < 0.0 or s.crit_chance > 1.0:
		fail(path, "accuracy and crit_chance must be in 0..1")

	var weapon := item.scene.instantiate() as Weapon
	if weapon == null:
		fail(path, "scene root is not a Weapon (inherit weapon_base.tscn)")
		return
	add_child(weapon)
	weapon.setup_weapon(item)

	var kind := "?"
	var behavior := weapon.weapon_behavior
	if behavior == null:
		fail(path, "WeaponBehavior node has no WeaponBehavior script")
	elif behavior.weapon != weapon:
		fail(path, "WeaponBehavior.weapon is not set to NodePath(\"..\")")

	if behavior is MeleeBehavior:
		kind = "melee"
		check_melee(path, weapon, behavior as MeleeBehavior)
	elif behavior is RangeBehavior:
		kind = "range"
		check_range(path, weapon, item)

	var expected_type := ItemWeapon.WeaponType.RANGE if kind == "range" else ItemWeapon.WeaponType.MELEE
	if item.type != expected_type:
		warn(path, "type is %s but behavior is %s (type is unused by code)" % [ItemWeapon.WeaponType.keys()[item.type], kind])

	if weapon.sprite.texture == null:
		fail(path, "Sprite2D has no texture")
	if not is_equal_approx(weapon.collision.shape.radius, s.max_range):
		fail(path, "RangeArea radius %.0f != max_range %.0f" % [weapon.collision.shape.radius, s.max_range])
	range_shapes.append(weapon.collision.shape)

	if item.item_tier == Global.UpgradeTier.COMMON:
		if weapon.sprite.material != null:
			fail(path, "COMMON weapon still has an outline material")
	else:
		var mat := weapon.sprite.material as ShaderMaterial
		if mat == null:
			fail(path, "non-common weapon needs the base outline ShaderMaterial on Sprite2D")
		elif mat.get_shader_parameter("outline_color") != Global.TIER_COLORS[item.item_tier]:
			fail(path, "outline_color does not match Global.TIER_COLORS")

	print("%s: %s %s tier=%s scene=%s dmg=%s cd=%s range=%s crit=%d%%x%s kb=%s ls=%s acc=%s cost=%d -> %s" % [
		path.get_file(), item.item_name, kind, Global.UpgradeTier.keys()[item.item_tier],
		item.scene.resource_path.get_file(), s.damage, s.cooldown, s.max_range, roundi(s.crit_chance * 100),
		s.crit_damage, s.knockback, s.life_steal, s.accuracy, item.item_cost,
		item.upgrade_to.item_name if item.upgrade_to else "-"])
	weapon.free()


func check_melee(path: String, weapon: Weapon, behavior: MeleeBehavior) -> void:
	var hitbox := behavior.hitbox
	if hitbox == null:
		fail(path, "MeleeBehavior.hitbox is not set")
		return
	check_hitbox(path, hitbox, "melee hitbox")
	if hitbox.monitorable:
		warn(path, "melee hitbox starts monitorable; it hurts enemies before the first swing (set monitoring/monitorable = false like weapon_punch.tscn)")


func check_range(path: String, weapon: Weapon, item: ItemWeapon) -> void:
	if weapon.get_node_or_null("%Muzzle") as Marker2D == null:
		fail(path, "range weapon needs a unique-name Marker2D %Muzzle under Sprite2D")
	var scene := item.stats.projectile_scene
	if scene == null:
		fail(path, "stats.projectile_scene is not set")
		return
	if item.stats.projectile_speed <= 0.0:
		fail(path, "projectile_speed must be > 0")
	var projectile := scene.instantiate() as Projectile
	if projectile == null:
		fail(path, "projectile_scene root is not a Projectile")
		return
	if projectile.hitbox == null:
		fail(path, "projectile has no hitbox export set")
	else:
		check_hitbox(path, projectile.hitbox, "projectile hitbox")
		if not projectile.hitbox.on_hit_hurtbox.is_connected(projectile._on_hitbox_component_on_hit_hurtbox):
			warn(path, "projectile does not free itself on hit (on_hit_hurtbox not connected)")
	if projectile.find_children("*", "VisibleOnScreenNotifier2D").is_empty():
		fail(path, "projectile has no VisibleOnScreenNotifier2D, it is never freed")
	projectile.free()


func check_hitbox(path: String, hitbox: HitboxComponent, what: String) -> void:
	if hitbox.collision_layer != PLAYER_HITBOX_LAYER or hitbox.collision_mask != ENEMY_HURTBOX_MASK:
		fail(path, "%s layer/mask is %d/%d, must be %d/%d" % [what, hitbox.collision_layer,
			hitbox.collision_mask, PLAYER_HITBOX_LAYER, ENEMY_HURTBOX_MASK])
	var shapes := hitbox.find_children("*", "CollisionShape2D", false)
	if shapes.is_empty() or (shapes[0] as CollisionShape2D).shape == null:
		fail(path, "%s has no CollisionShape2D with a shape" % what)


func check_chain(path: String, item: ItemWeapon) -> void:
	var seen: Array[ItemWeapon] = [item]
	var current := item
	while current.upgrade_to:
		var next := current.upgrade_to
		if seen.has(next):
			fail(path, "upgrade_to chain loops back to %s" % next.resource_path)
			return
		if next.item_tier <= current.item_tier:
			fail(path, "%s -> %s: tier does not increase" % [current.item_name, next.item_name])
		if next.scene != current.scene:
			warn(path, "%s -> %s: upgrade uses a different scene" % [current.item_name, next.item_name])
		if next.item_name == current.item_name:
			fail(path, "%s -> %s: same item_name, the shop would merge different tiers" % [current.item_name, next.item_name])
		seen.append(next)
		current = next
	if current.item_tier != Global.UpgradeTier.LEGENDARY:
		warn(path, "upgrade_to chain ends at %s (%s), not LEGENDARY" % [current.item_name,
			Global.UpgradeTier.keys()[current.item_tier]])


func check_registration(path: String, item: ItemWeapon, shop: ShopPanel, selection: SelectionPanel) -> void:
	if not shop.shop_items.has(item):
		warn(path, "not in ShopPanel.shop_items (%s)" % SHOP_PANEL_SCENE)
	var is_start := selection.start_weapon.has(item)
	if item.item_tier == Global.UpgradeTier.COMMON and not is_start:
		warn(path, "COMMON weapon is not in SelectionPanel.start_weapon (%s)" % SELECTION_PANEL_SCENE)
	if item.item_tier != Global.UpgradeTier.COMMON and is_start:
		warn(path, "non-COMMON weapon is in SelectionPanel.start_weapon")


func fail(path: String, msg: String) -> void:
	errors += 1
	print("ERROR ", path, ": ", msg)


func warn(path: String, msg: String) -> void:
	warnings += 1
	print("WARN  ", path, ": ", msg)
