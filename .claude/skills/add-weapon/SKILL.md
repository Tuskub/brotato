---
name: add-weapon
description: Add a new melee or ranged weapon to the Brotato arena game, with its tier I–IV variants (upgrade_to chain), its projectile, and its registration in the shop and the starting-weapon selection. Use when the user asks to create, add or register a weapon, gun, melee weapon, projectile or weapon tier, rebalance weapon stats, fix weapon combining/upgrade_to, or put a weapon into the shop or the character-selection screen.
---

# Adding a new weapon

A weapon "family" (e.g. Sword I → IV) has these parts. Missing any of them gives a weapon that never shows up, can't be combined, or crashes on fire:

1. sprites: the in-hand sprite `assets/sprites/Weapons/{Melee,Range}/<File>.png` and the card icon `assets/sprites/Weapons/Icons/weapon_<name>_icon.png`
2. **one** weapon scene inheriting `scenes/weapons/weapon_base.tscn`: `scenes/weapons/melee/weapon_<name>.tscn` or `scenes/weapons/range/weapon_<name>.tscn`
3. ranged only: a projectile scene inheriting `scenes/weapons/projectiles/projectile_pistol.tscn`: `projectile_<name>.tscn`
4. **per tier** (4 tiers): a `WeaponStats` resource `stats_<name>_N.tres` and an `ItemWeapon` resource `item_<name>_N.tres` in `resources/items/weapons/{melee,range}/<name>/`, chained with `upgrade_to`
5. registration: all 4 items in `shop_items` on `scenes/ui/shop_panel/shop_panel.tscn`, and the tier-I item in `start_weapon` on `scenes/ui/selection_panel/selection_panel.tscn`

These two exports live in the **panel scenes**, not in `arena.tscn`; arena only instances the panels.

Ask the user for what you can't infer: the sprites, melee or ranged, the rough role (fast/weak, slow/heavy, long range), and whether it should be a starting weapon. Take default stats from the closest existing weapon (see the table below).

## Hierarchy and runtime flow

```
weapon_base.tscn (Weapon, weapon.gd)    uid://dcc7rsdy4j8v6
  Sprite2D        index 0   scale 0.5, z_index 1, outline ShaderMaterial (resource_local_to_scene)
  RangeArea       index 1   Area2D layer 0 / mask 2 (Enemy body); CollisionShape2D (%CollisionShape2D) CircleShape2D
  CooldownTimer   index 2   one_shot
  WeaponBehavior  index 3   plain Node2D: the child scene sets its script
 ├── melee/weapon_*.tscn   WeaponBehavior = melee_behavior.gd (MeleeBehavior) + Sprite2D/HitboxComponent
 └── range/weapon_*.tscn   WeaponBehavior = range_behavior.gd (RangeBehavior) + Sprite2D/Muzzle (Marker2D, unique name)

projectile_pistol.tscn (Projectile, projectile.gd)   uid://1rjigu81muqp
  Sprite2D, HitboxComponent (+CollisionShape2D), VisibleOnScreenNotifier2D
 └── projectile_lazer / revolver / shotgun / smg / enemy.tscn   texture (and shape offset) only
```

- `ItemWeapon` (`resources/items/weapons/item_weapon.gd`): `type` (`WeaponType.MELEE`=0 / `RANGE`=1), `scene`, `stats`, `upgrade_to`, plus the `ItemBase` fields `item_name`, `item_icon`, `item_tier`, `item_type`, `item_cost`.
- Picking a starting weapon: `SelectionPanel._on_weapon_selected` → `Global.main_weapon_selected` → `Arena._on_selection_panel_on_selection_complited` calls `player.add_weapon()`, `shop_panel.create_item_weapon()` and appends to `Global.equipped_weapons`.
- Buying: `ShopCard._on_buy_button_pressed` (refuses weapons when `Global.equipped_weapons.size() >= 6`) → `ShopPanel._on_item_purchased` → `Global.player.add_weapon(item)` + `Global.equipped_weapons.append(item)`.
- `Player.add_weapon(data)` instantiates `data.scene`, then calls `Weapon.setup_weapon(data)`. That sets the RangeArea radius to `stats.max_range` and calls `apply_tier_outline()`. `WeaponContainer.update_weapons_position()` places weapons on the `One`…`Six` marker groups.
- Combining (`ShopPanel._on_combine_button_pressed`): the two equipped weapons and cards whose **`item_name`** equals the clicked one are removed, and `upgrade_to` is added. The button is enabled when ≥ 2 equipped weapons share that `item_name`. On the last tier (`upgrade_to` null) it does nothing.
- Selling refunds `int(item_cost * 0.75)`.
- Saving (`autoloads/progress_data.gd`) stores `equipped_weapons` and the shop cards as `resource_path`. **Never move or rename an item `.tres` once saves exist**, or `load()` of an old save fails.
- Damage: `WeaponBehavior.get_damage()` = `stats.damage + Global.player.stats.damage`. On a crit (`crit_chance`) it becomes `ceil(damage * crit_damage)`. Life steal per attack has chance `player.stats.life_steal / 100 + stats.life_steal` and heals 1 HP. It rolls on every attack, hit or miss.

## 1. Stats resources (`WeaponStats`, `resources/items/weapons/weapon_stats.gd`)

One per tier. Note the misspelling `atack_duration`, which is the real property name.

| field | default | used by | meaning |
|---|---|---|---|
| `damage` | 1.0 | both | base damage, player `damage` is added |
| `crit_chance` | 0.05 | both | 0..1 |
| `crit_damage` | 1.5 | both | crit multiplier |
| `max_range` | 150.0 | both | targeting radius (RangeArea); melee: also the lunge distance in px |
| `cooldown` | 0.9 | both | `@export_range(0.5, 3.0)`, CooldownTimer wait |
| `knockback` | 0.0 | both | passed to the hitbox as `knockback_power` |
| `life_steal` | 0.0 | both | 0..1 chance per attack |
| `accuracy` | 0.9 | both | 1.0 = no spread; spread = ±(1 − accuracy) rad accumulated in `weapon_spred` |
| `recoil` | 25.0 | both | px the sprite pulls back |
| `recoil_duration` | 0.1 | both | |
| `atack_duration` | 0.2 | melee | lunge-out tween time (sic) |
| `back_duration` | 0.15 | melee | return tween time |
| `projectile_scene` | null | range | **required** for ranged, `RangeBehavior.crete_projectile()` crashes on null |
| `projectile_speed` | 1600.0 | range | px/s |

Template (`stats_<name>_1.tres`; omit any field that stays at its default):

```
[gd_resource type="Resource" script_class="WeaponStats" load_steps=3 format=3 uid="uid://<new uid>"]

[ext_resource type="Script" uid="uid://b8a4mvry2f6tn" path="res://resources/items/weapons/weapon_stats.gd" id="1_script"]
[ext_resource type="PackedScene" uid="uid://<projectile uid>" path="res://scenes/weapons/projectiles/projectile_<name>.tscn" id="2_proj"]

[resource]
script = ExtResource("1_script")
damage = 6.0
max_range = 320.0
knockback = 0.5
projectile_scene = ExtResource("2_proj")
accuracy = 0.8
cooldown = 0.9
crit_chance = 0.08
metadata/_custom_type_script = "uid://b8a4mvry2f6tn"
```

For melee, drop the projectile `ext_resource` and set `load_steps=2`. Some existing stats files carry `metadata/_custom_type_script = "uid://c7dropxg1o1hb"`, a stale UID; use `uid://b8a4mvry2f6tn` (from `weapon_stats.gd.uid`).

### Existing weapons

Tiers are I COMMON, II RARE, III EPIC, IV LEGENDARY. dmg / cooldown / range / crit% × crit_damage / knockback / life_steal / accuracy / cost (printed by `check_weapon.gd`):

| weapon | type | I | II | III | IV |
|---|---|---|---|---|---|
| Axe | melee | 9 / 1.0 / 220 / 10%×2.5 / kb 1.5 / ls .10 / acc 1.0 / 22 | 18 / 0.9 / 230 / 13% / ls .12 / 52 | 33 / 0.8 / 240 / 16% / ls .14 / 140 | 55 / 0.7 / 250 / 20% / ls .16 / 295 |
| Chainsaw | melee | 5 / 1.8 / 200 / 5%×2.0 / kb 2.0 / ls .03 / acc 0.9 / 15 | 10 / 1.45 / 210 / 7% / kb 2.2 / ls .05 / 30 | 25 / 1.1 / 220 / 10% / ls .08 / 78 | 45 / 0.8 / 230 / 15% / ls .12 / 150 |
| Mace | melee | 10 / 2.0 / 160 / 5%×1.5 / kb 0 / ls 0 / acc 0.9 / 18 | 12 / 1.3 / 200 / 7% / kb 1.5 / ls .04 / acc 0.8 / 35 | 24 / 1.0 / 200 / 5% / ls .06 / 80 | 35 / 0.8 / 200 / 5% / ls .10 / 160 |
| Punch | melee | 4 / 1.5 / 180 / 5%×1.5 / kb 1.5 / ls 0 / acc 1.0 / 12 | 8 / 1.2 / 180 / kb 0 / 25 | 16 / 0.9 / 180 / 55 | 30 / 0.7 / 200 / 10%×2.0 / 130 |
| Sword | melee | 8 / 1.2 / 200 / 5%×2.0 / kb 1.5 / ls .05 / acc 1.0 / 25 | 15 / 1.0 / 200 / 8% / ls .08 / 55 | 30 / 0.8 / 200 / 10% / ls .10 / 130 | 48 / 0.6 / 200 / 15% / ls .12 / 285 |
| Wand | melee | 10 / 1.0 / 220 / 7%×2.5 / kb 2.5 / ls .10 / acc 1.0 / 35 | 20 / 0.8 / 220 / 10% / ls .12 / 75 | 32 / 0.7 / 220 / 15% / ls .15 / 165 | 50 / 0.6 / 220 / 20% / ls .17 / 345 |
| Laser | range | 1 / 0.6 / 450 / 10%×2.5 / kb 2.0 / ls .05 / acc 1.0 / 18 | 16 / 1.7 / 450 / 15% / ls .10 / 36 | 45 / 1.1 / 450 / 20% / ls .15 / 85 | 8 / 2.0 / 450 / 10% / ls .05 / 180 |
| Pistol | range | 1 / 1.0 / 300 / 5%×1.5 / kb 0 / ls 0 / acc 0.9 / 14 | 10 / 0.9 / 360 / 8%×2.0 / kb 1.3 / acc 0.85 / 30 | 18 / 0.8 / 370 / 10% / 65 | 30 / 0.7 / 380 / 15% / 180 |
| Revolver | range | 10 / 1.5 / 350 / 5%×2.5 / kb 2.0 / ls .05 / acc 0.7 / 16 | 20 / 1.4 / 350 / 7% / ls .07 / 34 | 20 / 1.3 / 350 / 9% / ls .09 / 72 | 40 / 1.2 / 350 / 12% / ls .12 / 165 |
| Shotgun | range | 1 / 1.0 / 150 / 5%×1.5 / kb 0 / ls 0 / acc 0.8 / 15 | 18 / 1.3 / 350 / 7%×2.0 / kb 3.0 / ls .05 / acc 0.85 / 32 | 32 / 1.1 / 350 / 9% / 70 | 48 / 0.9 / 350 / 11% / 170 |
| SMG | range | 3 / 0.8 / 320 / 10%×2.0 / kb 0.5 / ls 0 / acc 0.6 / 10 | 6 / 0.7 / 330 / 15% / 25 | 12 / 0.6 / 340 / 18% / 68 | 25 / 0.6 / 350 / 25% / ls .10 / 155 |

Omitted cells are unchanged from the previous tier. Rough progression: damage ×1.8–2 per tier, cooldown −0.1…−0.3, crit +2–5%, cost ×2–2.5. Tier-I costs are 10–35 (the player starts with `Global.coins = 20`). Pistol I, Shotgun I and Laser I (dmg 1) and Laser IV (dmg 8) look like unfinished data, so don't copy them as references.

## 2. Weapon scene

New sprites need their `.import`/UID first: run `$GODOT --path . --headless --editor --quit` once, then read `uid=` from `<png>.import`.

Use **one scene for all four tiers**: every tier's item points at the same scene, and only stats differ. Tier outlines are applied at runtime (see section 4).

Known pre-existing issue: the `RangeArea` `CircleShape2D` in `weapon_base.tscn` is not `resource_local_to_scene`, so every weapon instance shares it. Each `setup_weapon()` overwrites the radius, and all equipped weapons target with the `max_range` of the last weapon added. Keep this in mind when balancing ranges. Don't fix it as part of adding a weapon unless the user asks.

### Melee (template: `weapon_sword.tscn`, with the safe hitbox flags from `weapon_punch.tscn`)

```
[gd_scene load_steps=6 format=3 uid="uid://<new scene uid>"]

[ext_resource type="PackedScene" uid="uid://dcc7rsdy4j8v6" path="res://scenes/weapons/weapon_base.tscn" id="1_base"]
[ext_resource type="Texture2D" uid="uid://<png uid>" path="res://assets/sprites/Weapons/Melee/Weapon_<name>.png" id="2_tex"]
[ext_resource type="PackedScene" uid="uid://c0fyx8gj5uexl" path="res://scenes/components/hitbox_component.tscn" id="3_hitbox"]
[ext_resource type="Script" uid="uid://deu5p1vhsccvb" path="res://scenes/weapons/melee/melee_behavior.gd" id="4_behavior"]

[sub_resource type="CapsuleShape2D" id="CapsuleShape2D_hit"]
radius = 30.0
height = 170.0

[node name="Weapon<Name>" instance=ExtResource("1_base")]

[node name="Sprite2D" parent="." index="0"]
position = Vector2(34, 4)
texture = ExtResource("2_tex")

[node name="HitboxComponent" parent="Sprite2D" index="0" instance=ExtResource("3_hitbox")]
collision_layer = 16
collision_mask = 8
monitoring = false
monitorable = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="Sprite2D/HitboxComponent" index="0"]
rotation = 1.855285
shape = SubResource("CapsuleShape2D_hit")

[node name="WeaponBehavior" parent="." index="3" node_paths=PackedStringArray("hitbox", "weapon")]
script = ExtResource("4_behavior")
hitbox = NodePath("../Sprite2D/HitboxComponent")
weapon = NodePath("..")
```

- The hitbox is a child of `Sprite2D`, so it travels with the lunge tween: `MeleeBehavior.execute_attack()` moves the sprite to `attack_start_position.x + max_range`, calls `hitbox.enable()` + `hitbox.setup(...)`, and disables it on `tween.finished`.
- Shape coordinates are in sprite space, so the parent `scale 0.5` halves them on screen. Fit the shape to the blade in the editor.
- Always set `monitoring = false` / `monitorable = false`. Only `weapon_punch.tscn` does this today. The other melee scenes start monitorable, so they damage enemies they touch before the first swing.

### Ranged (template: `weapon_pistol.tscn`)

```
[gd_scene load_steps=4 format=3 uid="uid://<new scene uid>"]

[ext_resource type="PackedScene" uid="uid://dcc7rsdy4j8v6" path="res://scenes/weapons/weapon_base.tscn" id="1_base"]
[ext_resource type="Texture2D" uid="uid://<png uid>" path="res://assets/sprites/Weapons/Range/Weapon<Name>.png" id="2_tex"]
[ext_resource type="Script" uid="uid://bwvhhgev8kjgg" path="res://scenes/weapons/range/range_behavior.gd" id="3_behavior"]

[node name="Weapon<Name>" instance=ExtResource("1_base")]

[node name="Sprite2D" parent="." index="0"]
position = Vector2(23, -2)
texture = ExtResource("2_tex")

[node name="Muzzle" type="Marker2D" parent="Sprite2D" index="0"]
unique_name_in_owner = true
position = Vector2(92, -28)

[node name="WeaponBehavior" parent="." index="3" node_paths=PackedStringArray("weapon")]
script = ExtResource("3_behavior")
weapon = NodePath("..")
```

- `RangeBehavior` finds the muzzle with `%Muzzle`, so `unique_name_in_owner = true` is mandatory. Put it at the barrel tip in sprite space.
- One shot = one projectile, spawned under `get_tree().root` with velocity `Vector2.RIGHT.rotated(weapon.rotation) * projectile_speed`. There is no multi-pellet support; the shotgun is single-shot too. A spread weapon needs a new `WeaponBehavior` subclass (extend `RangeBehavior`, override `execute_attack()`, keep resetting `weapon.is_attacking` and `critical`).
- `Weapon.update_visuals()` flips `sprite.scale.y` to ±0.5 when aiming left, so draw the sprite pointing right.

## 3. Projectile (ranged only)

Inherit the pistol projectile and override the texture (sprites in `assets/sprites/Projectiles/`):

```
[gd_scene load_steps=3 format=3 uid="uid://<new uid>"]

[ext_resource type="PackedScene" uid="uid://1rjigu81muqp" path="res://scenes/weapons/projectiles/projectile_pistol.tscn" id="1_base"]
[ext_resource type="Texture2D" uid="uid://<png uid>" path="res://assets/sprites/Projectiles/<file>.png" id="2_tex"]

[node name="Projectile<Name>" instance=ExtResource("1_base")]

[node name="Sprite2D" parent="." index="0"]
texture = ExtResource("2_tex")

[node name="CollisionShape2D" parent="HitboxComponent" index="0"]
position = Vector2(0, 0)
```

The base already has hitbox layer 16 / mask 8, a 22 px `CircleShape2D`, a `VisibleOnScreenNotifier2D` that frees it off-screen, and the `on_hit_hurtbox` → `queue_free` connection (no piercing). Don't edit `projectile_pistol.tscn` itself: five other projectiles, including the **enemy** projectile, inherit it. `Projectile._process` doesn't check `Global.game_paused`, so projectiles keep flying while the game is paused.

## 4. Items and the tier chain

Template (`item_<name>_1.tres`):

```
[gd_resource type="Resource" script_class="ItemWeapon" load_steps=6 format=3 uid="uid://<new uid>"]

[ext_resource type="Script" uid="uid://ct2jopdoy6y1v" path="res://resources/items/weapons/item_weapon.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://<icon uid>" path="res://assets/sprites/Weapons/Icons/weapon_<name>_icon.png" id="2_icon"]
[ext_resource type="PackedScene" uid="uid://<scene uid>" path="res://scenes/weapons/range/weapon_<name>.tscn" id="3_scene"]
[ext_resource type="Resource" uid="uid://<stats_1 uid>" path="res://resources/items/weapons/range/<name>/stats_<name>_1.tres" id="4_stats"]
[ext_resource type="Resource" uid="uid://<item_2 uid>" path="res://resources/items/weapons/range/<name>/item_<name>_2.tres" id="5_next"]

[resource]
script = ExtResource("1_script")
type = 1
scene = ExtResource("3_scene")
stats = ExtResource("4_stats")
upgrade_to = ExtResource("5_next")
item_name = "<Name> I"
item_icon = ExtResource("2_icon")
item_tier = 0
item_cost = 20
metadata/_custom_type_script = "uid://ct2jopdoy6y1v"
```

Rules:

- **`item_name` must be unique per tier** ("Sword I", "Sword II", …). Combining, selling and the combine-button check all match on `item_name`, not on the resource. Two tiers with the same name would be merged together.
- `item_tier`: 0 COMMON, 1 RARE, 2 EPIC, 3 LEGENDARY (`Global.UpgradeTier`). It must strictly increase along `upgrade_to`. The tier IV item has no `upgrade_to` line, so drop that `ext_resource` and decrement `load_steps`.
- `type`: 0 MELEE, 1 RANGE. Nothing reads it today (the behavior node decides), but keep it correct; all four pistol items wrongly leave it at 0.
- `item_type` is `ItemBase.ItemType.WEAPON` = 0, the default, so leave it out. The shop branches on it.
- Write the chain bottom-up (IV, III, II, I) so every `upgrade_to` target UID exists when you reference it.
- The shop rolls tiers by wave (`Global.SHOP_PRPBABILITY_CONFIG`: rare from wave 2, epic from 4, legendary from 7, scaled by luck). Higher tiers must therefore be in `shop_items` themselves, not just reachable by combining.

**Outline shader per tier**: nothing to author. `weapon_base.tscn`'s `Sprite2D` has a `ShaderMaterial` (`shaders/outline.gdshader`, `resource_local_to_scene = true`). `Weapon.apply_tier_outline()` sets it to `null` for COMMON and otherwise sets `outline_color` to `Global.TIER_COLORS[tier]` (RARE blue, EPIC purple, LEGENDARY red). Don't override `Sprite2D.material` in the weapon scene: a null material on a non-common tier crashes `set_shader_parameter`.

## 5. Registration

**`scenes/ui/shop_panel/shop_panel.tscn`**: add one `ext_resource type="Resource"` per item (all four tiers), append them to `shop_items = Array[ExtResource("2_pk1f0")]([...])` on the root `ShopPanel` node, and bump `load_steps` by 4. The array currently holds the 44 weapon items followed by the 4 passives.

**`scenes/ui/selection_panel/selection_panel.tscn`** (only if it should be a starting weapon): add an `ext_resource` for the tier-I item, append it to `start_weapon = Array[ExtResource("8_q3p5q")]([...])`, and bump `load_steps` by 1. All 11 existing tier-I items are listed there. Only tier I belongs here.

`WeaponContainer` and `Global.equipped_weapons` need no changes: up to 6 of any weapon are handled generically.

## Physics layers for weapons

`project.godot`: 1 Player, 2 Enemy, 3 HitboxEnemy, 4 HurtboxEnemy, 5 HitboxPlayer, 6 HurtboxPlayer. The bit values are 1, 2, 4, 8, 16, 32.

| node | collision_layer | collision_mask |
|---|---|---|
| `RangeArea` (base, targeting) | 0 | 2 (enemy bodies) |
| melee `HitboxComponent` | 16 (HitboxPlayer) | 8 (HurtboxEnemy) |
| player projectile `HitboxComponent` | 16 | 8 |
| enemy projectile (`projectile_enemy.tscn`, for comparison) | 4 | 32 |

`hitbox_component.tscn` itself has default layer 1 / mask 1 and no shape. Always override both values and add a `CollisionShape2D`.

## Hand-editing `.tscn` / `.tres` safely

Prefer the editor. When writing files by hand:

- **New UID per new file** (charset `a-z0-7`, Godot base-34). Never invent one by tweaking an existing UID: `item_mace_2.tres`/`item_mace_4.tres` reference `uid://b2vgpc47q00v2`/`…v4`, which don't exist, and that causes the `invalid UID … using text path instead` warnings on every boot.

  ```sh
  python3 -I -c "
  import secrets
  i=secrets.randbits(63); s=''
  while True:
      c=i%34; s+=chr(97+c) if c<26 else chr(48+c-26); i//=34
      if not i: break
  print('uid://'+s[::-1])"
  ```
  `grep -rn "<uid>" .` should find nothing before you use it.
- In an `ext_resource`, a **valid UID beats the path**. `item_mace_1.tres` lists path `stats_mace_1.tres` but UID `uid://d0gevuo634gkv`, which belongs to `stats_mece_1.tres`, so the latter is what loads. When copying an `ext_resource` line, update both `uid=` and `path=`, and take the UID from the target file's header (or from `<script>.gd.uid` / `<png>.import`).
- `ext_resource`/`sub_resource` ids are arbitrary strings, unique within the file. `ExtResource("…")` must match one exactly.
- `load_steps` = number of `ext_resource` + `sub_resource` entries + 1. A wrong value only warns, but keep it right.
- Copying a whole file: change the header `uid=`, the node `name`, and every per-tier reference (`stats`, `upgrade_to`, `item_name`, `item_tier`, `item_cost`).
- Godot can rewrite these files when the editor saves them. Reopen and check the diff after an editor save.

## 6. Verify

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --path . --headless --editor --quit >/dev/null 2>&1      # import new sprites, register UIDs
$GODOT --path . --headless --quit 2>&1 | grep -v "resource_format_text.cpp:444\|invalid UID"
```

Expect only the pre-existing exit-time leak warning. Then run [check_weapon.gd](check_weapon.gd) as a temporary scene (it needs autoloads, so `--script` won't work) and delete it afterwards:

```sh
cp .claude/skills/add-weapon/check_weapon.gd _tmp_wpn_check.gd
printf '[gd_scene format=3]\n\n[ext_resource type="Script" path="res://_tmp_wpn_check.gd" id="1"]\n\n[node name="Check" type="Node"]\nscript = ExtResource("1")\n' > _tmp_wpn_check.tscn
$GODOT --path . --headless res://_tmp_wpn_check.tscn 2>&1 | grep -v "resource_format_text.cpp:444\|invalid UID\|GDScript backtrace\|_tmp_wpn_check.gd:"
# or only some items:  ... res://_tmp_wpn_check.tscn -- res://resources/items/weapons/range/<name>/item_<name>_1.tres
rm -f _tmp_wpn_check.gd _tmp_wpn_check.gd.uid _tmp_wpn_check.tscn
```

For every `item_*.tres` under `resources/items/weapons/` (or the paths after `--`), the script loads it as `ItemWeapon`, instantiates the scene, runs `setup_weapon()`, and prints one stats line. It reports `ERROR` for: wrong `item_type`, missing icon, stats or scene, a non-`Weapon` root, an unwired `WeaponBehavior.weapon`, melee without a hitbox, ranged without `%Muzzle` or `projectile_scene`, hitbox layer/mask ≠ 16/8, a hitbox without a shape, a projectile without a `VisibleOnScreenNotifier2D`, a RangeArea radius ≠ `max_range`, a wrong tier outline, an `upgrade_to` loop or non-increasing tier, a duplicate `item_name`. It reports `WARN` for: a melee hitbox that starts monitorable, `type` vs behavior mismatch, a chain not ending at LEGENDARY, an upgrade using a different scene, missing from `shop_items`, COMMON missing from `start_weapon` (or non-COMMON in it), and the shared RangeArea shape (pre-existing). The script exits with code 1 if there are errors. The current baseline is `checked 44 items: 0 errors, 25 warnings` (20 monitorable melee hitboxes, 4 pistol `type`, 1 shared shape). The new weapon should add no `ERROR`s and no new `WARN`s.

Finally, tell the user to open the weapon scene once in the editor (check the hitbox shape and muzzle position over the sprite) and playtest: buy two copies in the shop and combine them. Swing/shot feel, the hitbox fit and combining can't be verified headless.
