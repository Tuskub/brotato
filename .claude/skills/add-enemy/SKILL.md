---
name: add-enemy
description: Add a new enemy type to the Brotato arena game, or a new enemy behavior (charge, shoot, etc.). Use when the user asks to create, add or register an enemy, enemy variant or enemy behavior, or to put an enemy into the waves.
---

# Adding a new enemy

An enemy has four parts. Missing any of them gives an enemy that never spawns or never scales:

1. a `UnitStats` resource, `resources/units/enemies/stat_enemy_<name>.tres`
2. a scene inheriting `scenes/units/enemies/enemy_base.tscn`, `scenes/units/enemies/enemy_<name>.tscn`
3. registration in `enemy_collection` on the Spawner in `scenes/arena/arena.tscn`, for per-wave scaling
4. a `WaveUnitData` entry in a `WaveDate` in `resources/waves/data/*.tres`, so it actually spawns

Ask the user for anything you can't infer: the sprite, stats, which waves and spawn weight, and a special behavior if one is wanted. Sensible stat defaults are close to the existing enemies (see the table below).

## Hierarchy (don't break it)

```
unit.tscn (Unit)                    Visuals/Shadow, Visuals/Sprite, AnimationPlayer (idle/move/die), Hurtbox, Health, HealthBar, FlashTimer
 └── enemy_base.tscn (Enemy)        enemy.gd, collision layer 2, VisionArea, HitboxComponent, KnockbackTimer. NO stats, NO texture
      ├── enemy_chaser_slow/mid/fast.tscn   stats + texture only
      ├── enemy_charger.tscn                + ChargeBehavior + AnimationEffects
      └── enemy_shooter.tscn                + ShootingBehavior + Visuals/FirePos
```

- Always inherit `enemy_base.tscn` (`uid://h4qyxvfputld`). Never inherit a concrete enemy: it drags that enemy's stats and texture along.
- Don't create a new script extending `Enemy` just to change numbers. Use stats for numbers and behavior child nodes for logic.
- Every enemy needs **its own** `.tres`. Stats are shared by all instances and mutated in place by the Spawner, so two enemy types must never share one.

## 1. Stats resource

Copy an existing file such as `stat_enemy_charger.tres` and give it a new UID (see "Hand-editing scenes"). Fields (`resources/units/unit_stats.gd`). Note the misspellings, which are real property names:

```
name = "Mushroom"                    # display name; doesn't need to match anything
type = 1                             # UnitType.ENEMY
icon = ExtResource(<texture>)
health = 6                           # int
health_increase_pre_wave = 2.0
damage = 2.0
damege_increase_pre_wave = 1.5       # sic
speed = 260                          # int, px/s
luck = 0.0
block_chance = 3.0                   # percent
gold_drop = 2
```

Existing enemies for reference:

| enemy | hp | +hp/wave | dmg | +dmg/wave | speed | gold |
|---|---|---|---|---|---|---|
| Chaser Slow | 6 | 1 (default) | 1.5 | 1 (default) | 250 | 1 |
| Chaser Mid | 8 | 2 | 2 | 1 (default) | 300 (default) | 2 |
| Chaser Fast | 6 | 2.5 | 1.5 | 1.5 | 350 | 2 |
| Charger | 8 | 3 | 2.5 | 2 | 280 | 3 |
| Shooter | 4 | 2 | 3 | 1.5 | 260 | 3 |

Scaling: at the start of every wave, `Spawner.scale_enemies_for_wave()` sets `health = base + int(inc × (wave − 1))` and `damage = base + inc × (wave − 1)`, where base is the value from the `.tres`.

## 2. Scene

Minimal enemy (stats + sprite). Sprites go in `assets/sprites/Enemies/`. A new PNG needs its `.import`/UID, so run `$GODOT --path . --headless --editor --quit` once, then read the `uid=` from `<png>.import`.

```
[gd_scene load_steps=4 format=3 uid="uid://<new scene uid>"]

[ext_resource type="PackedScene" uid="uid://h4qyxvfputld" path="res://scenes/units/enemies/enemy_base.tscn" id="1_base"]
[ext_resource type="Texture2D" uid="uid://<png uid>" path="res://assets/sprites/Enemies/<file>.png" id="2_tex"]
[ext_resource type="Resource" uid="uid://<stats uid>" path="res://resources/units/enemies/stat_enemy_<name>.tres" id="3_stats"]

[node name="Enemy<Name>" instance=ExtResource("1_base")]
stats = ExtResource("3_stats")

[node name="Sprite" parent="Visuals" index="1"]
texture = ExtResource("2_tex")
```

The base sprite sits at `(0, -61)` inside `Visuals`, which is scaled 0.5. Collision, hurtbox and hitbox shapes are centered at `(0, -29)`, sized for the ~120px sprites. If the new sprite is much bigger or smaller, override the shapes (`CircleShape2D` sub-resources on `CollisionShape2D`, `HurtboxComponent/CollisionShape2D`, `HitboxComponent/CollisionShape2D`) and `HealthBar` offsets in the new scene.

Physics layers (`project.godot`): 1 Player, 2 Enemy, 3 HitboxEnemy, 4 HurtboxEnemy, 5 HitboxPlayer, 6 HurtboxPlayer. Bit values are 1, 2, 4, 8, 16, 32. The base already sets body layer 2, hurtbox layer 8 / mask 16, and hitbox layer 4 / mask 32. Any **extra** enemy hitbox must use layer 4 / mask 32. Enemy projectiles: reuse `scenes/weapons/projectiles/projectile_enemy.tscn`.

## 3. Behaviors (optional)

A behavior is a child `Node2D` with a script and `@export var enemy: Enemy` set to `NodePath("..")`. Add it after the base children: base nodes occupy indices 0–9, so the first added node is `index="10"`. Existing ones:

- `ChargeBehavior` (`chanrge_behavior.gd`, sic): `enemy`, `anim_effects` (an `AnimationPlayer` with a `charge` animation), `prep_time`, `cooldown`. See `enemy_charger.tscn`.
- `ShootingBehavior` (`shooting_behavior.gd`): `enemy`, `fire_pos` (`Marker2D` under `Visuals`), `cooldown`, `projectile_count`, `arc_angle`, `projectile_scene`, `projectile_speed`, `stop_duration`. See `enemy_shooter.tscn`.

Rules for a new behavior. Each one fixes a bug this project already had:

```gdscript
extends Node2D
class_name XxxBehavior

@export var enemy: Enemy
@export var cooldown := 3.0

var current_cooldown := 0.0

func _ready() -> void:
	current_cooldown = cooldown

func _process(delta: float) -> void:
	if Global.game_paused:          # custom pause flag, not get_tree().paused
		return

	if enemy == null or enemy.is_dead:   # stop during the die animation / after death
		return
	...
```

- Stop the enemy with `enemy.can_move = false` and release it with `= true`. Never set `true` once `enemy.is_dead`.
- Don't `await get_tree().create_timer(...)`. The enemy can be freed (`HealthComponent.die()` → `queue_free`) mid-await, and the timer ignores `Global.game_paused`. Count down in `_process` instead (see `stop_time_left` in `shooting_behavior.gd`).
- After any `await` on a signal, re-check `enemy.is_dead` before acting.
- Guard divisions by counts (`projectile_count - 1` etc.).
- Static typing and `class_name`, as everywhere in the project.

## 4. Register in Spawner and waves

**`scenes/arena/arena.tscn`**: add an `ext_resource` for the stats `.tres`, append it to `enemy_collection = Array[ExtResource("14_ustats")]([...])` on the `Spawner` node, and bump `load_steps` by 1.

**`resources/waves/data/<wave>.tres`**: add an `ext_resource` for the scene, a sub-resource, and append it to `units`. Then bump `load_steps` by 2.

```
[sub_resource type="Resource" id="Resource_<name>"]
script = ExtResource("<wave_unit_data.gd id>")
unit_scene = ExtResource("<scene id>")
weight = 2.0
metadata/_custom_type_script = "uid://rw3gxqh858sr"
```

Weights are relative within one `WaveDate` (currently slow 6, mid 3, fast 1). Waves past the last `WaveDate.to` reuse the last one (endless mode). For an enemy that should appear only later, create a new `WaveDate` `.tres` with its own `from..to` and add it to `wave_data` on the Spawner.

## Hand-editing scenes

Prefer the editor. When writing `.tscn`/`.tres` by hand, a new file needs a fresh UID (Godot's base-34 encoding, charset `a-y0-8`). Generate it with the `godot-scene-editing` skill's helper, which also checks that the UID is unused in the project:

```sh
python3 -I .claude/skills/godot-scene-editing/new_uid.py 2     # e.g. one for the stats .tres, one for the scene
```

`ext_resource` ids are arbitrary strings that are unique within the file. See `.claude/skills/godot-scene-editing/SKILL.md` for the full hand-editing rules.

## 5. Verify

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --path . --headless --editor --quit >/dev/null 2>&1      # import new assets, register UIDs
$GODOT --path . --headless --quit 2>&1 | grep -v "resource_format_text.cpp:444\|invalid UID"
```

Expect only the pre-existing exit-time leak warning. Then instantiate the enemy for real. `--script` mode does **not** load autoloads, so `enemy.gd` fails to compile there with "Identifier not found: Global". Run [check_enemy.gd](check_enemy.gd) as a temporary scene inside the project and delete it afterwards:

```sh
cp .claude/skills/add-enemy/check_enemy.gd _tmp_check.gd
printf '[gd_scene format=3]\n\n[ext_resource type="Script" path="res://_tmp_check.gd" id="1"]\n\n[node name="Check" type="Node"]\nscript = ExtResource("1")\n' > _tmp_check.tscn
$GODOT --path . --headless res://_tmp_check.tscn 2>&1 | grep -v "resource_format_text.cpp:444\|invalid UID\|GDScript backtrace\|_tmp_check.gd:"
rm -f _tmp_check.gd _tmp_check.gd.uid _tmp_check.tscn
```

It prints every `enemy_*.tscn` with its stats, HP, texture and children, plus the Spawner's scaled stats for waves 1, 2 and 5. Check that the new enemy has its own stats name and texture, its behavior nodes, and that it appears in the scaling list. Run Godot in the background with a time cap if it might hang.

Then run the project-wide check: `.claude/skills/godot-verify/verify.sh` (see the `godot-verify` skill).

Finally, tell the user to open the new scene once in the editor (the inherited-scene tree should look right) and playtest it. Behaviors can't be verified headless.
