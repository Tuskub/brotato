# Known issues

Bugs, dead code, data mistakes and risky patterns found by reading the code on `master` (`0acbae2`). **None of them is fixed.** This is a catalog: check the cited line before relying on an entry, and remove the entry when you fix the issue. Severity: **H** breaks gameplay, **M** visible wrong behavior or a trap for future changes, **L** cosmetic or dead.

## 1. Gameplay bugs

### 1.1 (H) Enemy contact damage is always 1.0, so enemy `damage` and its per-wave scaling do nothing
- Where: `scenes/units/enemies/enemy_base.tscn:47-49` instances a `HitboxComponent`, but no code calls `setup()` on it (`grep -n "setup(" scenes` finds only melee, projectiles, health and floating text). `HitboxComponent.damage` keeps its default `1.0` (`scenes/components/hitbox_component.gd:6`).
- Impact: every chaser and charger hits for 1 HP on wave 1 and on wave 100. `UnitStats.damage` and `damege_increase_pre_wave` only matter for Shooter projectiles (`shooting_behavior.gd:60`), and Shooter never spawns (§1.4). The enemy scaling in `Spawner.scale_enemies_for_wave` is half dead.

### 1.2 (H) Every weapon shares one `RangeArea` shape, so the last weapon set up decides every weapon's range
- Where: `scenes/weapons/weapon_base.tscn:13-14` defines `CircleShape2D_vffjk` without `resource_local_to_scene` (the outline `ShaderMaterial` above it has it). `Weapon.setup_weapon` writes `collision.shape.radius = data.stats.max_range` (`scenes/weapons/weapon.gd:37`).
- Checked headless: an axe and a pistol instance return the same `shape` object (`axe==pistol true`), while their materials are distinct.
- Impact: buying an SMG (320) after a Laser (450) shrinks the laser's targeting to 320, and buying a Laser gives melee weapons a 450 px acquisition radius. Melee then lunges at targets far outside its `max_range` lunge.

### 1.3 (H) Player death has no handling and crashes at wave end
- Where: `HealthComponent.take_damage` → `die()` → `owner.queue_free()` (`scenes/components/health_component.gd:27-32`). `Player` doesn't connect `on_unit_died` (only `enemy_base.tscn:68` does). Nothing sets a game-over state.
- Then: the wave timer keeps running. `Arena._on_spawner_on_wave_complited` returns early because `not Global.player` is true for a freed object (checked headless), but `Spawner._on_wave_timer_timeout` goes on to `Global.get_harvesting_coins()` → `player.stats.harvesting` on a freed instance (`scenes/arena/spawner.gd:148`, `autoloads/global.gd:73`), which is a script error. Weapons die with the player, the save stays at the last shop, and there's no way back to the menu.

### 1.4 (H) Charger and Shooter never spawn; wave data is a single misnamed entry
- Where: `resources/waves/data/wave_1_to_5.tres` is the only `WaveDate` (`arena.tscn:50`). It lists only `enemy_chaser_slow` (6), `_mid` (3) and `_fast` (1). Endless mode reuses it (`spawner.gd:33-42`).
- Also: the file name says 1–5, but `from = 1`, `to = 10`. `spawn_type = 0` (FIXED), so `min_spawn_time`/`max_spawn_time` (0.5/2.0) are ignored. `wave_time` isn't set (20 s default).
- Impact: `enemy_charger.tscn`, `enemy_shooter.tscn`, `ChargeBehavior`, `ShootingBehavior` and `projectile_enemy.tscn` are unreachable in play. Their stats are still scaled every wave because they're in `enemy_collection`.

### 1.5 (M) Mace I loads a different stats file than its path says; other weapon refs have stale UIDs
- `resources/items/weapons/melee/mace/item_mace_1.tres:6`: `uid="uid://d0gevuo634gkv" path=".../stats_mace_1.tres"`. That UID belongs to `stats_mece_1.tres` (sic), and Godot prefers the UID, so Mace I has damage 10, cooldown 2.0, range 160, `atack_duration` 0.4 (checked headless). `stats_mace_1.tres` (`uid://bsofskutm4xkh`) is never loaded. Fixing the "typo" file name, or deleting `stats_mece_1.tres`, silently changes Mace I.
- `item_mace_2.tres:6` (`uid://b2vgpc47q00v2`) and `item_mace_4.tres:6` (`uid://b2vgpc47q00v4`) point to UIDs that don't exist, so they fall back to the path. These and the stale `item_upgrade.gd` script UIDs in all 46 upgrade `.tres` (`uid://0kfyb4qfa66q` / `uid://cr0po024cxfg5` vs the real `uid://ti87pqqmd7ro`) produce the "invalid UID … using text path instead" boot warnings.
- No UID at all: `arena.tscn:15` → `start_menu.tscn` (whose header has no `uid`), `start_menu.tscn:3` → `start_menu.gd`, and `item_smg_1/item_shotgun_1/item_revolver_1.tres:7` → their tier-II `upgrade_to`. These only work by path, so moving the files breaks them.

### 1.6 (M) Tier-I Pistol, Shotgun and Laser deal 1 base damage; other weapon data anomalies
- `stats_pistol_1.tres`, `stats_shotgun_1.tres` and `stats_laser_1.tres` don't set `damage`, so they use the default `1.0` (`weapon_stats.gd:4`). `stats_shotgun_1` also leaves `max_range` at the default 150. Three of the 11 starting weapons do only `1 + player.damage` per hit.
- Laser IV (`stats_laser_4.tres`: damage 8, cooldown 2.0, crit 0.10, life_steal 0.05) is much weaker than Laser III (45 / 1.1 / 0.20 / 0.15). Laser II's cooldown 1.7 is slower than Laser I's 0.6. Revolver III's damage equals Revolver II's (20). Punch II–IV lose Punch I's knockback 1.5. Mace III/IV keep the default crit 0.05.
- `item_punch_4.tres` has `item_name = "Puch IV"`. Combining matches on `item_name`, so this is harmless today but would break a lookup by name.
- `ItemWeapon.type` is `RANGE` only for laser, revolver, shotgun and smg. Pistol is `MELEE` (the default). The field is unused (§3).

### 1.7 (M) Dash gives no invulnerability and blocks coin pickup instead
- `Player.start_dash` disables the root `CollisionShape2D` (`player.gd:77`). That shape only serves coin detection (`coins.tscn` mask 1 → the player root). The `HurtboxComponent` (layer 32) stays active.
- Impact: the player takes full damage while dashing and can't pick up coins during the dash.

### 1.8 (M) Weapon spread accumulates forever
- `Weapon.calculate_spread` does `weapon_spred += randf_range(-1 + accuracy, 1 - accuracy)` and never resets it (`weapon.gd:77-79`). The value is added to the aim during attacks (`weapon.gd:57`).
- Impact: for `accuracy < 1` (SMG 0.6, Revolver 0.7, Mace/Shotgun 0.8, Pistol II+ 0.85, Chainsaw 0.9) the aim offset is a random walk that grows with every shot, so long runs end up shooting sideways.

### 1.9 (M) Enemies can spawn after the wave has ended
- `Spawner.spawn_enemy` awaits the 0.8 s spawn animation (`spawner.gd:85`) and then instantiates the enemy without re-checking `wave_timer`/`game_paused` (`spawner.gd:88-91`).
- Impact: a spawn that starts in the last 0.8 s of a wave appears after `clear_enemies()`. It sits frozen through the upgrade/shop screens, survives into the next wave and doesn't count against it. The same await keeps running across a pause.

### 1.10 (M) Shop combine/sell logic edge cases
- `_on_combine_button_pressed` aborts only if *both* lists have fewer than 2 entries (`shop_panel.gd:98`, `and` should be `or`). If the nodes and cards ever disagree, it removes 1 weapon and still grants the upgrade.
- `can_merge` (`shop_panel.gd:50-61`) doesn't check `upgrade_to`, so the Combine button is enabled for tier-IV weapons and then does nothing. `combine_button.disabled` is never reset after a combine or sell, while `contecst_card` is set to null.
- After **Sell**, the remaining weapons aren't repositioned. `WeaponContainer.update_weapons_position` runs only in `Player.add_weapon` (`player.gd:91`). After a combine, the repositioning happens through `add_weapon`.
- Sell takes `.front()` of a filter result (`shop_panel.gd:135-136`), which errors on an empty array if a card exists with no matching weapon node.

### 1.11 (M) Things that keep running while `game_paused`
- `Projectile._process` has no pause check (`projectile.gd:7-9`), and projectiles live under the tree root, which nothing clears. Shots fired at wave end keep flying through the upgrade/shop screens, and enemy projectiles can still hit the player there.
- `HPRegenTimer` (3 s, autostart) keeps healing and spawning "+N" texts during the shop (`player.gd:108-117`). The flash, knockback and dash timers, the `AnimationPlayer`s and the spawn-effect awaits ignore the flag too. Only `_process` methods check it (list in `signals-and-flow.md`).

### 1.12 (M) Kill animation never plays
- `HealthComponent.die()` calls `owner.queue_free()` in the same frame as `on_unit_died` (`health_component.gd:28-32`). `Enemy.destroy_enemy()` (which plays `die` and then frees, `enemy.gd:28-35`) is only used by `Spawner.clear_enemies`. Killed enemies vanish instantly; enemies cleared at wave end animate.

### 1.13 (L) Smaller logic issues
- **Idle melee hitboxes are live until the first swing.** In axe, chainsaw, mace, sword and wand the `HitboxComponent` starts with the default `monitoring = true` (only `weapon_punch.tscn:21-22` disables it), damage 1.0 and no source, until the first `tween.finished` → `disable()` (`melee_behavior.gd:23-27`).
- **Life steal rolls once per attack, not per hit,** including ranged shots that miss. It always heals a flat 1.0 (`weapon_behavior.gd:20-26`, `melee_behavior.gd:19`, `range_behavior.gd:17`).
- **Contact damage only on `area_entered`** (`hurtbox_component.gd:7-9`). An enemy standing on the player deals damage once until it leaves and re-enters.
- **`ENEMY_HIT` sound plays for every hit,** including hits on the player (`hitbox_component.gd:28-31`).
- **Coins near the origin auto-collect.** `Coins._process` measures the distance to `target_pos` even when it is still `Vector2.ZERO` (`coins.gd:22-26`), so a coin dropped within 15 px of (0,0) is collected immediately.
- **Max HP changes don't apply until the next wave.** `HealthComponent.max_health` is only refreshed in `setup()`. Health upgrades and Cape's −2 health don't change the bar until `update_player_new_wave` (`player.gd:96-98`), which also fully heals. On Continue, `setup()` runs in `_ready` before the saved stats are written (`arena.gd:41-45`).
- **No common offers late in the run.** Tier normalization drives common odds to 0 % from shop wave 10 and upgrade wave 15 (`data-catalog.md` §7). Tier-I weapons and the Cape and Power ball passives stop appearing, so a single tier-I weapon can never be paired for a combine after that.
- **Free shop reroll.** Saves skip the current offers, so quitting in the shop and pressing Continue rerolls them (`arena.gd:59`). Quitting mid-wave loses that wave's coins and progress (`can_save()` requires the shop to be visible, `progress_data.gd:27`).
- **Unbounded fills.** `Global.select_items_from_offer` loops `while offered_items.size() < 4` (`global.gd:134`) with no exit. A pool with fewer than 4 distinct items, or an empty pool, freezes the game. `WeaponContainer.update_weapons_position` dereferences `reference_node` without a null check for counts outside 1–6 (`weapon_container.gd:15-23`).
- **Mixed liveness checks.** `if not Global.player` (`arena.gd:139`, `progress_data.gd:23`) and `is_instance_valid(Global.player)` are both used. `Weapon.get_idle_rotation` (`weapon.gd:67`) and `WeaponBehavior.get_damage` (`weapon_behavior.gd:12`) read `Global.player` with no check at all.

## 2. Risky patterns

### 2.1 (M) Shared, mutated `UnitStats`
- Player stats: `ItemUpgrade.apply_upgrade`, `ItemPassive.apply_passive`, `Player.update_player_new_wave` and `Arena.continue_saved_game` write straight into the character's `.tres` instance (`item_upgrade.gd:11`, `item_passive.gd:25-28`, `player.gd:97`, `arena.gd:45`). The Selection screen, StatsContainer and the save read the same object. Any in-session restart (no such feature exists yet) would start from the mutated values.
- Enemy stats: `Spawner.scale_enemies_for_wave` overwrites `health`/`damage` on the shared enemy `.tres` (`spawner.gd:96-101`). The wave-1 values are captured in `Spawner._ready` (`spawner.gd:24-26`). If an Arena were ever re-instantiated in the same session (`reload_current_scene`), `_ready` would capture already-scaled values and the scaling would compound. An enemy stats resource missing from `enemy_collection` is never scaled, and `enemy_base_stats[stat]` lookups assume every entry was captured.
- Two enemy scenes sharing one stats `.tres` would be scaled twice per wave.

### 2.2 (M) Stats addressed by plain strings
- `ItemUpgrade.stat_id`, `ItemPassive.add_stat` / `remove_stat` (`item_passive.gd:25,28`) and the save's `player_stats` keys must equal `UnitStats` property names, misspellings included. A typo makes `stats.get()` return null (→ `float(null)` error) or `stats[x] += …` raise at purchase time. Nothing validates them on load.
- `ProgressData.save_game` reflects over *every* int/float script property (`progress_data.gd:46-48`), including the `type` enum, so renaming a `UnitStats` property silently orphans old saves' values.
- Int-typed stats (`health`, `speed`, `gold_drop`) receive float writes: `stats.set(stat_id, float)` (`item_upgrade.gd:11`), `stats.health += health_increase_pre_wave` (float, `player.gd:97`), and JSON-loaded floats (`arena.gd:45`). Fractional parts are truncated, so a per-wave health gain of 0.5 adds nothing. Every character currently uses `0.0`.

### 2.3 (L) Scene and identity coupling
- `Global.available_player` is keyed by `UnitStats.name` (`global.gd:35-41`, `global.gd:67`, `arena.gd:40`, `progress_data.gd:79`). Renaming a character's display name breaks spawning and invalidates saves.
- `player_well_rounded.tscn` is both a playable character and the base scene of the other four players, so editing it changes every character.
- `Arena` is found through the `arena` group (`progress_data.gd:26,50`), and `can_save()` reads `arena.shop_panel.visible` as the "between waves" signal.
- `HealthComponent.die()` frees `owner`. That is correct only while the component is a direct part of a unit scene.

## 3. Dead code, unused stats and exports

| Item | Location | Note |
|---|---|---|
| `HealthComponent.on_unit_hit` | `health_component.gd:4,24` | Emitted, never connected |
| `UnitStats.type` / `UnitType` | `unit_stats.gd:4-10` | Set in the `.tres`, never read (except that the save stores it) |
| `UnitStats.luck` on enemies; `hp_regen`, `life_steal`, `harvesting` on enemies; `gold_drop`, `damege_increase_pre_wave` on players | `unit_stats.gd` | Never read for that unit kind |
| `ItemWeapon.type` / `WeaponType` | `item_weapon.gd:4-9` | Never read; also inconsistent data (§1.6) |
| `ItemBase.item_cost` for upgrades | all upgrade `.tres` (0) | Upgrades are free; never read |
| `WeaponStats.atack_duration`, `back_duration` for ranged; `projectile_scene`, `projectile_speed` for melee | `weapon_stats.gd`; `range_behavior.gd:14-15` uses `recoil_duration` twice | Set in many `.tres`, ignored |
| `ChargeBehavior.prep_time` | `chanrge_behavior.gd:6` | Export never read (the `charge` animation length 0.7 s is the real windup) |
| `WaveDate.min_spawn_time` / `max_spawn_time` | `wave_1_to_5.tres` | Ignored because `spawn_type` is FIXED |
| `class_name Camera` | `scenes/arena/camera_2d.gd:2` | Never referenced by type |
| Commented-out `enemy_collection` rebuild | `spawner.gd:119-122` | Dead |
| `SelectionPanel.player_title` (`%PlayerTitle`) | `selection_panel.gd:14,51` | Shown/hidden, its text is never set |
| `stats_mace_1.tres` | `resources/items/weapons/melee/mace/` | Orphan (§1.5) |
| Placeholder children in `.tscn` | `selection_panel.tscn:184-264`, `shop_panel.tscn:132-141,174-301`, `upgrage_panel.tscn:99-108` | Editor previews, freed at runtime |
| Debug `print` on every offer roll | `global.gd:116-117` | Spams stdout every wave |
| Unused `delta` params | `arena.gd:72`, `coins_bag.gd:6`, `stats_container.gd:14`, `weapon.gd:20` | Warnings only |
| Spanish comments | `shaders/outline.gdshader:11,17,23` | Rest of the code base is English |

## 4. Misspellings (real identifiers, keep them unless you rename every reference)

On top of the list in `CLAUDE.md` (`upgrage_panel`, `chanrge_behavior`, `WaveDate`, `on_wave_complited`, `SHOP_PRPBABILITY_CONFIG`, `damege_increase_pre_wave`, `fixsed_spawn_time`, `atack_duration`):

| Identifier | Where | Referenced from |
|---|---|---|
| `UPGRADE_PRPBABILITY_CONFIG` | `global.gd:29` | `upgrage_panel.gd:13` |
| `on_selection_complited`, `_on_selection_panel_on_selection_complited` | `selection_panel.gd:4`, `arena.gd:155` | `arena.tscn:116` |
| `UpgragePanel` (node name), `%UpgragePanel` | `upgrage_panel.tscn:60`, `arena.tscn:88` | `arena.gd:13` |
| `ChanrgeBehavior` (node name) | `enemy_charger.tscn:52` | — |
| `emeny` (signal param) | `global.gd:8` | — |
| `health_increase_pre_wave` ("pre" = per) | `unit_stats.gd:13` | `.tres`, `spawner.gd:100`, `player.gd:97` |
| `current_cooldonw` | `chanrge_behavior.gd:10` | same file |
| `set_flush_material` | `unit.gd:15` | `unit.gd:28` |
| `collission` | `player.gd:10` | `player.gd:77,104` |
| `get_free_steam_layer` | `sound_manager.gd:18` | `sound_manager.gd:26` |
| `get_chance_succes` | `global.gd:76` | `unit.gd:23`, `weapon_behavior.gd:14,22` |
| `contecst_card` | `shop_panel.gd:15` | same file |
| `crete_projectile` | `range_behavior.gd:23` | `range_behavior.gd:9` |
| `update_closes_target`, `weapon_spred` | `weapon.gd:81,14` | same file |
| `discription`, `stast` | `item_passive.gd:12`, `stats_container.gd:19` | locals |
| `stat_enemy_shoter.tres` / `name = "Shoter"` | `resources/units/enemies/` | `arena.tscn:21`, `enemy_shooter.tscn:7` |
| `stats_mece_1.tres` | `resources/items/weapons/melee/mace/` | `item_mace_1.tres` by UID (§1.5) |
| `weapon_lazer.tscn`, `projectile_lazer.tscn` (vs `laser/` data folder and "Laser" item names) | `scenes/weapons/` | laser `.tres` |
| `Player_3}.png` | `assets/sprites/Players/` | `player_crazy.tscn:4`, `stat_player_crazy.tres` |
| `"Puch IV"` | `item_punch_4.tres` `item_name` | combine-by-name |

## 5. Documentation drift in `CLAUDE.md` (for the coordinator; not edited here)

- It says the shop pool `shop_items` and the upgrade pool `upgrade_list` are "set in `arena.tscn`". They are set in `scenes/ui/shop_panel/shop_panel.tscn:96` and `scenes/ui/upgrade_panel/upgrage_panel.tscn:68`, and `arena.tscn` doesn't override them.
- It says ProgressData "saves … on window close". It also saves on upgrade pick (`arena.gd:66`) and on Next wave (`arena.gd:150`).
- It calls the charger behavior node `ChargeBehavior`. The class is `ChargeBehavior`, but the node in `enemy_charger.tscn:52` is `ChanrgeBehavior`.
