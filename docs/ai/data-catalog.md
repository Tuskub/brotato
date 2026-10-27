# Data catalog

All current game data, read from the `.tres` files. A value marked `*` is not stored in the `.tres`; it is the script default (`resources/units/unit_stats.gd`, `resources/items/weapons/weapon_stats.gd`, `resources/waves/wave_data.gd`, `resources/items/item_base.gd`). Godot omits default values when it saves, so `*` means "inherited default", not "missing".

Tier enum `Global.UpgradeTier` (`autoloads/global.gd:10-15`): 0 COMMON, 1 RARE, 2 EPIC, 3 LEGENDARY. `ItemBase.ItemType`: 0 WEAPON, 1 UPGRADE, 2 PASSIVE.

## 1. Characters (`resources/units/players/*.tres`, `type` = 0 PLAYER*)

All five are listed in `SelectionPanel.players` (`selection_panel.tscn:41`) and mapped by `name` in `Global.available_player` (`global.gd:35-41`).

| `name` (dict key) | Stats file | Scene | health | damage | speed | luck | block_chance % | harvesting | hp_regen | life_steal | +hp/wave |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Brawler | `stat_player_brawler.tres` | `player_brawler.tscn` | 25 | 4 | 270 | 3.0 | 5.0 | 0* | 0* | 0* | 0.0 |
| Bunny | `stat_player_bunny.tres` | `player_bunny.tscn` | 20 | 5 | 325 | 5.0 | 3.0 | 0* | 0* | 0* | 0.0 |
| Crazy | `stat_player_crazy.tres` | `player_crazy.tscn` | 15 | 3 | 350 | 5.0 | 5.0 | 0* | 0* | 0* | 0.0 |
| Knight | `stat_player_knight.tres` | `player_knight.tscn` | 30 | 6 | 260 | 1.0* | 10.0 | 0* | 0* | 0* | 0.0 |
| Well Rounded | `stat_player_well_rounded.tres` | `player_well_rounded.tscn` | 15 | 3 | 300* | 0.0 | 1.0 | 5.0 | 0* | 0* | 0.0 |

`damege_increase_pre_wave` is `0.0` for all players and isn't read for players anyway. `gold_drop` is 0 or unset (only enemies use it). Sprites: Player_2/4/`3}`/5/1.png. Starting coins: `Global.coins = 20` (`global.gd:45`). Shared player tuning (`player_well_rounded.tscn:23-25`, `player.gd`): dash 0.5 s at ×1.5 speed with a 0.5 s cooldown (`dash` = Space), HP regen tick every 3 s (`HPRegenTimer`), movement clamped to x ±1000 and y ±500 (`player.gd:47-48`).

Units of the stats: `block_chance`, `luck` and `life_steal` are percentages (each is divided by 100 where it is used: `unit.gd:23`, `global.gd:97`, `weapon_behavior.gd:21`). `harvesting` is the flat number of coins paid at wave end (`global.gd:72-73`). `hp_regen` is HP per 3 s tick. `damage` is added flat to every weapon hit (`weapon_behavior.gd:12`).

## 2. Enemies (`resources/units/enemies/*.tres`, `type` = 1 ENEMY)

| `name` | Stats file (UID) | Scene | health | +hp/wave | damage | +dmg/wave (`damege_…`) | speed | block % | gold_drop | Sprite |
|---|---|---|---|---|---|---|---|---|---|---|
| Chaser Slow | `stat_enemy_chaser_slow.tres` (`ckjfoti6xiyji`) | `enemy_chaser_slow.tscn` | 6 | 1.0* | 1.5 | 1.0* | 250 | 3.0 | 1* | Enemy_1 |
| Chaser Mid | `stat_enemy_chaser_mid.tres` (`1xd321qgf1vb`) | `enemy_chaser_mid.tscn` | 8 | 2.0 | 2.0 | 1.0* | 300* | 7.0 | 2 | Enemy_2 |
| Chaser Fast | `stat_enemy_chaser_fast.tres` (`mlvx6uebwl4x`) | `enemy_chaser_fast.tscn` | 6 | 2.5 | 1.5 | 1.5 | 350 | 5.0 | 2 | Enemy_3 |
| Charger | `stat_enemy_charger.tres` (`clhs08eeatohp`) | `enemy_charger.tscn` | 8 | 3.0 | 2.5 | 2.0 | 280 | 5.0 | 3 | Enemy_5 |
| Shoter (sic) | `stat_enemy_shoter.tres` (`beacl0wnixguy`) | `enemy_shooter.tscn` | 4 | 2.0 | 3.0 | 1.5 | 260 | 3.0 | 3 | Enemy_4 |

All five are in `Spawner.enemy_collection` (`arena.tscn:51`). **Only the three chasers are in any `WaveDate`** (see §6), so Charger and Shooter never spawn.

Per-wave scaling (`spawner.gd:96-101`) gives `health = base + int(inc × (w−1))` and `damage = base + inc × (w−1)`. Values as health / damage:

| Enemy | w1 | w2 | w5 | w10 | w15 | w20 |
|---|---|---|---|---|---|---|
| Chaser Slow | 6 / 1.5 | 7 / 2.5 | 10 / 5.5 | 15 / 10.5 | 20 / 15.5 | 25 / 20.5 |
| Chaser Mid | 8 / 2 | 10 / 3 | 16 / 6 | 26 / 11 | 36 / 16 | 46 / 21 |
| Chaser Fast | 6 / 1.5 | 8 / 3 | 16 / 7.5 | 28 / 15 | 41 / 22.5 | 53 / 30 |
| Charger | 8 / 2.5 | 11 / 4.5 | 20 / 10.5 | 35 / 20.5 | 50 / 30.5 | 65 / 40.5 |
| Shoter | 4 / 3 | 6 / 4.5 | 12 / 9 | 22 / 16.5 | 32 / 24 | 42 / 31.5 |

The `damage` column only reaches the player through Shooter projectiles (`shooting_behavior.gd:60`). Contact damage is always the `HitboxComponent` default `1.0` (`hitbox_component.gd:6`; see `known-issues.md` §1.1).

Shared enemy tuning: stop distance 60 px from the player (`enemy.gd:48`), `flock_push` 20 with a 150 px vision radius (`enemy_base.tscn:22,11`), knockback lasts 0.4 s (`enemy_base.tscn:65`) and moves at `(dir + knockback_dir × power) × speed`. Charger: every `cooldown` 3.0 s it plays `charge` (0.7 s), then dashes to the player's position at `speed × 5` until it is within 50 px (`chanrge_behavior.gd:25-28`). Shooter: every 3.0 s it fires 3 projectiles in a 45° arc at 1800 px/s and stands still for 1.0 s (`shooting_behavior.gd:5-12`).

## 3. Weapons (`resources/items/weapons/{melee,range}/<kind>/item_<kind>_<n>.tres` + `stats_<kind>_<n>.tres`)

The combine chain is `item_<kind>_1 → _2 → _3 → _4` through `upgrade_to`. Tier IV has no `upgrade_to`. Combining matches on the `item_name` string (`shop_panel.gd:55,94`). Every tier-I item (cost from the table) is in `SelectionPanel.start_weapon`. All 44 items are in `ShopPanel.shop_items`. Sell price = `int(item_cost × 0.75)` (`shop_panel.gd:133`).

Columns: dmg = `damage`, cd = `cooldown` (s), rng = `max_range` (px; also the melee lunge distance), crit = `crit_chance` × `crit_damage`, kb = `knockback`, acc = `accuracy`, ls = `life_steal` (chance per attack, added to `player.life_steal/100`). Final hit = `dmg + player.damage`, and a crit is `ceil(hit × crit_damage)` (`weapon_behavior.gd:11-17`).

### Melee (`WeaponBehavior` = `melee_behavior.gd`)

| Item file | item_name | tier | cost / sell | dmg | cd | rng | crit | kb | acc | ls | recoil / rec_dur / atk_dur / back_dur |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `axe/item_axe_1` | Axe I | 0* | 22 / 16 | 9 | 1.0 | 220 | 0.10 × 2.5 | 1.5 | 1.0 | 0.10 | 20 / 0.1* / 0.2* / 0.1 |
| `axe/item_axe_2` | Axe II | 1 | 52 / 39 | 18 | 0.9* | 230 | 0.13 × 2.5 | 1.5 | 1.0 | 0.12 | 20 / 0.1* / 0.2* / 0.1 |
| `axe/item_axe_3` | Axe III | 2 | 140 / 105 | 33 | 0.8 | 240 | 0.16 × 2.5 | 1.5 | 1.0 | 0.14 | 20 / 0.1* / 0.2* / 0.1 |
| `axe/item_axe_4` | Axe IV | 3 | 295 / 221 | 55 | 0.7 | 250 | 0.20 × 2.5 | 1.5 | 1.0 | 0.16 | 20 / 0.1* / 0.2* / 0.1 |
| `chainsaw/item_chainsaw_1` | Chainsaw I | 0* | 15 / 11 | 5 | 1.8 | 200 | 0.05* × 2.0 | 2.0 | 0.9* | 0.03 | 30 / 0.15 / 0.2* / 0.2 |
| `chainsaw/item_chainsaw_2` | Chainsaw II | 1 | 30 / 22 | 10 | 1.45 | 210 | 0.07 × 2.0 | 2.2 | 0.9* | 0.05 | 30 / 0.15 / 0.2* / 0.2 |
| `chainsaw/item_chainsaw_3` | Chainsaw III | 2 | 78 / 58 | 25 | 1.1 | 220 | 0.10 × 2.0 | 2.0 | 0.9* | 0.08 | 30 / 0.15 / 0.2* / 0.2 |
| `chainsaw/item_chainsaw_4` | Chainsaw IV | 3 | 150 / 112 | 45 | 0.8 | 230 | 0.15 × 2.0 | 2.0 | 0.9* | 0.12 | 30 / 0.15 / 0.2* / 0.2 |
| `mace/item_mace_1` → **`stats_mece_1.tres`** (via UID) | Mace I | 0* | 18 / 13 | 10 | 2.0 | 160 | 0.05 × 1.5* | 0* | 0.9* | 0* | 25 / 0.1* / 0.4 / 0.15* |
| `mace/item_mace_2` | Mace II | 1 | 35 / 26 | 12 | 1.3 | 200 | 0.07 × 1.5* | 1.5 | 0.8 | 0.04 | 28 / 0.15 / 0.2* / 0.18 |
| `mace/item_mace_3` | Mace III | 2 | 80 / 60 | 24 | 1.0 | 200 | 0.05* × 1.5* | 1.5 | 0.8 | 0.06 | 28 / 0.15 / 0.2* / 0.18 |
| `mace/item_mace_4` | Mace IV | 3 | 160 / 120 | 35 | 0.8 | 200 | 0.05* × 1.5* | 1.5 | 0.8 | 0.10 | 28 / 0.15 / 0.2* / 0.18 |
| `punch/item_punch_1` | Punch I | 0* | 12 / 9 | 4 | 1.5 | 180 | 0.05* × 1.5* | 1.5 | 1.0 | 0* | 25* / 0.1* / 0.2* / 0.15* |
| `punch/item_punch_2` | Punch II | 1 | 25 / 18 | 8 | 1.2 | 180 | 0.05* × 1.5* | 0* | 1.0 | 0* | 25* / 0.1* / 0.2* / 0.15* |
| `punch/item_punch_3` | Punch III | 2 | 55 / 41 | 16 | 0.9* | 180 | 0.05* × 1.5* | 0* | 1.0 | 0* | 25* / 0.1* / 0.2* / 0.15* |
| `punch/item_punch_4` | **Puch IV** (sic) | 3 | 130 / 97 | 30 | 0.7 | 200 | 0.10 × 2.0 | 0* | 1.0 | 0* | 25* / 0.1* / 0.2* / 0.15* |
| `sword/item_sword_1` | Sword I | 0* | 25 / 18 | 8 | 1.2 | 200 | 0.05* × 2.0 | 1.5 | 1.0 | 0.05 | 20 / 0.1* / 0.2* / 0.13 |
| `sword/item_sword_2` | Sword II | 1 | 55 / 41 | 15 | 1.0 | 200 | 0.08 × 2.0 | 1.5 | 1.0 | 0.08 | 20 / 0.1* / 0.2* / 0.13 |
| `sword/item_sword_3` | Sword III | 2 | 130 / 97 | 30 | 0.8 | 200 | 0.10 × 2.0 | 1.5 | 1.0 | 0.10 | 20 / 0.1* / 0.2* / 0.13 |
| `sword/item_sword_4` | Sword IV | 3 | 285 / 213 | 48 | 0.6 | 200 | 0.15 × 2.0 | 1.5 | 1.0 | 0.12 | 20 / 0.1* / 0.2* / 0.13 |
| `wand/item_wand_1` | Wand I | 0* | 35 / 26 | 10 | 1.0 | 220 | 0.07 × 2.5 | 2.5 | 1.0 | 0.10 | 20 / 0.1* / 0.2* / 0.12 |
| `wand/item_wand_2` | Wand II | 1 | 75 / 56 | 20 | 0.8 | 220 | 0.10 × 2.5 | 2.5 | 1.0 | 0.12 | 20 / 0.1* / 0.2* / 0.12 |
| `wand/item_wand_3` | Wand III | 2 | 165 / 123 | 32 | 0.7 | 220 | 0.15 × 2.5 | 2.5 | 1.0 | 0.15 | 20 / 0.1* / 0.2* / 0.12 |
| `wand/item_wand_4` | Wand IV | 3 | 345 / 258 | 50 | 0.6 | 220 | 0.20 × 2.5 | 2.5 | 1.0 | 0.17 | 20 / 0.1* / 0.2* / 0.12 |

Mace I: `item_mace_1.tres:6` names the path `stats_mace_1.tres` but carries `uid://d0gevuo634gkv`, which is the UID of `stats_mece_1.tres`. Godot resolves by UID, so the row above is `stats_mece_1.tres` (checked headless: `stats.resource_path == ".../stats_mece_1.tres"`, damage 10.0). `stats_mace_1.tres` (`uid://bsofskutm4xkh`: projectile_speed 1500, accuracy 0.8, cooldown 1.0, everything else default) is never loaded.

### Ranged (`WeaponBehavior` = `range_behavior.gd`; uses `recoil_duration` for both tween legs, so `atack_duration`/`back_duration` are ignored)

| Item file | item_name | tier | cost / sell | dmg | cd | rng | crit | kb | acc | ls | projectile scene @ speed | recoil / rec_dur |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `laser/item_laser_1` | Laser I | 0* | 18 / 13 | **1.0*** | 0.6 | 450 | 0.10 × 2.5 | 2.0 | 1.0 | 0.05 | `projectile_lazer.tscn` @ 1900 | 35 / 0.2 |
| `laser/item_laser_2` | Laser II | 1 | 36 / 27 | 16 | 1.7 | 450 | 0.15 × 2.5 | 2.0 | 1.0 | 0.10 | lazer @ 1900 | 35 / 0.2 |
| `laser/item_laser_3` | Laser III | 2 | 85 / 63 | 45 | 1.1 | 450 | 0.20 × 2.5 | 2.0 | 1.0 | 0.15 | lazer @ 1900 | 35 / 0.2 |
| `laser/item_laser_4` | Laser IV | 3 | 180 / 135 | **8** | **2.0** | 450 | 0.10 × 2.5 | 2.0 | 1.0 | 0.05 | lazer @ 1900 | 35 / 0.2 |
| `pistol/item_pistol_1` | Pistol I | 0* | 14 / 10 | **1.0*** | 1.0 | 300 | 0.05* × 1.5* | 0* | 0.9* | 0* | `projectile_pistol.tscn` @ 1600* | 25* / 0.1* |
| `pistol/item_pistol_2` | Pistol II | 1 | 30 / 22 | 10 | 0.9* | 360 | 0.08 × 2.0 | 1.3 | 0.85 | 0* | pistol @ 1700 | 25* / 0.1* |
| `pistol/item_pistol_3` | Pistol III | 2 | 65 / 48 | 18 | 0.8 | 370 | 0.10 × 2.0 | 1.3 | 0.85 | 0* | pistol @ 1700 | 25* / 0.1* |
| `pistol/item_pistol_4` | Pistol IV | 3 | 180 / 135 | 30 | 0.7 | 380 | 0.15 × 2.0 | 1.3 | 0.85 | 0* | pistol @ 1700 | 25* / 0.1* |
| `revolver/item_revolver_1` | Revolver I | 0* | 16 / 12 | 10 | 1.5 | 350 | 0.05* × 2.5 | 2.0 | 0.7 | 0.05 | `projectile_revolver.tscn` @ 1800 | 25* / 0.15 |
| `revolver/item_revolver_2` | Revolver II | 1 | 34 / 25 | 20 | 1.4 | 350 | 0.07 × 2.5 | 2.0 | 0.7 | 0.07 | revolver @ 1800 | 25* / 0.15 |
| `revolver/item_revolver_3` | Revolver III | 2 | 72 / 54 | 20 | 1.3 | 350 | 0.09 × 2.5 | 2.0 | 0.7 | 0.09 | revolver @ 1800 | 25* / 0.15 |
| `revolver/item_revolver_4` | Revolver IV | 3 | 165 / 123 | 40 | 1.2 | 350 | 0.12 × 2.5 | 2.0 | 0.7 | 0.12 | revolver @ 1800 | 25* / 0.15 |
| `shotgun/item_shotgun_1` | Shotgun I | 0* | 15 / 11 | **1.0*** | 1.0 | 150* | 0.05* × 1.5* | 0* | 0.8 | 0* | `projectile_shotgun.tscn` @ 1500 | 25* / 0.1* |
| `shotgun/item_shotgun_2` | Shotgun II | 1 | 32 / 24 | 18 | 1.3 | 350 | 0.07 × 2.0 | 3.0 | 0.85 | 0.05 | shotgun @ 1800 | 35 / 0.25 |
| `shotgun/item_shotgun_3` | Shotgun III | 2 | 70 / 52 | 32 | 1.1 | 350 | 0.09 × 2.0 | 3.0 | 0.85 | 0.05 | shotgun @ 1800 | 35 / 0.2 |
| `shotgun/item_shotgun_4` | Shotgun IV | 3 | 170 / 127 | 48 | 0.9* | 350 | 0.11 × 2.0 | 3.0 | 0.85 | 0.05 | shotgun @ 1800 | 35 / 0.2 |
| `smg/item_smg_1` | SMG I | 0* | 10 / 7 | 3 | 0.8 | 320 | 0.10 × 2.0 | 0.5 | 0.6 | 0* | `projectile_smg.tscn` @ 1850 | 20 / 0.1* |
| `smg/item_smg_2` | SMG II | 1 | 25 / 18 | 6 | 0.7 | 330 | 0.15 × 2.0 | 0.5 | 0.6 | 0* | smg @ 1850 | 20 / 0.1* |
| `smg/item_smg_3` | SMG III | 2 | 68 / 51 | 12 | 0.6 | 340 | 0.18 × 2.0 | 0.5 | 0.6 | 0* | smg @ 1850 | 20 / 0.1* |
| `smg/item_smg_4` | SMG IV | 3 | 155 / 116 | 25 | 0.6 | 350 | 0.25 × 2.0 | 0.5 | 0.6 | 0.10 | smg @ 1850 | 20 / 0.1* |

Weapon scenes: `scenes/weapons/melee/weapon_{axe,chainsaw,mace,punch,sword,wand}.tscn` and `scenes/weapons/range/weapon_{lazer,pistol,revolver,shotgun,smg}.tscn`. Every tier of a kind shares the same scene. `ItemWeapon.type` (`MELEE`=0 / `RANGE`=1) is set to 1 only on laser, revolver, shotgun and smg. Pistol and every melee item keep the default 0. Nothing reads it.

Ranged weapons fire one projectile per attack along the weapon rotation (`range_behavior.gd:28`). The "shotgun" has no spread or multi-shot. The `max_range` radius is applied to a `RangeArea` shape that all weapons share, so the effective targeting range of every weapon is the `max_range` of the last weapon set up (`known-issues.md` §1.2).

## 4. Upgrades (`resources/items/upgrades/data/<stat>/upgrade_<stat>_<value>.tres`, `ItemUpgrade`)

All 46 are in `UpgradePanel.upgrade_list` (`upgrage_panel.tscn:68`). `item_cost` = 0 (upgrades are free). `description` is the literal string `"+<value>"`. Applying one does `stats.set(stat_id, stats.get(stat_id) + value)` (`item_upgrade.gd:8-11`).

| item_name | `stat_id` | Icon | COMMON (0) | RARE (1) | EPIC (2) | LEGENDARY (3) |
|---|---|---|---|---|---|---|
| Block | `block_chance` | Upgrades/8.png | +1, +2 | +4, +5 | +6 | +7 |
| Damage | `damage` | Upgrades/12.png | +1, +2 | +3, +5 | +7 | +9 |
| Harvesting | `harvesting` | Upgrades/7.png | +1, +2 | +5, +6 | +8 | +10 |
| Health | `health` | Upgrades/6.png | +1, +2 | +4, +5 | +8 | +12 |
| HP Regen | `hp_regen` | Upgrades/13.png | +1 | +2 | +3 | +4 |
| Life Steal | `life_steal` | Upgrades/3.png | +1, +2 | +4, +5 | +7 | +9 |
| Luck | `luck` | Upgrades/1.png | +1, +3 | +5, +6 | +9 | +12 |
| Speed | `speed` | Upgrades/11.png | +5, +7 | +10, +12 | +15 | +20 |

Pool size per tier: 15 COMMON / 15 RARE / 8 EPIC / 8 LEGENDARY.

## 5. Passives (`resources/items/passives/data/*.tres`, `ItemPassive`, `item_type` = 2)

All four are in `ShopPanel.shop_items`. Bought passives can't be sold or selected (`item_card.gd:19` only emits for weapons). Applying one does `stats[add_stat] += add_value; stats[remove_stat] -= remove_value` (`item_passive.gd:23-28`).

| File | item_name | tier | cost | + stat | − stat | Icon |
|---|---|---|---|---|---|---|
| `passive_cape.tres` | Cape | 0* | 22 | +5 `life_steal` | −2 `health` | Upgrades/4.png |
| `passive_power_ball.tres` | Power ball | 0* | 30 | +5 `damage` | — | Upgrades/2.png |
| `passive_rage.tres` | Rage | 1 | 45 | +10 `damage` | −20 `speed` | Upgrades/9.png |
| `passive_mighty_sword.tres` | Mighty sword | 2 | 85 | +15 `luck` | — | Upgrades/10.png |

Shop pool per tier (weapons + passives): 13 COMMON / 12 RARE / 12 EPIC / 11 LEGENDARY = 48.

## 6. Waves (`resources/waves/data/*.tres`, `WaveDate`)

There is one file, and `Spawner.wave_data = [wave_1_to_5.tres]` (`arena.tscn:50`).

| File (UID) | from | to | wave_time (s) | spawn_type | fixsed_spawn_time | min / max spawn | Units (scene : weight → share) |
|---|---|---|---|---|---|---|---|
| `wave_1_to_5.tres` (`cer6rdmxrnenh`) | 1 | **10** | 20.0* | 0 = FIXED | 0.5 | 0.5 / 2.0 (ignored in FIXED) | `enemy_chaser_slow` : 6 → 60 %, `enemy_chaser_mid` : 3 → 30 %, `enemy_chaser_fast` : 1 → 10 % |

- A spawn is attempted every 0.5 s, so a 20 s wave makes about 39 spawns. Each enemy appears 0.8 s after its spawn mark (`enemy_spawn_effect.tscn`, `spawn` length 0.8). The spawn position is uniform in x ±1000, y ±500 (`spawner.gd:71-74`) and doesn't avoid the player.
- **Endless** (wave > 10): the same `WaveDate` is reused, and its spawn interval is scaled by `max(0.25, 0.95^(wave−10))` (`spawner.gd:53-55`, exports in `spawner.gd:11-13`).

| Wave | 10 | 11 | 15 | 20 | 30 | ≥ 37 |
|---|---|---|---|---|---|---|
| Multiplier | 1.0 | 0.95 | 0.774 | 0.599 | 0.358 | 0.25 (floor) |
| Interval (s) | 0.5 | 0.475 | 0.387 | 0.299 | 0.179 | 0.125 |

## 7. Tier probability config (`autoloads/global.gd:23-33, 80-124`)

| Config | rare start / per-wave | epic start / per-wave | legendary start / per-wave |
|---|---|---|---|
| `SHOP_PRPBABILITY_CONFIG` | wave 2 / 0.10 | wave 4 / 0.06 | wave 7 / 0.01 |
| `UPGRADE_PRPBABILITY_CONFIG` | wave 2 / 0.06 | wave 4 / 0.02 | wave 7 / 0.0023 |

The formula: `chance_t = min(1, (w − start_t + 1) × base_multi_t)` once `w ≥ start_t`, then × `(1 + luck/100)`. If the non-common sum is > 1, all three are scaled down to sum to 1. Common gets the rest. Every offer rolls 4 **distinct** items (`select_items_from_offer`, `global.gd:126-163`). It falls back to a lower tier when the rolled tier is empty. `w` is the wave that just **finished** (`spawner.wave_index` at `load_shop` / `load_upgrades`).

Computed odds, luck 0 (C / R / E / L):

| Wave | Shop | Upgrade |
|---|---|---|
| 1 | 100 / 0 / 0 / 0 | 100 / 0 / 0 / 0 |
| 2 | 90 / 10 / 0 / 0 | 94 / 6 / 0 / 0 |
| 3 | 80 / 20 / 0 / 0 | 88 / 12 / 0 / 0 |
| 4 | 64 / 30 / 6 / 0 | 80 / 18 / 2 / 0 |
| 5 | 48 / 40 / 12 / 0 | 72 / 24 / 4 / 0 |
| 7 | 15 / 60 / 24 / 1 | 55.8 / 36 / 8 / 0.23 |
| 10 | 0 / 66.2 / 30.9 / 2.9 | 31.1 / 54 / 14 / 0.92 |
| 15 | 0 / 55.2 / 39.8 / 5.0 | 0 / 76.3 / 21.8 / 1.9 |
| 20 | 0 / 46.7 / 46.7 / 6.5 | 0 / 72.9 / 24.8 / 2.35 |

With luck 5 (Bunny/Crazy), the shop at wave 5 is 45.4 / 42 / 12.6 / 0. Once the sum is capped, luck has no effect: from wave 8 in the shop (0.7 + 0.3 + 0.02 > 1) and from wave 14 for upgrades, even at luck 0.

## 8. Tier colors and styles

| Tier | `Global.TIER_COLORS` (weapon outline, `global.gd:17-21`) | Card StyleBoxFlat (`Global.get_tier_style`, `global.gd:165-174`) |
|---|---|---|
| COMMON | — (outline material removed, `weapon.gd:102-104`) | `styles/common_style.tres` `uid://dt8ypn0hibm80` bg (0.102,0.102,0.102) |
| RARE | Color(0.0, 0.557, 0.741) | `styles/rare_style.tres` `uid://ici2d08626ar` bg (0,0.275,0.373), border (0,0.557,0.741) |
| EPIC | Color(0.478, 0.251, 0.71) | `styles/epic_style.tres` `uid://ccifgx30nsp4h` bg (0.31,0.227,0.392), border (0.478,0.251,0.71) |
| LEGENDARY | Color(0.906, 0.212, 0.212) | `styles/legendary_style.tres` `uid://dnnhiwx3gx5h0` bg (0.373,0.18,0.18), border (0.906,0.212,0.212) |

Outline shader `shaders/outline.gdshader`: `outline_color`, `outline_width` (0–10, 8 in `weapon_base.tscn`), `glow_intensity` (0–5, 4 in `weapon_base.tscn`). Hit flash: `effects/flash_material.tres` (`uid://x4frie3idpxo`) with `effects/flash.gdshader`, which paints white with the texture alpha for 0.2 s.

## 9. Prices summary

| What | Price | Source |
|---|---|---|
| Weapons | `item_cost` per tier (§3), I: 10–35, II: 25–75, III: 55–165, IV: 130–345 | `shop_card.gd:31-32` |
| Weapon sell | `int(item_cost × 0.75)` | `shop_panel.gd:133` |
| Passives | 22 / 30 / 45 / 85 (§5), can't be sold | `shop_card.gd` |
| Upgrades | free (`item_cost` 0, never read) | `upgrade_card.gd:20-24` |
| Income | enemy `gold_drop` per coin picked up + `int(harvesting)` at wave end | `arena.gd:118`, `global.gd:72-73` |
| Combine | free; 2 × same `item_name` → `upgrade_to` | `shop_panel.gd:84-123` |
| Reroll | doesn't exist | — |

## 10. Audio

`SoundManager.Sound` (`autoloads/sound_manager.gd:3-13`): `ENEMY_HIT` → `assets/audio/EnemyHit.wav` (any hitbox→hurtbox hit), `FIRE` → `assets/audio/ShotgunFire.wav` (every ranged shot), `UI` → `assets/audio/UI Pop.mp3` (buttons, selection hover). 10 pooled players at −15 dB on the `SFX` bus, pitch randomized 0.8–1.3. A sound is dropped when all 10 are busy. Music: `Arena/MusicPlayer` `Bg Music.mp3` at −20 dB on the `Music` bus. Buses: `default_bus_layout.tres` (Master, Music, SFX).
