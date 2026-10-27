# Signals and run flow

Every signal in the game, who emits it and who listens, plus the full run lifecycle with `Global.game_paused` transitions and save/load points. Line numbers are for the current `master` (commit `0acbae2`).

## 1. `Global` event-bus signals (`autoloads/global.gd`)

Only `Arena` connects to them, and only in code (`scenes/arena/arena.gd:21-26`). No `.tscn` connects to a `Global` signal.

| Signal (decl.) | Args | Emitted by | Connected by → handler | What the handler does |
|---|---|---|---|---|
| `on_create_block_text` (`global.gd:3`) | `unit: Node2D` | `Unit._on_hurtbox_component_on_damaged` when the block roll succeeds, `scenes/units/unit.gd:25` | `arena.gd:22` → `_on_create_block_text` `arena.gd:123` | Floating text "Blocked!" in `block_color` |
| `on_create_damage_text` (`global.gd:4`) | `unit: Node2D, hitbox: HitboxComponent` | `Unit._on_hurtbox_component_on_damaged` after `take_damage`, `unit.gd:30` | `arena.gd:23` → `_on_create_damage_text` `arena.gd:127` | Floating text `str(hitbox.damage)`, `critical_color` if `hitbox.critical`, otherwise `normal_color` |
| `on_create_heal_text` (`global.gd:5`) | `unit: Node2D, heal: float` | `Player._on_hp_regen_timer_timeout` `scenes/units/players/player.gd:117`, `WeaponBehavior.apply_life_steal` `scenes/weapons/weapon_behavior.gd:26` | `arena.gd:25` → `_on_create_heal_text` `arena.gd:133` | Floating text `"+ %s"` in `hp_color` |
| `on_upgrade_selected` (`global.gd:7`) | none | `UpgradeCard._on_custom_button_pressed` `scenes/ui/upgrade_card/upgrade_card.gd:24` (after `item_data.apply_upgrade()`) | `arena.gd:24` → `_on_upgrade_selected` `arena.gd:62` | Hides UpgradePanel, `shop_panel.load_shop(wave_index)`, shows ShopPanel, `save_progress()` |
| `on_enemy_died` (`global.gd:8`) | `emeny: Enemy` (sic) | `Enemy._on_health_component_on_unit_died` `scenes/units/enemies/enemy.gd:100` | `arena.gd:26` → `_on_enemy_died` `arena.gd:146` | `spawn_coin(enemy)`: a `Coins` with `value = enemy.stats.gold_drop`, added with `call_deferred` |

Floating text is created by `Arena.create_floating_text` (`arena.gd:96-102`): a `FLOATING_TEXT_SCENE` instance added to `get_tree().root` near the unit. It frees itself after its tween (`scenes/ui/floating_text/floating_text.gd:14-30`).

## 2. Local (scene) signals

| Signal (decl.) | Args | Emitter | Connection (where) → handler |
|---|---|---|---|
| `Spawner.on_wave_complited` `scenes/arena/spawner.gd:4` | none | `spawner.gd:146` in `_on_wave_timer_timeout` | `arena.tscn:112` → `Arena._on_spawner_on_wave_complited` `arena.gd:138` |
| `SelectionPanel.on_selection_complited` `scenes/ui/selection_panel/selection_panel.gd:4` | none | `selection_panel.gd:72` (Continue pressed with a character and a weapon chosen) | `arena.tscn:116` → `Arena._on_selection_panel_on_selection_complited` `arena.gd:155` |
| `StartMenu.on_continue_selected` `scenes/ui/start_menu/start_menu.gd:4` | none | `start_menu.gd:10` | `arena.tscn:117` → `_on_start_menu_on_continue_selected` `arena.gd:166` → `continue_saved_game()` |
| `StartMenu.on_new_game_selected` `start_menu.gd:5` | none | `start_menu.gd:16` | `arena.tscn:118` → `_on_start_menu_on_new_game_selected` `arena.gd:170` (deletes the save, shows SelectionPanel) |
| `ShopPanel.on_shop_next_wave` `scenes/ui/shop_panel/shop_panel.gd:6` | none | `shop_panel.gd:81` (NewWaveButton) | `arena.tscn:115` → `Arena._on_shop_panel_on_shop_next_wave` `arena.gd:149` |
| `ShopCard.on_item_purchased` `scenes/ui/shop_card/shop_card.gd:4` | `item: ItemBase` | `shop_card.gd:33` (after `Global.coins -= item_cost`) | code: `shop_panel.gd:33` → `ShopPanel._on_item_purchased` `shop_panel.gd:63` |
| `ItemCard.on_item_card_selected` `scenes/ui/item_card/item_card.gd:4` | `card: ItemCard` | `item_card.gd:20`, **only for `ItemType.WEAPON`** | code: `shop_panel.gd:39` → `ShopPanel._on_item_card_selected` `shop_panel.gd:47` |
| `HealthComponent.on_health_changed` `scenes/components/health_component.gd:5` | `current: float, max: float` | `health_component.gd:15,25,40` | `unit.tscn:290` → `HealthBar._on_health_component_on_health_changed` `scenes/ui/health_bar.gd:30` |
| `HealthComponent.on_unit_died` `health_component.gd:6` | none | `health_component.gd:28`, right before `die()` (which `owner.queue_free()`s) | `enemy_base.tscn:68` → `Enemy._on_health_component_on_unit_died` `enemy.gd:97`. **Player: not connected.** |
| `HealthComponent.on_unit_hit` `health_component.gd:4` | none | `health_component.gd:24` | **nobody** (dead signal) |
| `HurtboxComponent.on_damaged` `scenes/components/hurtbox_component.gd:4` | `hitbox: HitboxComponent` | `hurtbox_component.gd:9` on `area_entered` of a `HitboxComponent` | `unit.tscn:289` → `Unit._on_hurtbox_component_on_damaged` `unit.gd:19` (`Enemy` overrides it at `enemy.gd:87` to add knockback) |
| `HitboxComponent.on_hit_hurtbox` `scenes/components/hitbox_component.gd:4` | `hurtbox: HurtboxComponent` | `hitbox_component.gd:31` (also plays `Sound.ENEMY_HIT`) | `projectile_pistol.tscn:28` → `Projectile._on_hitbox_component_on_hit_hurtbox` `scenes/weapons/projectiles/projectile.gd:21` (`queue_free`). Melee hitboxes: not connected |

Built-in signal connections in scenes:

| Scene:line | Signal → method |
|---|---|
| `arena.tscn:113-114` | `Spawner/SpawnTimer.timeout` → `Spawner._on_spawn_timer_timeout` (`spawner.gd:136`); `Spawner/WaveTimer.timeout` → `Spawner._on_wave_timer_timeout` (`spawner.gd:144`) |
| `unit.tscn:291` | `FlashTimer.timeout` → `Unit._on_flash_timer_timeout` (`unit.gd:33`, clears the flash material) |
| `enemy_base.tscn:69` | `KnockbackTimer.timeout` (0.4 s) → `Enemy._on_knockback_timer_timeout` |
| `player_well_rounded.tscn:155-157` | `DashTimer.timeout` → `_on_dash_timer_timeout`; `TrailTimer.timeout` → `Visuals/Trail._on_trail_timer_timeout`; `HPRegenTimer.timeout` (3 s, autostart) → `_on_hp_regen_timer_timeout`. `DashCooldownTimer` has no connection (polled with `is_stopped()`) |
| `weapon_base.tscn:37-38` | `RangeArea.area_entered/area_exited` → `Weapon._on_range_area_area_entered/exited` (`weapon.gd:110,113`) |
| `hitbox_component.tscn:8`, `hurtbox_component.tscn:8`, `coins.tscn:53` | self `area_entered` → `_on_area_entered` |
| `projectile_pistol.tscn:29` | `VisibleOnScreenNotifier2D.screen_exited` → `Projectile.queue_free` |
| `item_card.tscn:21`, `selection_card.tscn:13-14` | `pressed` (and `mouse_entered` for SelectionCard) → UI sound / emit |
| `selection_panel.tscn:269`, `shop_card.tscn:129`, `shop_panel.tscn:335-337`, `start_menu.tscn:42-43`, `upgrade_card.tscn:71` | button `pressed` → panel handlers |

Code connections besides those above: `selection_panel.gd:34,44` connect each `SelectionCard.pressed` to `_on_player_selected.bind(stats)` / `_on_weapon_selected.bind(item)`. `melee_behavior.gd:23` connects `tween.finished` to a lambda that disables the hitbox.

## 3. Run lifecycle

```
Arena._ready (arena.gd:21)
 ├─ use_save_data && ProgressData.has_save_file() ─► SelectionPanel.hide, StartMenu.show
 │     StartMenu ──Continue──► continue_saved_game() ──► (shop state, game_paused = true) ─┐
 │               └─New game──► ProgressData.delete_save(), SelectionPanel.show            │
 └─ else: SelectionPanel visible (default)                                                  │
SelectionPanel ──on_selection_complited──► spawn player + first weapon, Spawner.start_wave, game_paused = false
      ▼                                                                                     │
WAVE (WaveTimer runs, SpawnTimer spawns)                                                    │
      ▼ WaveTimer.timeout                                                                   │
Spawner._on_wave_timer_timeout: stop spawns, emit on_wave_complited, clear_enemies,         │
      harvesting coins, game_paused = true                                                  │
      ▼ Arena: clean_arena, wait 1.0 s, UpgradePanel                                        │
UpgradePanel ──Global.on_upgrade_selected──► ShopPanel (+ save) ◄───────────────────────────┘
      ▼ NewWaveButton ──on_shop_next_wave──► save, hide shop, start_new_wave (game_paused = false, wave_index += 1)
      └──────────────────────────────► WAVE …   (endless: there is no win or lose state)
```

### Step by step

1. **Boot.** Autoloads load first. `Global.game_paused` starts `false` and `Global.coins` starts `20` (`global.gd:44-45`). `Arena._ready` connects the bus signals (`arena.gd:22-26`). `Spawner._ready` stores the wave-1 `health`/`damage` of each `enemy_collection` stat in `enemy_base_stats` (`spawner.gd:24-26`). `arena.tscn:35` sets `use_save_data = true`. If a save exists, `StartMenu` is shown and `SelectionPanel` hidden (`arena.gd:28-30`). Otherwise `SelectionPanel` stays visible (it isn't hidden in `arena.tscn:99-100`). While no player exists, `game_paused` is `false`, so `Arena._process` refreshes the wave labels.
2. **StartMenu** (`start_menu.gd`). Both buttons hide the menu first.
   - *Continue* → `Arena.continue_saved_game` (`arena.gd:32-60`): `ProgressData.load_game()`. If `has_saved_game` stays false, `SelectionPanel` is shown and the function returns. Otherwise it shows `ShopPanel`, instantiates `Global.available_player[current_player_name]`, adds it to Arena (so `_ready`→`health_component.setup` runs with the *unsaved* `.tres` health), writes every saved stat back with `stats.set`, re-adds `Global.equipped_weapons` (filled by `load_game`) as weapon nodes, recreates the weapon cards (`my_weapons`) and passive cards (`my_passives`, **not** re-applied because the saved stats already include them), sets `spawner.wave_index`, calls `shop_panel.load_shop(wave_index)` and sets `game_paused = true`.
   - *New game* → `ProgressData.delete_save()` + `selection_panel.show()` (`arena.gd:170-172`).
3. **SelectionPanel** (`selection_panel.gd`). `_ready` frees the placeholder buttons and builds one `SelectionCard` per `players` / `start_weapon` entry (exports in `selection_panel.tscn:41-42`). A click sets `Global.main_player_selected` / `Global.main_weapon_selected` (`:56`, `:64`). *Continue* needs both, then emits `on_selection_complited` and hides the panel (`:67-73`).
4. **Run start** (`arena.gd:155-163`). `Global.get_selected_player()` instantiates `available_player[stats.name]` and sets `Global.player` (`global.gd:66-70`). Arena adds the player, `player.add_weapon(main_weapon_selected)`, creates the weapon card in the shop, appends to `Global.equipped_weapons`, calls `spawner.start_wave()` and sets **`game_paused = false`**. `wave_index` is `1` (`spawner.gd:18`).
5. **Wave** (`spawner.gd:111-127`). `find_wave_data()` returns the `WaveDate` whose `from..to` contains `wave_index`, or the one with the highest `to` (endless). Then `scale_enemies_for_wave()` **mutates** each `enemy_collection` stat: `health = base + int(health_increase_pre_wave*(w-1))`, `damage = base + damege_increase_pre_wave*(w-1)`. `WaveTimer.wait_time = wave_time` and `set_spawn_timer()` runs. Each `SpawnTimer.timeout` → `spawn_enemy()`: pick a weighted scene (`wave_data.gd:20-34`), add an `EnemySpawnEffect` to Arena, **restart SpawnTimer** (`spawner.gd:84`), await the 0.8 s `spawn` animation, then instantiate the enemy under Arena and append it to `spawned_enemies`. Spawn time is `fixsed_spawn_time` (FIXED) or `randf_range(min,max)` (RANDOM), multiplied by `max(endless_min_spawn_multiplier, (1-endless_spawn_time_decrease)^endless_waves)` (`spawner.gd:53-66`).
   - During a wave: enemies chase the player. Weapons target the nearest enemy in their `RangeArea`, and hits go `HitboxComponent` → `HurtboxComponent.on_damaged` → `Unit._on_hurtbox_component_on_damaged` (block roll `stats.block_chance/100`, flash, `take_damage`, damage text). At 0 HP `HealthComponent` emits `on_unit_died` and immediately `owner.queue_free()`s (`health_component.gd:27-32`). For enemies, that emits `Global.on_enemy_died` → coin drop. Coins fly to the player once its root area overlaps them (`coins.gd:15-17,32-33`) and add `value` to `Global.coins` (`coins.gd:35-37`). `Player` heals `hp_regen` every 3 s (`player.gd:108-117`).
6. **Wave end** (`spawner.gd:144-149`). `spawn_timer.stop()`, then `on_wave_complited.emit()`. That runs `Arena._on_spawner_on_wave_complited` synchronously up to its `await` (`arena.gd:138-144`): it returns early if `Global.player` is falsy, otherwise calls `clean_arena()` (sends every alive coin in `gold_list` to the CoinsBag screen position and calls `spawner.clear_enemies()` → `Enemy.destroy_enemy()` plays `die` and frees). Back in Spawner: `clear_enemies()` again, `Global.get_harvesting_coins()` (`coins += int(player.stats.harvesting)`), **`Global.game_paused = true`**. One second later Arena calls `show_upgrades()` (`upgrage_panel.load_upgrades(wave_index)` + show) and `clean_arena()` once more.
7. **UpgradePanel** (`upgrage_panel.gd:9-18`). It clears the cards and rolls 4 distinct `ItemUpgrade`s with `Global.select_items_from_offer(upgrade_list, wave_index, UPGRADE_PRPBABILITY_CONFIG)`. A click → `ItemUpgrade.apply_upgrade()` (`stats.set(stat_id, stats.get(stat_id) + value)`, `item_upgrade.gd:8-11`) → `Global.on_upgrade_selected`.
8. **Shop** (`arena.gd:62-66`). `upgrage_panel.hide()`, `shop_panel.load_shop(wave_index)` (4 distinct items from `shop_items` with `SHOP_PRPBABILITY_CONFIG`), `shop_panel.show()`, `save_progress()`. Inside the shop:
   - **Buy** (`shop_card.gd:26-34`): refused if it's a weapon and `Global.equipped_weapons.size() >= 6`. If `coins >= item_cost`: coins are deducted, `on_item_purchased` fires and the card frees itself. A weapon gets a card in `WeaponsContainer` plus `player.add_weapon` plus `equipped_weapons.append`. A passive gets a card in `PassivesContainer` plus `ItemPassive.apply_passive()` (`shop_panel.gd:63-77`).
   - **Select a weapon card** → `contecst_card`. `CombineButton.disabled = not (≥2 equipped with the same item_name)` (`shop_panel.gd:47-61`).
   - **Combine** (`shop_panel.gd:84-123`): removes 2 weapon nodes, their `equipped_weapons` entries and 2 cards with that `item_name`, then adds `upgrade_to` as a weapon and a card.
   - **Sell** (`shop_panel.gd:126-146`): removes the first weapon node with that `item_name` and its card, and adds `int(item_cost * 0.75)` coins.
   - **Next wave** → `on_shop_next_wave` → `Arena._on_shop_panel_on_shop_next_wave` (`arena.gd:149-152`): `save_progress()` (the shop is still visible, so the save goes through), `shop_panel.hide()`, `start_new_wave()`.
9. **Next wave** (`arena.gd:79-83`). **`game_paused = false`**, `wave_index += 1`, `spawner.start_wave()` (re-scales the enemy stats), `player.update_player_new_wave()` (`stats.health += health_increase_pre_wave`, then `health_component.setup(stats)` → **full heal** to the new max, `player.gd:96-98`). Loop back to step 5.
10. **Player death.** There is no handler. The player node is freed by `HealthComponent.die()`, the wave timer keeps running, and the wave end then crashes in `Global.get_harvesting_coins()` (see `known-issues.md` §1.3).

### `Global.game_paused` transitions

| Value | Where | When |
|---|---|---|
| `false` | `global.gd:44` | Initial value (title / selection screens) |
| `false` | `arena.gd:163` | Run started from SelectionPanel |
| `true` | `spawner.gd:149` | Wave timer ended |
| `false` | `arena.gd:80` | `start_new_wave()` from the shop |
| `true` | `arena.gd:60` | `continue_saved_game()` (resumes in the shop) |

Readers that return early when paused: `Arena._process` `arena.gd:73`, `Enemy._process` `enemy.gd:15`, `ChargeBehavior._process` `chanrge_behavior.gd:18`, `ShootingBehavior._process` `shooting_behavior.gd:21`, `Player._process` `player.gd:31`, `Weapon._process` `weapon.gd:21`.
These ignore the flag: `Projectile._process` (`projectile.gd:7`), `Coins._process` (on purpose, coins fly to the bag), `Trail`, `Camera`, `StatsContainer`, `CoinsBag`, all `Timer`s (HPRegen, Flash, Knockback, Dash), all `AnimationPlayer`s and tweens, and the pending `await` in `Spawner.spawn_enemy`.

### Save / load (`autoloads/progress_data.gd`)

| Event | Call | Notes |
|---|---|---|
| Upgrade picked | `arena.gd:66` `save_progress()` → `ProgressData.save_game()` | After `shop_panel.show()`, so `can_save()` passes |
| Next wave pressed | `arena.gd:150` | Before `shop_panel.hide()`; saves the wave that *just finished* |
| Window close | `progress_data.gd:103-105` (`NOTIFICATION_WM_CLOSE_REQUEST`) | Saves only if the shop is visible |
| Continue | `arena.gd:33` `ProgressData.load_game()` | Invalid JSON or an unknown character → `printerr` + `delete_save()` |
| New game | `arena.gd:171` `ProgressData.delete_save()` | |

`can_save()` (`progress_data.gd:22-27`) needs a valid `Global.player`, an `arena`-group node with `use_save_data` set, and `shop_panel.visible`. The JSON at `user://data.sav` has the keys `coins`, `current_wave` (`spawner.wave_index`), `current_player_name` (`stats.name`), `player_stats` (every `TYPE_FLOAT`/`TYPE_INT` script property of `UnitStats`, `type` included), `equipped_weapons` (resource paths from `Global.equipped_weapons`), `purchased_weapons` (paths of every card in `WeaponsContainer`) and `purchased_passives` (paths of every card in `PassivesContainer`). The current shop offers are **not** saved, so they are re-rolled on Continue.

### What persists between waves

| Persists | Where it lives |
|---|---|
| Coins | `Global.coins` |
| Player node, its weapon nodes, its mutated stats | `Global.player`, `Player.current_weapons`, shared `UnitStats` `.tres` |
| Equipped weapon resources | `Global.equipped_weapons` (`Array[ItemWeapon]`, ≤ 6) |
| Owned weapon / passive cards | `ShopPanel.weapons_container` / `passives_container` children |
| Wave number | `Spawner.wave_index` |
| Scaled enemy stats | the shared enemy `UnitStats` resources (recomputed from `enemy_base_stats` each wave) |
| Leftover projectiles and in-flight spawns | root / Arena children that nothing clears |

| Reset each wave | How |
|---|---|
| Enemies | `spawner.clear_enemies()` |
| Ground coins | `clean_arena()` flies them to the CoinsBag (they're collected even while paused) |
| Player HP | `update_player_new_wave()` → full heal |
| Shop offers / upgrade offers | Re-rolled in `load_shop` / `load_upgrades` |
| Combine selection | `contecst_card` is only cleared after a combine or sell |
