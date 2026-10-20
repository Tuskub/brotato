# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Brotato-style arena survivor game written in GDScript for **Godot 4.5** (Mobile renderer, 1920x1080 viewport). It has no test suite, linter or build scripts. All the code is `.gd` scripts attached to `.tscn` scenes, and the data lives in `.tres` resources.

## Commands

Godot is installed as an app bundle and is not on PATH:

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot

$GODOT --path . --editor                 # open in editor
$GODOT --path .                          # run main scene (scenes/arena/arena.tscn)
$GODOT --path . --headless --quit        # boot the main scene for one frame; prints script/parse errors
$GODOT --path . --headless --export-release "macOS" ./brotato.dmg   # presets: "macOS", "Linux"
```

The headless boot already prints many `invalid UID ... using text path instead` warnings and an exit-time leak warning, so only look for new errors. `--headless --script foo.gd` does **not** load autoloads, so any script touching `Global` fails to compile there. To exercise game code headless, put a temporary `Node` scene with the script in the project root, run `$GODOT --path . --headless res://_tmp_check.tscn`, and delete it afterwards. `.claude/skills/add-enemy/` has a ready-made version of this. `export_presets.cfg` is gitignored. `brotato.dmg` is a build artifact and should not be committed.

## Architecture

### Autoloads (global singletons, see `project.godot`)
- **`Global`** (`autoloads/global.gd`) is the central hub. It holds the event-bus signals (`on_create_damage_text`, `on_enemy_died`, `on_upgrade_selected`, …), the shared mutable run state (`player`, `coins`, `game_paused`, `equipped_weapons`, the selected character and weapon), the `UpgradeTier` enum with tier colors and styles, the preloaded scenes, and the tier-weighted offer roll `select_items_from_offer()` used by both the shop and the upgrade panel. The roll is scaled by `player.stats.luck`.
- **`ProgressData`** saves and loads a JSON file at `user://data.sav` on window close. It stores resources by `resource_path` and player stats by reflecting over the float/int properties of `UnitStats`. Saved data is only loaded when the Arena's `use_save_data` export is enabled.
- **`SoundManager`** is a scene with a pool of `AudioStreamPlayer`s. Call `SoundManager.play_sound(SoundManager.Sound.X)`.

### Game loop (`scenes/arena/arena.gd` is the orchestrator)
1. `SelectionPanel`: the player picks a character (`UnitStats`) and a starting weapon. Arena then instantiates the player scene from `Global.available_player[stats.name]`, so the stats `name` must match that dictionary key.
2. `Spawner` runs a wave. It finds the `WaveDate` resource whose `from..to` range contains `wave_index`, then spawns weighted-random enemies (each spawn plays a spawn effect first) until `WaveTimer` ends.
3. When the wave ends: `Global.game_paused = true` and harvesting coins are granted. (At the start of every wave, `Spawner.scale_enemies_for_wave()` **mutates in place** the enemy `UnitStats` in `enemy_collection`, setting them to wave-1 values + `*_pre_wave` × (`wave_index` − 1). A new enemy stats resource must be added to `enemy_collection` in `arena.tscn` or it won't scale.) Arena clears the arena (coins fly to the CoinsBag) and shows the `UpgradePanel`.
4. `UpgradePanel` → `Global.on_upgrade_selected` → `ShopPanel`. In the shop the player buys, sells and combines items. "Next wave" calls `Arena.start_new_wave()`.

Pausing is a custom flag, not `get_tree().paused`. Every `_process` that should freeze checks `Global.game_paused` and returns early.

### Units and combat
- `Unit` (`scenes/units/unit.gd`) is the base for `Player` and `Enemy`. It owns the `UnitStats` resource, a `HealthComponent`, the flash-on-hit material and the block roll.
- Damage travels through `HitboxComponent` → `HurtboxComponent` area overlaps. The hitbox carries `damage`, `critical`, `knockback_power` and `source`. The hurtbox emits `on_damaged`, and `Unit._on_hurtbox_component_on_damaged` handles it. The physics layers are named in `project.godot` (Player, Enemy, HitboxEnemy, HurtboxEnemy, HitboxPlayer, HurtboxPlayer). Set the layers and masks correctly on new hitboxes and hurtboxes.
- Every enemy scene inherits `enemies/enemy_base.tscn` (which inherits `unit.tscn` with `enemy.gd`, and has no stats or texture) and sets its own `stats` and `Visuals/Sprite` texture. Variants add behavior child nodes, such as `ChargeBehavior` (`chanrge_behavior.gd`) and `shooting_behavior.gd`. Behaviors must stop when `enemy.is_dead` or `Global.game_paused` is set. They pause movement through `enemy.can_move`. To add an enemy or a behavior, use the `add-enemy` skill (`.claude/skills/add-enemy/SKILL.md`).
- Movement uses direct `position +=` updates, not physics bodies. The player is clamped to ±1000 x ±500, which matches `Spawner.spawn_area_size`.

### Weapons
- `ItemWeapon` resource (data: `WeaponStats`, `scene`, `upgrade_to`) → weapon scene that inherits `weapon_base.tscn` (`Weapon`) → `WeaponBehavior` child, either `MeleeBehavior` (a tween lunge that toggles a hitbox) or `RangeBehavior` (spawns a `Projectile` under the tree root).
- `Weapon` targets the closest enemy inside its range `Area2D`. The radius is set from `stats.max_range`. Non-common tiers get an outline shader (`shaders/outline.gdshader`).
- The player holds at most 6 weapons. `WeaponContainer` positions them using marker groups `One`…`Six`, and each group must have exactly N children. Combining two weapons with the same `item_name` replaces them with `upgrade_to`.
- Final damage = weapon damage + `player.stats.damage`, with crits from `WeaponStats.crit_*`.

### Items (`resources/items/`)
`ItemBase` (name, icon, tier, type, cost, `get_description()` returning BBCode) has three subclasses:
- `ItemWeapon`
- `ItemUpgrade`, which adds `value` to the stat named by `stat_id`
- `ItemPassive`, which adds `add_value` to `add_stat` and subtracts `remove_value` from `remove_stat`

Stat names are plain strings that must match `UnitStats` property names. The shop pool is the `shop_items` export on ShopPanel, and the upgrade pool is `upgrade_list` on UpgradePanel. Both are set in `arena.tscn`.

## Conventions and gotchas
- Scripts reference scenes and resources through `preload("uid://...")`. Keep the `.uid` and `.import` files alongside their sources, and prefer editing scenes in the editor over hand-editing `.tscn` files.
- Many identifiers are misspelled and are referenced by those names in scenes and signal connections: `upgrage_panel`, `chanrge_behavior`, `WaveDate`, `on_wave_complited`, `SHOP_PRPBABILITY_CONFIG`, `damege_increase_pre_wave`, `fixsed_spawn_time`, `atack_duration`. Renaming one requires updating the matching `.tscn` connections.
- `UnitStats` resources are shared and mutated at runtime by upgrades, passives and per-wave scaling. Remember this when adding new stat logic.
- Classes are registered with `class_name` and use static typing throughout. Follow the same pattern.
