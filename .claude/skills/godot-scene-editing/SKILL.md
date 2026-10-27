---
name: godot-scene-editing
description: Rules for safely hand-editing Godot 4.5 .tscn scenes and .tres resources in this repo as text, covering the header (load_steps, format=3, uid), ext_resource/sub_resource ids, generating new uid:// values and .uid files, inherited scenes (enemy_base.tscn, weapon_base.tscn, player_well_rounded.tscn, projectile_pistol.tscn), node paths and index, node_paths exports, signal [connection] entries with this repo's misspelled handlers, collision layer/mask bit values, typed Array[...] exports and enum ints. Use whenever you create, copy, rename or modify a .tscn or .tres file without the editor, add a node, override, connection or resource reference, wire an export, set collision layers, or fix "invalid UID", "Unrecognized UID", "has vanished" or "Parse Error" in a scene file.
---

# Hand-editing .tscn / .tres files

The editor is the safe way to change scenes. When you have to edit the text (which is always the case for an agent), follow these rules and then run the `godot-verify` skill, which catches most mistakes in this file:

```sh
.claude/skills/godot-verify/verify.sh            # static scan + headless boot
```

Tools here: [new_uid.py](new_uid.py) generates `uid://` values with Godot's real encoding and checks the repo for collisions.

## 1. File anatomy

A complete real scene, `scenes/units/enemies/enemy_charger.tscn`, with the animations shortened:

```
[gd_scene load_steps=8 format=3 uid="uid://n8xlqxlsl5el"]

[ext_resource type="PackedScene" uid="uid://h4qyxvfputld" path="res://scenes/units/enemies/enemy_base.tscn" id="1_woq8q"]
[ext_resource type="Texture2D" uid="uid://emsi6ifyt0vf" path="res://assets/sprites/Enemies/Enemy_5.png" id="2_a2ev1"]
[ext_resource type="Resource" uid="uid://clhs08eeatohp" path="res://resources/units/enemies/stat_enemy_charger.tres" id="2_esmqr"]
[ext_resource type="Script" uid="uid://d31buvajxowsm" path="res://scenes/units/enemies/chanrge_behavior.gd" id="4_4a187"]

[sub_resource type="Animation" id="Animation_4a187"]
resource_name = "charge"
...
[sub_resource type="Animation" id="Animation_ne2cu"]
...
[sub_resource type="AnimationLibrary" id="AnimationLibrary_44v2p"]
_data = {
&"RESET": SubResource("Animation_ne2cu"),
&"charge": SubResource("Animation_4a187")
}

[node name="EnemyCharger" instance=ExtResource("1_woq8q")]
stats = ExtResource("2_esmqr")

[node name="Sprite" parent="Visuals" index="1"]
texture = ExtResource("2_a2ev1")

[node name="ChanrgeBehavior" type="Node2D" parent="." index="10" node_paths=PackedStringArray("enemy", "anim_effects")]
script = ExtResource("4_4a187")
enemy = NodePath("..")
anim_effects = NodePath("../AnimationEffects")

[node name="AnimationEffects" type="AnimationPlayer" parent="." index="11"]
libraries = {
&"": SubResource("AnimationLibrary_44v2p")
}
```

The sections always come in this order: header, every `[ext_resource]`, every `[sub_resource]` (each one declared **before** anything that uses it, as `AnimationLibrary` comes after its `Animation`s), then the `[node]` sections (a `.tscn`) or the single `[resource]` (a `.tres`), then `[connection]`, then `[editable]`.

**Header.**

- `format=3` always (Godot 4).
- `uid="uid://…"` is this file's identity, and other files reference it with that value. Every file has its own uid (section 3).
- `load_steps` = number of ext_resources + number of sub_resources + 1. In the charger above that is 4 + 3 + 1 = 8. It is only a loading-progress hint, so a wrong value is harmless and Godot even accepts a missing one. `run_harness.sh` writes `[gd_scene format=3]`, and the hand-written `start_menu.tscn` (`[gd_scene load_steps=4 format=3]`) has no uid at all. Still, keep it right when you add or remove sections: the editor rewrites it anyway, and a correct value keeps diffs small.
- A `.tres` that uses a custom script says so twice: `[gd_resource type="Resource" script_class="ItemWeapon" load_steps=6 format=3 uid="uid://b2vgpc47q00vl"]` plus `script = ExtResource(...)` in `[resource]`. `script_class` must be the script's `class_name` (`UnitStats`, `WeaponStats`, `ItemWeapon`, `ItemUpgrade`, `ItemPassive`, `WaveDate`).
- `metadata/_custom_type_script = "uid://…"` at the end of a custom resource is editor metadata naming the script's uid. Set it to the script's real uid. Many existing files have stale ones (check_refs lists them), and they are harmless.

## 2. ext_resource and sub_resource ids

```
[ext_resource type="<Type>" uid="uid://<target's uid>" path="res://<target>" id="<any unique string>"]
```

- `type` values in this repo: `PackedScene`, `Script`, `Resource` (any `.tres`), `Texture2D`, `Shader`, `AudioStream`.
- `id` is any string that is unique **within the file**. The editor writes `<n>_<5 random chars>` (`1_woq8q`). Hand-written files use readable ones (`1_base`, `13_start`, `14_ustats` in `arena.tscn`). Never renumber the existing ids. Pick a new id that isn't used yet.
- Sub-resource ids follow the editor style `<Type>_<5 chars>` (`CircleShape2D_ebrsu`). They are file-local.
- Use them as `ExtResource("id")` / `SubResource("id")`. Every use needs a declaration, and check_refs reports undeclared or duplicate ids.
- A sub_resource is shared by every instance of the scene unless it sets `resource_local_to_scene = true`. `weapon_base.tscn`'s outline `ShaderMaterial` does that, so each weapon instance can have its own outline color. ExtResource `.tres` files are always shared. `UnitStats` files get mutated at runtime, so every enemy type needs its own stats file.

**Where to get the `uid=` of a target:**

| target | its uid lives in |
|---|---|
| `.tscn` / `.tres` | its own header, `uid="…"` |
| `.gd`, `.gdshader` | the sibling file `<name>.gd.uid` / `<name>.gdshader.uid` (one line, `uid://…`) |
| `.png`, `.mp3`, `.wav`, `.otf`, `.svg` | `<asset>.import`, line `uid="uid://…"` in `[remap]` |

```sh
head -1 scenes/units/enemies/enemy_base.tscn          # uid="uid://h4qyxvfputld"
cat scenes/units/enemies/enemy.gd.uid                  # uid://37mmvysgo1tu
grep '^uid=' assets/sprites/Enemies/Enemy_5.png.import # uid="uid://emsi6ifyt0vf"
```

**A uid has to be right or absent.**

- A uid that belongs to *another* file wins over `path`, so Godot loads the wrong file without a warning. That is the real state of `item_mace_1.tres`, which loads `stats_mece_1.tres` while its path says `stats_mace_1.tres`.
- An unknown uid falls back to `path` with `invalid UID … using text path instead`. That causes the 48 warnings at every boot (upgrade `.tres` files point at `item_upgrade.gd` with `uid://cr0po024cxfg5` / `uid://0kfyb4qfa66q`, while the real one is `uid://ti87pqqmd7ro`).
- If you can't look the uid up, leave it out (`[ext_resource type="PackedScene" path="res://scenes/ui/start_menu/start_menu.tscn" id="13_start"]` in `arena.tscn`). Path-only references are valid, and the editor adds the uid the next time it saves the file.

## 3. New files: uids, .uid files, imports

```sh
python3 .claude/skills/godot-scene-editing/new_uid.py            # one fresh uid for a new .tscn/.tres header
python3 .claude/skills/godot-scene-editing/new_uid.py 3          # several
python3 .claude/skills/godot-scene-editing/new_uid.py --file scenes/units/enemies/foo.gd   # writes foo.gd.uid
```

- **The encoding.** Godot writes a random 63-bit id in base 34, using the letters **a–y** and then the digits **0–8**. There is no `z` and no `9`, and uids are 12–13 characters long. All 323 uids in the repo fit this. `new_uid.py` round-trips through Godot's own `ResourceUID.text_to_id`/`id_to_text` with 0 mismatches. (The generator in the `add-enemy` skill uses `a–z0–7`, which is wrong: it can produce `z` and never `8`.) Don't invent uids by hand or copy one from another file.
- **New `.gd`.** Commit the `.uid` file along with the script. Either write it with `new_uid.py --file` (when a scene you're writing needs to reference the script by uid), or let `.claude/skills/godot-verify/verify.sh --import` create it. Only an import or the editor writes `.uid` files, and a plain `--headless --quit` doesn't. A hand-written `.uid` survives the import unchanged.
- **New `class_name`.** It is unknown to other scripts until `verify.sh --import` updates `.godot/global_script_class_cache.cfg`. Before that you get `Parse Error: Identifier "Foo" not declared in the current scope`.
- **New asset (png/audio/font).** Run `verify.sh --import`, then read `uid=` from the generated `<asset>.import` and commit that file. Don't hand-write `.import` files.
- **Until the next import, new uids are unknown at runtime.** `ext_resource` entries still load through their `path`, but `preload("uid://new…")` and `load("uid://new…")` in scripts fail with `ERROR: Unrecognized UID`. Run `--import` before testing.
- **Copying a file to make a variant** (the usual way to create a stats `.tres` or an enemy scene): give the copy a **new header uid** right away. Two files with one uid confuse the uid cache, and check_refs reports it as an error.
- **Moving or renaming a file.** Fix every `path="res://old…"` (`grep -rn "old/path" --include='*.tscn' --include='*.tres' --include='*.gd' .`). Keep the uid, keep the `.uid`/`.import` file next to the source, and remember `preload("uid://…")` users in scripts.

## 4. Nodes, node paths and exports

```
[node name="Arena" type="Node2D" groups=["arena"]]                      # root: no parent
[node name="Spawner" type="Node2D" parent="."]                          # child of root
[node name="SpawnTimer" type="Timer" parent="Spawner"]                  # grandchild
[node name="UpgradeCard" parent="MarginContainer/HBoxContainer/VBoxContainer/ItemsContainer" instance=ExtResource("2_1n3gp")]
```

- `parent` is a path from the root, written without the root's name. The root itself is `"."`. A parent's section must come before its children, and file order is child order.
- A node with `type=` is a new node of that class. A node with `instance=ExtResource(…)` is an instanced scene and has no `type`. A node with neither is an **override** of an existing node (see section 5).
- Only non-default property values are written. Deleting a line resets the property to the class or script default, not to "unchanged". `item_sword_1.tres` has no `item_tier` or `type` line, which means `COMMON` and `MELEE`.
- **Exported node references need two pieces:** the property name in `node_paths=PackedStringArray(...)` on the node header, plus a `NodePath` that is relative to **that node**, not to the root:
  ```
  [node name="WeaponBehavior" parent="." index="3" node_paths=PackedStringArray("hitbox", "weapon")]
  script = ExtResource("4_nukjc")
  hitbox = NodePath("../Sprite2D/HitboxComponent")
  weapon = NodePath("..")
  ```
  (`weapon_sword.tscn`.) Without `node_paths` the value is not resolved to a node. `trail.gd`'s `player = NodePath("../..")` goes up from `Visuals/Trail` to the root.
- `unique_name_in_owner = true` makes the node reachable as `%Name` from scripts of the same scene (`arena.gd`: `%WaveIndexLabel`, `%UpgragePanel`, `%ShopPanel`, and 44 nodes use it). The name must be unique in that scene.
- Renaming a node breaks `$Path` / `%Name` lookups, `[connection]` `from`/`to` paths, `NodePath`s, the `tracks/N/path = NodePath("Visuals/Sprite:scale")` entries of animations, and every override in inheriting scenes. Grep for the old name everywhere before you rename.
- `groups=["arena"]` on the Arena root is what `get_first_node_in_group('arena')` (in `progress_data.gd`) finds. The group is also declared in `project.godot` under `[global_group]`.

## 5. Inherited scenes

Inheritance chains in this repo:

```
unit.tscn ── enemy_base.tscn ── enemy_chaser_slow/mid/fast, enemy_charger, enemy_shooter
          └─ player_well_rounded.tscn ── player_brawler, player_bunny, player_crazy, player_knight
weapon_base.tscn ── weapon_axe/chainsaw/mace/punch/sword/wand, weapon_lazer/pistol/revolver/shotgun/smg
projectile_pistol.tscn ── projectile_enemy/lazer/revolver/shotgun/smg
```

- **Root.** It has `instance=` of the base and no `type`/`parent`: `[node name="EnemyCharger" instance=ExtResource("1_woq8q")]`. It may set a script and properties on the root (`enemy_base.tscn`: `collision_layer = 2`, `script = ExtResource("2_uipox")`).
- **Override an inherited node.** Use the **exact** `name` and `parent` from the base, with no `type`, and list only the changed properties: `[node name="Sprite" parent="Visuals" index="1"]` + `texture = …`. If the name or parent doesn't match, Godot prints `WARNING: Node 'Visuals/Sprit' was modified from inside an instance, but it has vanished.` and drops the override, so the sprite ends up without a texture. verify.sh counts that warning as an error.
- **Add a node.** Use `type=` or `instance=` plus `index` = its position among the parent's children in the **final** scene. A wrong `index` on an override was ignored in testing, but copy the value from a sibling scene of the same chain anyway, because the editor writes it that way. The resulting child order:
  - `unit.tscn` root: Visuals 0, CollisionShape2D 1, AnimationPlayer 2, HurtboxComponent 3, HealthComponent 4, HealthBar 5, FlashTimer 6.
  - `enemy_base.tscn` inserts VisionArea (3) and HitboxComponent (5) and appends KnockbackTimer (9). The result is Visuals, CollisionShape2D, AnimationPlayer, VisionArea, HurtboxComponent, HitboxComponent, HealthComponent, HealthBar, FlashTimer, KnockbackTimer, so **the first node an enemy adds is `index="10"`** (`ChanrgeBehavior` 10, `AnimationEffects` 11).
  - `player_well_rounded.tscn` inserts `Trail` at `Visuals` index 0, so in player scenes the sprite override is `[node name="Sprite" parent="Visuals" index="2"]` (`player_knight.tscn`). Enemies use `index="1"`. Don't copy overrides between the two chains.
  - `weapon_base.tscn`: Sprite2D 0, RangeArea 1, CooldownTimer 2, WeaponBehavior 3. Weapons override `WeaponBehavior` at `index="3"` to give it a `MeleeBehavior`/`RangeBehavior` script.
- **Add a child under an inherited or instanced node** with `parent` set to that node. `enemy_base.tscn` does this for `[node name="CollisionShape2D" type="CollisionShape2D" parent="HurtboxComponent" index="0"]`, and `weapon_sword.tscn` for `[node name="HitboxComponent" parent="Sprite2D" index="0" instance=ExtResource("3_3wm1q")]`.
- **Inherit, don't copy.** Always inherit the *base* (`enemy_base.tscn` `uid://h4qyxvfputld`, `weapon_base.tscn` `uid://dcc7rsdy4j8v6`). Never inherit a concrete scene, because that drags its stats and texture along (`projectile_enemy.tscn` inheriting `projectile_pistol.tscn` is the existing exception).
- **Base changes propagate.** Renaming, removing or re-parenting a node in a base silently orphans the overrides in every child scene, so grep the chain.
- **Connections declared in a base** (such as `unit.tscn`'s `on_damaged` → `_on_hurtbox_component_on_damaged`) apply to all inheriting scenes. Don't repeat them.
- **Editable children** (`[editable path="HitboxComponent"]` at the end of the file) are **not used** in this repo. They are only needed to override nodes *inside* a scene that is instanced as a child (not inherited). Setting properties on the instanced node itself (`collision_layer` on an instanced `HitboxComponent` in `projectile_pistol.tscn`) or adding children to it works without them.

## 6. Signal connections

```
[connection signal="on_wave_complited" from="Spawner" to="." method="_on_spawner_on_wave_complited"]
[connection signal="timeout" from="Spawner/SpawnTimer" to="Spawner" method="_on_spawn_timer_timeout"]
```

- `from` and `to` are node paths from the root (`.` = root). The signal must be declared on the `from` node (`signal on_wave_complited` in `spawner.gd`), and the `method` must exist in the `to` node's script. check_refs warns when no `func` in the project has that name.
- The editor names a handler `_on_<from node in snake_case>_<signal>`, and the misspellings carry over. These names are real and must be spelled exactly like this: signals `on_wave_complited` (`spawner.gd`) and `on_selection_complited` (`selection_panel.gd`); handlers `_on_spawner_on_wave_complited` and `_on_selection_panel_on_selection_complited` (`arena.gd`); nodes `UpgragePanel` (`upgrage_panel.tscn`/`.gd`) and `ChanrgeBehavior` (`chanrge_behavior.gd`). Renaming any of these means changing the signal, every handler and every `[connection]` together.
- Put the connection in the scene that contains both nodes. Global event-bus signals (`Global.on_enemy_died`, …) are connected in code (`arena.gd` `_ready`), never in `.tscn` files.
- `flags=`, `binds=` and `unbinds=` are not used in this repo.

## 7. Collision layers and masks

Layer names (`project.godot` `[layer_names]`): layer *N* has bit value 2^(N−1). A property's value is the sum of its bits (layers 1 + 2 → `3`). An omitted line means the Area2D default, layer `1` / mask `1`. `0` means none.

| layer | name | bit |
|---|---|---|
| 1 | Player | 1 |
| 2 | Enemy | 2 |
| 3 | HitboxEnemy | 4 |
| 4 | HurtboxEnemy | 8 |
| 5 | HitboxPlayer | 16 |
| 6 | HurtboxPlayer | 32 |

Current assignments. Match them for new nodes:

| node | collision_layer | collision_mask | file |
|---|---|---|---|
| player body (Unit root) | 1 (default) | 2 | `player_well_rounded.tscn` |
| player HurtboxComponent | 32 | 4 | `player_well_rounded.tscn` |
| enemy body | 2 | 1 (default) | `enemy_base.tscn` |
| enemy VisionArea (flocking) | 0 | 2 | `enemy_base.tscn` |
| enemy HurtboxComponent | 8 | 16 | `enemy_base.tscn` |
| enemy HitboxComponent / enemy projectile | 4 | 32 | `enemy_base.tscn`, `projectile_enemy.tscn` |
| player weapon / projectile HitboxComponent | 16 | 8 | `weapon_*.tscn`, `projectile_pistol.tscn` |
| weapon RangeArea (targeting) | 0 | 2 | `weapon_base.tscn` |
| Coins | 0 | 1 (default) | `coins.tscn` |

Rule: a hitbox sits on its own side's Hitbox layer and masks the *other* side's Hurtbox layer. Writing `collision_layer = 5` because "layer 5 is HitboxPlayer" is the classic mistake: that value means layers 1 + 3. Use the bit value, `16`.

## 8. Values and typed exports

- **Typed arrays of script classes.** The element type is the **script's** ext_resource, so that script must be declared even though no node uses it directly:
  ```
  [ext_resource type="Script" uid="uid://brjn3a1k336sd" path="res://resources/units/unit_stats.gd" id="14_ustats"]
  ...
  enemy_collection = Array[ExtResource("14_ustats")]([ExtResource("15_chaser_slow"), ExtResource("16_chaser_mid"), ExtResource("17_chaser_fast"), ExtResource("18_charger"), ExtResource("19_shoter")])
  ```
  (`arena.tscn`, the `Spawner` node, `@export var enemy_collection: Array[UnitStats]`.) Elements can also be `SubResource(...)`, as in `units = Array[ExtResource("2_78wao")]([SubResource("Resource_3lh5k"), …])` in `resources/waves/data/wave_1_to_5.tres`. To append, add an ext_resource (or sub_resource) for the element, append it inside `[...]` and bump `load_steps`. Where the pools live: `shop_items` (`Array[ItemBase]`) is in `scenes/ui/shop_panel/shop_panel.tscn`, `upgrade_list` (`Array[ItemUpgrade]`) is in `scenes/ui/upgrade_panel/upgrage_panel.tscn`, and `players` / `start_weapon` are in `scenes/ui/selection_panel/selection_panel.tscn`. None of them are in `arena.tscn`.
- **Enums are stored as ints:**

  | enum | values |
  |---|---|
  | `UnitStats.UnitType` (`type`) | PLAYER 0, ENEMY 1 |
  | `ItemBase.ItemType` (`item_type`) | WEAPON 0, UPGRADE 1, PASSIVE 2 |
  | `Global.UpgradeTier` (`item_tier`) | COMMON 0, RARE 1, EPIC 2, LEGENDARY 3 |
  | `ItemWeapon.WeaponType` (`type`) | MELEE 0, RANGE 1 |
  | `WaveDate.SpawnType` (`spawn_type`) | FIXED 0, RANDOM 1 |

- **Literal syntax** as written by Godot 4.5: `Vector2(0, -61)`, `Color(1, 0.29, 0.45, 1)` (0–1 floats), `NodePath("..")`, `&"idle"` (StringName, used for animation names and `bus = &"Music"`), `PackedStringArray("enemy", "anim_effects")`, `PackedVector2Array(0, 0)`, `PackedFloat32Array(0, 0.1)`, and dictionaries `{ &"": SubResource("…") }`. Strings are double-quoted, and `\"` escapes a quote.
- **Property names must match the script exactly**, misspellings included: `damege_increase_pre_wave`, `health_increase_pre_wave`, `fixsed_spawn_time`, `atack_duration`. An unknown property is **silently ignored**: `health_increase_per_wave = 99.0` in a `UnitStats` `.tres` loads without any error and has no effect. Check names against the `@export` lines of the script and confirm values in a harness.
- Respect the declared types. `health`, `speed` and `gold_drop` in `UnitStats` are `int`. `damage = 8` into a `float` export loads fine (`stats_sword_1.tres`). Don't write fractional values into int exports.

## 9. Pitfalls

1. A copied file keeps the original's header uid. Generate a new one immediately.
2. A guessed or copied `uid=` on an ext_resource can point at another file, and the uid wins over the path. Look it up (section 2) or omit it.
3. An `ExtResource`/`SubResource` id used without being declared, or declared twice, gives `Parse Error: [ext_resource] referenced non-existent resource` and cascades through every scene that loads the file. The first error printed is the real one.
4. An override's name or parent doesn't match the base (`has vanished`), or a new node is missing `type=`, so it is treated as an override of nothing.
5. `node_paths` is missing for a node export, or the `NodePath` is written relative to the root instead of to the node.
6. Collision values written as layer numbers instead of bit values.
7. A misspelled property is silently ignored. "Fixing" a misspelled signal or handler in one place only breaks the connection.
8. A new script, `class_name` or asset is tested without `verify.sh --import`.
9. Letter case: macOS resolves `res://assets/sprites/weapons/...` for `Weapons/`, but exports don't. check_refs flags it. Note the real oddities `assets/sprites/Players/Player_3}.png` and `stats_mece_1.tres`. They are referenced by those names, so don't "fix" them.
10. Editing a `.tscn` while the user has it open in the editor: the editor holds its own copy and can write it back over your change. Tell the user to reload the scene (or close it first).

## 10. Verify

1. `python3 .claude/skills/godot-verify/check_refs.py` must show 0 new errors (the baseline is 1 known error and 99 warnings).
2. Run `.claude/skills/godot-verify/verify.sh` (add `--import` if you added a script, a `class_name` or an asset). The expected result is `0 error(s)`. The boot only loads what the main scene pulls in.
3. Instantiate what you edited with the harness template (`.claude/skills/godot-verify/harness_template.gd` + `run_harness.sh <copy> <prefix>`). Its smoke test loads and instantiates every scene. Add asserts for what you changed: node names and order (`get_children()`), exported values, `NodePath` targets, collision values.
4. Tell the user to open the edited scenes once in the editor. The inherited tree should look right, and saving normalizes the file (ids, `load_steps`, uids added to path-only references), so expect a small diff.
