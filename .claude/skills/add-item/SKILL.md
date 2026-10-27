---
name: add-item
description: Add a stat item to the Brotato arena game, either an upgrade offered after each wave (ItemUpgrade) or a passive bought in the shop (ItemPassive). Use when the user asks to create, add, rebalance or register an upgrade, passive, item, perk or stat bonus, change item tiers, costs or offer chances, or asks which stats exist or what a stat does. Not for weapons (ItemWeapon).
---

# Adding an upgrade or passive item

There are two kinds of stat items. Both extend `ItemBase` (`resources/items/item_base.gd`) and change the **player's** `UnitStats` at runtime:

| kind | script | applied by | offered in | pool (export) | pool lives in |
|---|---|---|---|---|---|
| Upgrade | `ItemUpgrade` (`resources/items/upgrades/item_upgrade.gd`, `uid://ti87pqqmd7ro`) | `apply_upgrade()`: `stats.set(stat_id, stats.get(stat_id) + value)` | `UpgradePanel` after every wave, free (pick 1 of 4) | `upgrade_list: Array[ItemUpgrade]` | `scenes/ui/upgrade_panel/upgrage_panel.tscn` (sic) |
| Passive | `ItemPassive` (`resources/items/passives/item_passive.gd`, `uid://b02nvnwsn6gp8`) | `apply_passive()`: `stats[add_stat] += add_value`, `stats[remove_stat] -= remove_value` | `ShopPanel`, bought for `item_cost` | `shop_items: Array[ItemBase]` (shared with weapons) | `scenes/ui/shop_panel/shop_panel.tscn` |

The pools are set in the **panel scenes**, not in `arena.tscn`: `arena.tscn` instances both panels without overriding the arrays. An item that is in no pool is never offered.

Ask the user for anything you can't infer: kind, stat(s), value(s), tier, cost (passives) and icon. Base the defaults on the existing items (tables below).

## Stats: what is valid and what actually reads it

The only valid values for `stat_id`, `add_stat` and `remove_stat` are the int/float properties of `UnitStats` (`resources/units/unit_stats.gd`). They are plain strings and nothing checks them at load time. On a typo, `apply_upgrade()` fails with `Invalid cast: could not convert value to 'float'` (`get()` returns null). `UpgradeCard._on_custom_button_pressed()` then aborts before `on_upgrade_selected` fires, and the run gets stuck on the upgrade panel. `apply_passive()` fails with `Invalid access to property or key` after the coins have been spent. (Both errors verified headless.) Note the real misspellings.

| stat | type, default | read by (gameplay) | shown in | effect on the player | flag |
|---|---|---|---|---|---|
| `health` | int, 1 | `HealthComponent.setup()` → `max_health` (`scenes/components/health_component.gd:13`); regen cap `player.gd:112`; `Player.update_player_new_wave()` (`player.gd:97-98`); enemy scaling `spawner.gd:100` | StatsContainer, SelectionPanel | max HP. **Applies at the start of the next wave**: `update_player_new_wave()` re-runs `health_component.setup(stats)`, which fully heals. | int: fractions truncate |
| `health_increase_pre_wave` (sic) | float, 1.0 | `player.gd:97` (`stats.health += …` every new wave); enemy scaling `spawner.gd:100` | none | +max HP at every wave start (a "growth" stat). All characters set it to 0. | not displayed |
| `damage` | float, 1.0 | `WeaponBehavior.get_damage()` (`scenes/weapons/weapon_behavior.gd:12`): weapon damage + this, before crit (`ceil(dmg * crit_damage)`); enemy shooter projectiles `shooting_behavior.gd:60`; enemy scaling `spawner.gd:101` | StatsContainer, SelectionPanel | flat bonus on every weapon hit | enemies: contact damage ignores it (see Gotchas) |
| `damege_increase_pre_wave` (sic) | float, 1.0 | `spawner.gd:101` only (enemies in `enemy_collection`) | none | **none** | **no effect on the player** |
| `speed` | int, 300 | `player.gd:41`; `enemy.gd:25`; `chanrge_behavior.gd:25` | StatsContainer, SelectionPanel | move speed in px/s. Dashing multiplies it by `dash_speed_multi`. | int: fractions truncate; nothing clamps it, so it can go negative |
| `luck` | float, 1.0 | `Global.calculate_tier_probability()` (`autoloads/global.gd:97`): `luck_factor = 1 + luck / 100` multiplies the rare/epic/legendary chances | StatsContainer (`%`), SelectionPanel | better offer tiers in both the shop and the upgrade panel | enemies: unused |
| `block_chance` | float, 0.0 | `Unit._on_hurtbox_component_on_damaged()` (`scenes/units/unit.gd:23`): `block_chance / 100` | StatsContainer (`%`), SelectionPanel | percent chance to ignore a hit. Not capped, so ≥ 100 means invulnerable. | |
| `gold_drop` | int, 1 | `arena.gd:118` (`enemy.stats.gold_drop`) | none | **none** | **no effect on the player** (enemies only) |
| `hp_regen` | float, 0.0 | `Player._on_hp_regen_timer_timeout()` (`player.gd:108-117`), on `HPRegenTimer` (`wait_time = 3.0`) | StatsContainer | heals this much every 3 s while below max HP | enemies: unused |
| `life_steal` | float, 0.0 | `WeaponBehavior.apply_life_steal()` (`weapon_behavior.gd:21`): chance = `life_steal / 100 + WeaponStats.life_steal`, heals a flat 1 HP | StatsContainer (`%`) | percent chance **per attack** (called from `melee_behavior.gd:19` / `range_behavior.gd:17` whether or not the attack hits) to heal 1 HP | enemies: unused |
| `harvesting` | float, 0.0 | `Global.get_harvesting_coins()` (`global.gd:73`, `coins += int(harvesting)`), called from `Spawner._on_wave_timer_timeout()` (`spawner.gd:148`) | StatsContainer | coins granted at the end of every wave | fractions truncate when paid |
| `type` | `UnitType` enum (int), PLAYER | **nothing** (`UnitStats.UnitType` is never compared anywhere) | none | none | **never read. Never target it.** (`check_items.gd` rejects it) |

`name` (String) and `icon` (Texture2D) are not numeric, so items can't target them.

Every int/float property, `type` included, is saved by reflection in `ProgressData.save_game()` (`autoloads/progress_data.gd:46-48`) and restored by `Arena.continue_saved_game()` (`arena.gd:44-45`). Purchased passives are **not** re-applied on load, because their effect is already in the saved stats. So a new stat needs no save code.

## 1. Create the resource

File naming: `resources/items/upgrades/data/<stat>/upgrade_<stat>_<value>.tres` and `resources/items/passives/data/passive_<name>.tres`. New files need a fresh UID (see "Hand-editing" below).

**Upgrade**. Copy of `upgrade_damage_1.tres`, with the script UID corrected (the existing files carry the stale script UIDs `uid://0kfyb4qfa66q` / `uid://cr0po024cxfg5`, which cause the `invalid UID` warnings at boot; their text paths still work):

```
[gd_resource type="Resource" script_class="ItemUpgrade" load_steps=3 format=3 uid="uid://<new uid>"]

[ext_resource type="Texture2D" uid="uid://dn68qq5evmvwa" path="res://assets/sprites/Upgrades/12.png" id="1_icon"]
[ext_resource type="Script" uid="uid://ti87pqqmd7ro" path="res://resources/items/upgrades/item_upgrade.gd" id="2_script"]

[resource]
script = ExtResource("2_script")
value = 4.0
description = "+4"
stat_id = "damage"
item_name = "Damage"
item_icon = ExtResource("1_icon")
item_tier = 2
item_type = 1
item_cost = 0
```

- `description` is shown as-is in a plain `Label` (`UpgradeCard`, `scenes/ui/upgrade_card/upgrade_card.gd:14`). **No BBCode.** The convention is `"+<value>"`, and the card title is `item_name`.
- `item_type = 1` (`ItemBase.ItemType.UPGRADE`). `item_cost` is unused for upgrades (they're free), so keep it 0.
- One stat per upgrade. Same-stat upgrades share `item_name` and icon and differ only in value and tier.

**Passive**. Copy of `passive_rage.tres`:

```
[gd_resource type="Resource" script_class="ItemPassive" load_steps=3 format=3 uid="uid://<new uid>"]

[ext_resource type="Script" uid="uid://b02nvnwsn6gp8" path="res://resources/items/passives/item_passive.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://<png uid>" path="res://assets/sprites/Upgrades/<n>.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
add_value = 10.0
add_stat = "damage"
remove_value = 20.0
remove_stat = "speed"
item_name = "Rage"
item_icon = ExtResource("2_icon")
item_tier = 1
item_type = 2
item_cost = 45
metadata/_custom_type_script = "uid://b02nvnwsn6gp8"
```

- `item_type = 2` (`ItemBase.ItemType.PASSIVE`). Without it the shop's `_on_item_purchased` does nothing useful with the item.
- `remove_value` is **subtracted**, so write it positive. Leave out `remove_value`/`remove_stat` for a pure bonus (as in `passive_power_ball.tres`). At most one added and one removed stat. More would need code changes in `item_passive.gd`.
- The shop description is generated by `ItemPassive.get_description()` as BBCode for the shop card's `RichTextLabel` (`bbcode_enabled = true`): `[code][color=green]+10.0 damage[/color]\n[color=red]-20.0 speed[/color]\n[/code]`. It prints the **raw stat id**, so it can't be customized per item without changing that function.
- Leaving out `item_tier` means COMMON (0).

Icons: `assets/sprites/Upgrades/*.png`. All 12 are already used: 1 luck, 3 life_steal, 6 health, 7 harvesting, 8 block, 11 speed, 12 damage, 13 hp_regen (upgrades); 4 Cape, 9 Mighty sword, 10 Power ball, 2 Rage (passives). Reuse the stat's icon for an upgrade. A new PNG needs an import first (`$GODOT --path . --headless --editor --quit`), then read the `uid=` from `<png>.import`.

## 2. Tier, cost and offer chances

`item_tier` is `Global.UpgradeTier`: 0 COMMON, 1 RARE, 2 EPIC, 3 LEGENDARY. It sets the card style (`Global.get_tier_style()`) and the offer chance. `Global.select_items_from_offer(pool, wave, config)` rolls 4 distinct items per offer. Per wave the non-common chance is `min(1, (wave − start_wave + 1) × base_multi) × (1 + luck/100)`, normalized so the total stays ≤ 1. Common takes the rest. When the rolled tier has no item in the pool, it falls back to the next lower tier.

| config (`autoloads/global.gd`) | rare start / multi | epic | legendary |
|---|---|---|---|
| `UPGRADE_PRPBABILITY_CONFIG` (sic) | 2 / 0.06 | 4 / 0.02 | 7 / 0.0023 |
| `SHOP_PRPBABILITY_CONFIG` (sic) | 2 / 0.10 | 4 / 0.06 | 7 / 0.01 |

Resulting chances at luck 0 (C/R/E/L):

| wave | upgrades | shop |
|---|---|---|
| 1 | 1.00 / 0 / 0 / 0 | 1.00 / 0 / 0 / 0 |
| 4 | 0.80 / 0.18 / 0.02 / 0 | 0.64 / 0.30 / 0.06 / 0 |
| 7 | 0.56 / 0.36 / 0.08 / 0.002 | 0.15 / 0.60 / 0.24 / 0.010 |
| 10 | 0.31 / 0.54 / 0.14 / 0.009 | 0 / 0.66 / 0.31 / 0.029 |
| 20 | 0 / 0.73 / 0.25 / 0.023 | 0 / 0.47 / 0.47 / 0.065 |

So late in a run, COMMON items stop being offered: from wave 8 in the shop and from wave 14 in the upgrade panel. After that they only appear through the empty-tier fallback. Give new upgrades a value ladder across tiers like the existing stats do.

Passive costs so far: COMMON 22–30, RARE 45, EPIC 85 (no legendary passive yet). For scale, weapons cost 10–35 at tier I and 285 for Sword IV. Coins come from enemy `gold_drop` plus `harvesting`, and the run starts with `Global.coins = 20`. Passives can't be sold: `ItemCard._on_pressed` only selects weapons.

## 3. Register in the pool

**Upgrade** → `scenes/ui/upgrade_panel/upgrage_panel.tscn`:
1. Add `[ext_resource type="Resource" uid="uid://<item uid>" path="res://resources/items/upgrades/data/<stat>/upgrade_<stat>_<v>.tres" id="<unique id>"]`.
2. Append `ExtResource("<unique id>")` to `upgrade_list = Array[ExtResource("2_7oj0a")]([...])` on the `UpgragePanel` node.
3. Bump `load_steps` in the header by 1.

**Passive** → `scenes/ui/shop_panel/shop_panel.tscn`: the same, appending to `shop_items = Array[ExtResource("2_pk1f0")]([...])` on the `ShopPanel` node.

Never put an `ItemUpgrade` in `shop_items`. The shop shows it with an empty description (`ItemBase.get_description()` returns `""`), and on purchase `ShopPanel._on_item_purchased()` handles neither branch: the stat is not applied, the coins are lost, and the orphan `ItemCard`'s `_set_item` hits a null `@onready` icon. `upgrade_list` is typed `Array[ItemUpgrade]`, so a passive can't go there.

Each pool must keep at least 4 distinct items. `select_items_from_offer` loops `while offered_items.size() < 4` and would hang forever otherwise.

## 4. Adding a new stat (only if no existing stat fits)

This touches game code, so confirm with the user first.
1. `resources/units/unit_stats.gd`: add `@export var <stat> := 0.0`. Prefer float, because int stats truncate fractional upgrade values.
2. Read it where it matters, usually `Global.player.stats.<stat>`. A stat nothing reads is dead (see `type`).
3. Show it: add a `Stats<Name>` panel with `Title` and a unique-named `<Name>Label` to `scenes/ui/stats_container/stats_container.tscn` (copy `StatsHarvesting`), plus an `@onready` and a line in `stats_container.gd`. Optionally add it to the description string in `selection_panel.gd:61`.
4. Saving is automatic (reflection over int/float properties). Old saves simply lack the key, so the stat keeps its `.tres` value.
5. Remember `UnitStats` are shared resources mutated in place: the player's `.tres` accumulates upgrades for the whole session.

## Existing items

Upgrades (all in `upgrade_list`, `item_cost = 0`, `description = "+<value>"`):

| stat_id | item_name | icon | COMMON | RARE | EPIC | LEGENDARY |
|---|---|---|---|---|---|---|
| `block_chance` | Block | 8 | +1, +2 | +4, +5 | +6 | +7 |
| `damage` | Damage | 12 | +1, +2 | +3, +5 | +7 | +9 |
| `harvesting` | Harvesting | 7 | +1, +2 | +5, +6 | +8 | +10 |
| `health` | Health | 6 | +1, +2 | +4, +5 | +8 | +12 |
| `hp_regen` | HP Regen | 13 | +1 | +2 | +3 | +4 |
| `life_steal` | Life Steal | 3 | +1, +2 | +4, +5 | +7 | +9 |
| `luck` | Luck | 1 | +1, +3 | +5, +6 | +9 | +12 |
| `speed` | Speed | 11 | +5, +7 | +10, +12 | +15 | +20 |

Passives (all in `shop_items`):

| file | item_name | tier | cost | add | remove |
|---|---|---|---|---|---|
| `passive_cape.tres` | Cape | COMMON | 22 | +5 `life_steal` | −2 `health` |
| `passive_power_ball.tres` | Power ball | COMMON | 30 | +5 `damage` | |
| `passive_rage.tres` | Rage | RARE | 45 | +10 `damage` | −20 `speed` |
| `passive_mighty_sword.tres` | Mighty sword | EPIC | 85 | +15 `luck` | |

## Gotchas

- Stat strings must match `UnitStats` exactly, misspellings included: `damege_increase_pre_wave` and `health_increase_pre_wave` (`pre`, not `per`).
- `health`, `speed`, `gold_drop` are ints. `+1.5 health` applies as `+1` (verified by `check_items.gd`, which prints `TRUNCATED`).
- A `health` change, including Cape's −2, updates `max_health` only at the next wave start. That call also fully heals the player.
- Nothing clamps stats. Passives can push `speed`, `block_chance` or `health` to 0 or below, and `block_chance ≥ 100` blocks everything.
- Purchased passives are saved by `resource_path` (`ProgressData` `purchased_passives`). Don't move or rename a released passive `.tres`, or loading a save breaks.
- Enemy contact damage is **not** `stats.damage`: `HitboxComponent.damage` defaults to `1.0` and nothing sets it on enemies. Only `ShootingBehavior` projectiles use `enemy.stats.damage`. This matters if you balance `block_chance` or `health` against wave scaling.

## Hand-editing

Prefer the editor (create a new resource → `ItemUpgrade`/`ItemPassive`, then drag it into the panel's array). By hand, generate a UID (charset `a-z0-7`) and make sure `grep -rn "<uid>" .` finds nothing:

```sh
python3 -I -c "
import secrets
i=secrets.randbits(63); s=''
while True:
    c=i%34; s+=chr(97+c) if c<26 else chr(48+c-26); i//=34
    if not i: break
print('uid://'+s[::-1])"
```

## 5. Verify

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --path . --headless --quit 2>&1 | grep -v "resource_format_text.cpp:444\|invalid UID"
```

Expect only the pre-existing exit-time leak warning. Then run [check_items.gd](check_items.gd). It needs autoloads (`ItemBase` exports `Global.UpgradeTier`), so run it as a temporary scene, not with `--script`:

```sh
cp .claude/skills/add-item/check_items.gd _tmp_item_check.gd
printf '[gd_scene format=3]\n\n[ext_resource type="Script" path="res://_tmp_item_check.gd" id="1"]\n\n[node name="Check" type="Node"]\nscript = ExtResource("1")\n' > _tmp_item_check.tscn
$GODOT --path . --headless --quit-after 600 res://_tmp_item_check.tscn 2>&1 | grep -v "resource_format_text.cpp:444\|invalid UID\|GDScript backtrace\|_tmp_item_check.gd:"; echo "exit=${pipestatus[1]}"
rm -f _tmp_item_check.gd _tmp_item_check.gd.uid _tmp_item_check.tscn
```

It loads every `.tres` under `resources/items/` (weapons skipped) and checks:
- every `stat_id`/`add_stat`/`remove_stat` is a numeric `UnitStats` property and not `type`
- non-zero values
- `item_type` matches the class
- upgrades only in `upgrade_list` with a description
- passives only in `shop_items` with a cost
- name and icon set
- no missing pool references

It prints one line per item (tier, effect, cost, pools), then `checked N upgrade/passive items, 0 error(s)`, and exits 1 on any error. The new item must appear with the right pool.

Finally, ask the user to playtest: reach the upgrade panel or shop and check that the card text, the tier color and the stat change in the StatsContainer look right.
