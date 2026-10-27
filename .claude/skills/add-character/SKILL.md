---
name: add-character
description: Add a new playable character to the Brotato arena game, or change an existing one's starting stats, sprite or selection entry. Use when the user asks to create, add or register a character, hero, playable class or player variant, put a character on the selection screen, rebalance character stats, or change starting weapons.
---

# Adding a playable character

A character has four parts. If one is missing, the character either never appears or crashes the game when picked:

1. a `UnitStats` resource, `resources/units/players/stat_player_<name>.tres`, with `type = PLAYER` and a `name`
2. a player scene inheriting `scenes/units/players/player_well_rounded.tscn`, `scenes/units/players/player_<name>.tscn`, whose `stats` is **that same** `.tres`
3. an entry `"<name>": preload("uid://<scene uid>")` in `Global.available_player` (`autoloads/global.gd:35-41`). The key must equal `stats.name` exactly.
4. the stats `.tres` appended to `players` on `SelectionPanel` in `scenes/ui/selection_panel/selection_panel.tscn`

How the parts connect. `SelectionPanel.load_players()` builds one `SelectionCard` per `players` entry, using `stats.icon`. Clicking a card sets `Global.main_player_selected`. `Arena._on_selection_panel_on_selection_complited()` then calls `Global.get_selected_player()`, which instantiates `available_player[main_player_selected.name]`. In other words, the selection screen only uses the stats for display and as a dictionary key. The stats used in the game are whatever the **scene's** `stats` export points to. Save files store `stats.name` (`ProgressData.save_game()`) and look it up in `available_player` again on load (`ProgressData.load_game()`, `Arena.continue_saved_game()`).

Ask the user for anything you can't infer: name, sprite and stats. Sensible defaults are close to the existing characters below.

## Existing characters

| name (= key) | stats `.tres` (uid) | scene (uid) | sprite | hp | dmg | speed | luck | block | other |
|---|---|---|---|---|---|---|---|---|---|
| Brawler | `stat_player_brawler.tres` (`bunibsb7u1731`) | `player_brawler.tscn` (`nk87ujktnw1c`) | `Player_2.png` | 25 | 4 | 270 | 3 | 5 | |
| Bunny | `stat_player_bunny.tres` (`bq88pw5hp5xdp`) | `player_bunny.tscn` (`by1lqht47vkds`) | `Player_4.png` | 20 | 5 | 325 | 5 | 3 | |
| Crazy | `stat_player_crazy.tres` (`7447673xti1j`) | `player_crazy.tscn` (`bsxha0eaawok4`) | `Player_3}.png` (sic, stray `}`) | 15 | 3 | 350 | 5 | 5 | |
| Knight | `stat_player_knight.tres` (`c6peqkogo66e5`) | `player_knight.tscn` (`dlxdaijg5gkku`) | `Player_5.png` | 30 | 6 | 260 | 1 (default, not set) | 10 | |
| Well Rounded | `stat_player_well_rounded.tres` (`b42xxkqwoymy1`) | `player_well_rounded.tscn` (`jadv5cnwph1c`) | `Player_1.png` | 15 | 3 | 300 (default) | 0 | 1 | harvesting 5 |

All five set `health_increase_pre_wave = 0.0`, and every scene is in `Global.available_player` and `SelectionPanel.players`. Sprites live in `assets/sprites/Players/`, and each character's `icon` is the same PNG as its sprite. All five PNGs are in use.

## 1. Stats resource

Copy `stat_player_bunny.tres` and give it a new UID (see "Hand-editing"):

```
[gd_resource type="Resource" script_class="UnitStats" load_steps=3 format=3 uid="uid://<new uid>"]

[ext_resource type="Texture2D" uid="uid://<png uid>" path="res://assets/sprites/Players/<file>.png" id="1_icon"]
[ext_resource type="Script" uid="uid://brjn3a1k336sd" path="res://resources/units/unit_stats.gd" id="2_script"]

[resource]
script = ExtResource("2_script")
name = "Ninja"
icon = ExtResource("1_icon")
health = 18
health_increase_pre_wave = 0.0
damage = 4.0
damege_increase_pre_wave = 0.0
speed = 330
luck = 2.0
block_chance = 4.0
gold_drop = 0
metadata/_custom_type_script = "uid://brjn3a1k336sd"
```

- `type` is omitted because PLAYER (0) is the default. Don't set `type = 1`: that marks an enemy. Nothing in the code reads `type` today (see the stat table in the `add-item` skill), but the check script enforces it.
- **Always write `health_increase_pre_wave = 0.0`** unless the character should grow. Its default is `1.0`, and `Player.update_player_new_wave()` adds it to max HP at every wave start.
- Omitted fields take the `unit_stats.gd` defaults: `speed` 300, `luck` 1.0, `damage` 1.0, `health` 1, `block_chance`/`hp_regen`/`life_steal`/`harvesting` 0. Knight gets luck 1 this way.
- `damege_increase_pre_wave` (sic) and `gold_drop` have no effect on players. They are enemy-only (`spawner.gd:101`, `arena.gd:118`).
- `hp_regen`, `life_steal` and `harvesting` work as starting stats (Well Rounded uses harvesting), but the selection screen doesn't show them. `SelectionPanel._on_player_selected()` (`selection_panel.gd:61`) prints only Health, Damage, Speed, Luck and Block.
- `name` is the dictionary key **and** what saves store. Renaming a released character invalidates saves: `load_game()` deletes the save on an unknown name.

## 2. Player scene

`player_well_rounded.tscn` (`uid://jadv5cnwph1c`) is both the Well Rounded character and the base of all the other characters. It contains `player.gd`, the Trail, `WeaponContainer` with markers `One`…`Six`, the dash timers, `HPRegenTimer` (3 s), the hurtbox (layer 32 / mask 4) and the body mask 2. Inherit it and override only `stats` and the sprite texture. Copy `player_knight.tscn`:

```
[gd_scene load_steps=4 format=3 uid="uid://<new scene uid>"]

[ext_resource type="PackedScene" uid="uid://jadv5cnwph1c" path="res://scenes/units/players/player_well_rounded.tscn" id="1_base"]
[ext_resource type="Texture2D" uid="uid://<png uid>" path="res://assets/sprites/Players/<file>.png" id="2_tex"]
[ext_resource type="Resource" uid="uid://<stats uid>" path="res://resources/units/players/stat_player_<name>.tres" id="3_stats"]

[node name="Player<Name>" instance=ExtResource("1_base")]
stats = ExtResource("3_stats")

[node name="Sprite" parent="Visuals" index="2"]
texture = ExtResource("2_tex")
```

- The Sprite is `index="2"` inside `Visuals` because `Trail` is index 0.
- Per-character feel without code: override `dash_duration`, `dash_speed_multi` and `dash_cooldown` (exports on `player.gd`, all 0.5 / 1.5 / 0.5) on the root node.
- Editing `player_well_rounded.tscn` changes **every** character. Don't put character-specific changes there.
- A new PNG needs an import before it has a UID: `$GODOT --path . --headless --editor --quit`, then read `uid=` from `<png>.import`. The current sprites are about 120 px, and the collision/hurtbox shapes in the base are sized for that.

## 3. Register in `Global.available_player`

In `autoloads/global.gd`, add a line to the dictionary:

```gdscript
var available_player: Dictionary[String, PackedScene] = {
	...
	"Well Rounded": preload("uid://jadv5cnwph1c"),
	"Ninja": preload("uid://<new scene uid>"),
}
```

Create the scene **before** this edit. `Global` is an autoload, so a `preload` of an unknown UID breaks the whole project at boot.

## 4. Add to the selection screen

`scenes/ui/selection_panel/selection_panel.tscn`:
1. Add `[ext_resource type="Resource" uid="uid://<stats uid>" path="res://resources/units/players/stat_player_<name>.tres" id="<unique id>"]`.
2. Append `ExtResource("<unique id>")` to `players = Array[ExtResource("2_hu73q")]([...])` on the `SelectionPanel` node. The order there is the card order.
3. Bump `load_steps` in the header by 1.

`PlayerContainer` is an `HBoxContainer` of 128×128 `SelectionCard`s (`selection_card.tscn`). Ask the user to check that the extra card fits the row.

## Starting weapons

Starting weapons are **not per character**. `SelectionPanel.start_weapon: Array[ItemWeapon]` is a single list shown to every character: the 11 tier-I weapons Axe, Chainsaw, Mace, Punch, Sword, Wand, Laser, Pistol, Revolver, Shotgun and SMG (`item_*_1.tres`). The player picks one of them, and `Arena._on_selection_panel_on_selection_complited()` equips it (`player.add_weapon()` + `shop_panel.create_item_weapon()` + `Global.equipped_weapons`). To offer another weapon, append its `ItemWeapon` to `start_weapon` the same way as step 4 (see the `add-weapon` skill). A per-character weapon list or a forced starting weapon needs code changes, for example a new export on `UnitStats` or on the player scene read in `SelectionPanel.load_weapons()`. Confirm with the user before changing game code.

## Gotchas

- Key mismatch: if `stats.name` isn't a key of `Global.available_player`, picking the character crashes in `Global.get_selected_player()` with an invalid dictionary key.
- Stats mismatch: if the scene's `stats` points to a different `.tres` than the one in `SelectionPanel.players`, the selection screen shows one set of numbers and the game uses another. The check script catches this.
- `UnitStats` resources are shared and mutated in place by upgrades and passives (`ItemUpgrade.apply_upgrade()`, `ItemPassive.apply_passive()`), so the character's `.tres` holds the boosted values for the rest of the session. Never share one `.tres` between two characters.
- The player has no game over. At 0 HP, `HealthComponent.die()` calls `owner.queue_free()` and the run just continues without a player. That's not specific to new characters, but worth knowing when playtesting.

## Hand-editing

Prefer the editor (New Inherited Scene from `player_well_rounded.tscn`). By hand, generate fresh UIDs (charset `a-z0-7`) and make sure `grep -rn "<uid>" .` finds nothing:

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
$GODOT --path . --headless --editor --quit >/dev/null 2>&1      # import new sprites, register UIDs
$GODOT --path . --headless --quit 2>&1 | grep -v "resource_format_text.cpp:444\|invalid UID"
```

Expect only the pre-existing exit-time leak warning. A `Global` parse error here usually means a bad `preload` UID. Then run [check_characters.gd](check_characters.gd) as a temporary scene. It needs autoloads, so `--script` mode won't work:

```sh
cp .claude/skills/add-character/check_characters.gd _tmp_char_check.gd
printf '[gd_scene format=3]\n\n[ext_resource type="Script" path="res://_tmp_char_check.gd" id="1"]\n\n[node name="Check" type="Node"]\nscript = ExtResource("1")\n' > _tmp_char_check.tscn
$GODOT --path . --headless --quit-after 600 res://_tmp_char_check.tscn 2>&1 | grep -v "resource_format_text.cpp:444\|invalid UID\|GDScript backtrace\|_tmp_char_check.gd:"; echo "exit=${pipestatus[1]}"
rm -f _tmp_char_check.gd _tmp_char_check.gd.uid _tmp_char_check.tscn
```

For every `.tres` in `resources/units/players/`, it checks that:
- `type` is PLAYER and an icon is set
- the stats are in `SelectionPanel.players`
- `name` is a key of `Global.available_player`
- that scene's root is a `Player` whose `stats` is the very same `.tres`
- the scene inherits `player_well_rounded.tscn` and has `WeaponContainer/Six`

It also checks that every `available_player` key is backed by a stats file and that every `start_weapon` has a scene. It prints one line per character (stats, scene, texture) and the start weapons, ends with `checked N characters, N available_player entries, 0 error(s)`, and exits 1 on any error.

Finally, ask the user to playtest: pick the new character, check the info panel and the in-game sprite, and play a wave.
