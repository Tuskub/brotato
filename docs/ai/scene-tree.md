# Scene tree, inheritance and physics layers

Node trees of the main scene and the reusable unit, weapon and UI scenes. Format: `Name (Type, script) key props`. `%` means `unique_name_in_owner = true`. Inherited nodes that a child scene only overrides are omitted unless they matter.

## 1. `scenes/arena/arena.tscn` (`uid://dy355015qgab6`, the main scene, `project.godot` `run/main_scene`)

```
Arena (Node2D, arena.gd) groups=["arena"]                          arena.tscn:29
│  normal_color (1,1,1) · block_color (1,0.29,0.455) · critical_color (0.996,0.78,0.38)
│  hp_color (0,0.627,0.482) · use_save_data = true                 arena.tscn:31-35
├─ BlackBG (Sprite2D) scale 2, assets/sprites/BG.png
├─ GrassBG (Sprite2D) scale 2, assets/sprites/Map.png
├─ Camera2D (Camera2D, camera_2d.gd → class Camera) follows Global.player
├─ Spawner (Node2D, spawner.gd)                                     arena.tscn:48-51
│    wave_data = [wave_1_to_5.tres]
│    enemy_collection = [stat_enemy_chaser_slow, _chaser_mid, _chaser_fast, _charger, _shoter]
│    spawn_area_size (1000,500), endless_spawn_time_decrease 0.05, endless_min_spawn_multiplier 0.25 (script defaults)
│  ├─ SpawnTimer (Timer) one_shot
│  └─ WaveTimer (Timer) one_shot
├─ GameUI (CanvasLayer)
│  ├─ WaveIndexLabel % (Label, 64px)       ← Spawner.get_wave_text()
│  ├─ WaveTimeLabel % (Label, 64px)        ← Spawner.get_wave_timer_text()
│  ├─ UpgragePanel % (instance upgrage_panel.tscn) visible=false
│  ├─ ShopPanel % (instance shop_panel.tscn) visible=false
│  ├─ CoinsBag % (instance coins_bag.tscn)
│  ├─ SelectionPanel % (instance selection_panel.tscn) visible (default)
│  └─ StartMenu % (instance start_menu.tscn, referenced by path only, no UID) visible=false
└─ MusicPlayer (AudioStreamPlayer) "Bg Music.mp3", -20 dB, autoplay, bus Music
```
Created at runtime under Arena: the player (`add_child` in `arena.gd:42/157`), enemies and `EnemySpawnEffect`s (Spawner's `get_parent()`, `spawner.gd:82,90`), coins (`call_deferred('add_child')`, `arena.gd:120`). Created under `get_tree().root`: projectiles (`range_behavior.gd:25`, `shooting_behavior.gd:54`) and floating texts (`arena.gd:98`).

## 2. Scene inheritance graph (UIDs from the scene headers)

```
unit.tscn  uid://xoi5bf006vpc  (Unit root = Area2D)
├─ enemies/enemy_base.tscn  uid://h4qyxvfputld  (script → enemy.gd, NO stats / texture)
│   ├─ enemy_chaser_slow.tscn  uid://cwiud4jd3uiwc   stats + Enemy_1.png
│   ├─ enemy_chaser_mid.tscn   uid://dqra0wv8gndxm   stats + Enemy_2.png
│   ├─ enemy_chaser_fast.tscn  uid://cfan46km6mh65   stats + Enemy_3.png
│   ├─ enemy_charger.tscn      uid://n8xlqxlsl5el    + ChanrgeBehavior + AnimationEffects, Enemy_5.png
│   └─ enemy_shooter.tscn      uid://dt0abjo0fjjcj   + ShootingBehavior + Visuals/FirePos, Enemy_4.png
└─ players/player_well_rounded.tscn  uid://jadv5cnwph1c  (script → player.gd; a playable character AND the base of the other 4)
    ├─ player_brawler.tscn  uid://nk87ujktnw1c   stats + Player_2.png
    ├─ player_bunny.tscn    uid://by1lqht47vkds   stats + Player_4.png
    ├─ player_crazy.tscn    uid://bsxha0eaawok4   stats + "Player_3}.png"
    └─ player_knight.tscn   uid://dlxdaijg5gkku   stats + Player_5.png

weapons/weapon_base.tscn  uid://dcc7rsdy4j8v6  (Weapon, Node2D)
├─ melee/weapon_axe.tscn      uid://bpc7qmrh8hs0n   ┐
├─ melee/weapon_chainsaw.tscn uid://d2k5wxsuodxib   │ + Sprite2D/HitboxComponent,
├─ melee/weapon_mace.tscn     uid://c40id7ntypee8   │   WeaponBehavior script = melee_behavior.gd
├─ melee/weapon_punch.tscn    uid://d1igydtpm3sq8   │
├─ melee/weapon_sword.tscn    uid://dpfr7bp8hxeth   │
├─ melee/weapon_wand.tscn     uid://tpvqjv8raieb    ┘
├─ range/weapon_lazer.tscn    uid://wophsdj4mw5m    ┐
├─ range/weapon_pistol.tscn   uid://jkxk68loxb55    │ + Sprite2D/Muzzle %,
├─ range/weapon_revolver.tscn uid://cft8rb2ggqdui   │   WeaponBehavior script = range_behavior.gd
├─ range/weapon_shotgun.tscn  uid://ddi16trhufcq    │
└─ range/weapon_smg.tscn      uid://bbm5yl708x174   ┘

weapons/projectiles/projectile_pistol.tscn  uid://1rjigu81muqp  (Projectile; base of the others)
├─ projectile_enemy.tscn    uid://q6vcpbi8wuoa   hitbox re-layered to enemy side (4/32)
├─ projectile_lazer.tscn    uid://dpd483djqnssl
├─ projectile_revolver.tscn uid://b5ujji5yqlgqx
├─ projectile_shotgun.tscn  uid://bg3wkn4k4al02
└─ projectile_smg.tscn      uid://b1gvqt7an25u1
```
Composition (instanced, not inherited): `components/hitbox_component.tscn` `uid://c0fyx8gj5uexl`, `components/hurtbox_component.tscn` `uid://bkyyic3okyjxx`, `components/health_component.tscn` `uid://2ew7i6g3p0v8`, `ui/health_bar.tscn` `uid://ifmw1e7gycc8` (in `unit.tscn`), `ui/custom_button/custom_button.tscn` `uid://cexaxg5jj2ljl` (in SelectionPanel, ShopCard, StartMenu, UpgradeCard), `ui/stats_container/stats_container.tscn` `uid://cp1haphh1gj8t` (in ShopPanel **and** UpgragePanel), `ui/shop_card` `uid://3aptedc0ypht`, `ui/item_card` `uid://jo7b40q6dpjw`, `ui/upgrade_card` `uid://bfohai4xgom8w`, `ui/selection_card` `uid://c0c53v7p12lwu`, `ui/floating_text` `uid://qkwyrg22h3gi`, `coins/coins.tscn` `uid://b00ep0bndm7sr`, `effects/enemy_spawn_effect.tscn` `uid://cvcrh2erbeae5`. The UIDs that `Global` preloads are listed in `autoloads/global.gd:35-63`.

## 3. Units

### `scenes/units/unit.tscn` (base)
```
Unit (Area2D, unit.gd)   export stats: UnitStats           unit.tscn:252
├─ Visuals % (Node2D) scale (0.5,0.5)                       ← flipped via scale.x
│  ├─ Shadow (Sprite2D) shadow.png, modulate dark, scale (0.8,1)
│  └─ Sprite % (Sprite2D) position (0,-61), no texture      ← FLASH_MATERIAL target
├─ CollisionShape2D (no shape in base)
├─ AnimationPlayer: RESET, die, idle, move
├─ HurtboxComponent (Area2D, hurtbox_component.gd)          on_damaged → Unit._on_hurtbox_component_on_damaged
├─ HealthComponent (Node, health_component.gd)              on_health_changed → HealthBar
├─ HealthBar (Control, health_bar.gd) offsets (-46,-90)-(50,-70); exports back_color, fill_color
└─ FlashTimer (Timer) 0.2 s one_shot
```

### `scenes/units/enemies/enemy_base.tscn` (overrides and additions)
```
EnemyBase (inherits Unit; script enemy.gd) collision_layer=2, flock_push=20     enemy_base.tscn:19-22
├─ CollisionShape2D  Circle r=3 at (0,-29)
├─ VisionArea (Area2D) layer 0, mask 2 → CollisionShape2D Circle r=150 at (0,-29)   (flocking)
├─ HurtboxComponent  layer 8, mask 16 → Circle r=35 at (0,-29)
├─ HitboxComponent (instance) layer 4, mask 32 → Circle r=37 at (0,-29)            (contact damage; never .setup())
├─ HealthBar back (0.016,0.055,0.169) fill (0.373,0.537,0.757)
└─ KnockbackTimer (Timer) 0.4 s one_shot
```
- `enemy_charger.tscn`: `ChanrgeBehavior` (Node2D, `chanrge_behavior.gd`; **the node name is misspelled too**) with `enemy = ".."`, `anim_effects = "../AnimationEffects"`, and the script defaults `prep_time 1.0` (unused) and `cooldown 3.0`. `AnimationEffects` (AnimationPlayer: `charge` 0.7 s, RESET) (`enemy_charger.tscn:52-60`).
- `enemy_shooter.tscn`: `Visuals/FirePos` (Marker2D at (-86,-48)) and `ShootingBehavior` (Node2D, `shooting_behavior.gd`) with `enemy = ".."`, `fire_pos`, `projectile_scene = projectile_enemy.tscn`, and the script defaults `cooldown 3.0`, `projectile_count 3`, `arc_angle 45`, `projectile_speed 1800`, `stop_duration 1.0` (`enemy_shooter.tscn:15-22`).

### `scenes/units/players/player_well_rounded.tscn` (Player base and the Well Rounded character)
```
PlayerWellRounded (inherits Unit; script player.gd) collision_mask=2           :20-26
│  dash_duration 0.5 · dash_speed_multi 1.5 · dash_cooldown 0.5 · stats = stat_player_well_rounded.tres
├─ Visuals
│  ├─ Trail % (Line2D, trail.gd) index 0, top_level, width 50, trail_length 30, player = "../.."
│  ├─ Shadow
│  └─ Sprite (index 2) z_index 1, Player_1.png       ← child players override "Sprite" parent="Visuals" index="2"
├─ CollisionShape2D Circle r≈1.41 at (0,-31)        ← disabled during dash; picks up coins
├─ WeaponContainer (Node2D, weapon_container.gd)
│  ├─ One   (1 Marker2D)   (0,-15)
│  ├─ Two   (2) (±40,20)
│  ├─ Three (3) (±40,20) (0,-115)
│  ├─ Four  (4) (±40,20) (±40,-115)
│  ├─ Five  (5) (±40,20) (±60,-40) (0,-115)
│  └─ Six   (6) (±35,20) (±35,-115) (±60,-45)
├─ DashTimer, DashCooldownTimer (Timer; one_shot/wait_time set in _ready)
├─ TrailTimer % (Timer) one_shot
├─ HurtboxComponent layer 32, mask 4 → Circle r≈33.06 at (0,-31)
├─ HealthBar back (0.137,0.02,0.027) fill (1,0.29,0.455)
└─ HPRegenTimer (Timer) 3.0 s autostart → _on_hp_regen_timer_timeout
```
Weapon nodes are added as **direct children of the player** (`player.gd:85-91`), not of `WeaponContainer`. Their `global_position` is copied from the markers of the group whose size equals the weapon count (`weapon_container.gd:12-28`).

## 4. Weapons and projectiles

### `scenes/weapons/weapon_base.tscn`
```
WeaponBase (Node2D, weapon.gd)
├─ Sprite2D z_index 1, scale 0.5, ShaderMaterial(outline.gdshader, resource_local_to_scene=true,
│           outline_color white, outline_width 8, glow_intensity 4)
├─ RangeArea (Area2D) layer 0, mask 2
│  └─ CollisionShape2D % CircleShape2D r=150 — NOT local_to_scene, shared by every weapon instance (known-issues §1.2)
├─ CooldownTimer (Timer) one_shot; wait_time = stats.cooldown on each attack
└─ WeaponBehavior (Node2D) — script assigned by each child scene; export weapon = ".."
```
- **Melee** child scenes add `Sprite2D/HitboxComponent` (layer 16, mask 8) with a weapon-specific shape (axe Capsule r18.5 h72 ×2 scale; chainsaw Capsule r27 h156; mace Circle r42; punch Rect 52×38 ×2 scale, `monitoring=false`; sword Capsule r30.6 h174.7; wand Rect 74×78). `WeaponBehavior` uses `melee_behavior.gd` with `hitbox` and `weapon` set.
- **Range** child scenes add `Sprite2D/Muzzle %` (Marker2D) and `WeaponBehavior` with `range_behavior.gd`. The projectile scene comes from `WeaponStats.projectile_scene`, not from the weapon scene.

### `scenes/weapons/projectiles/projectile_pistol.tscn`
```
ProjectilePistol (Node2D, projectile.gd) export hitbox = HitboxComponent
├─ Sprite2D scale 0.6
├─ HitboxComponent layer 16, mask 8 → Circle r=22 at (-3,0)    on_hit_hurtbox → queue_free
└─ VisibleOnScreenNotifier2D                                   screen_exited → queue_free
```
`projectile_enemy.tscn` re-layers the hitbox to layer 4, mask 32 (`projectile_enemy.tscn:11-13`).

## 5. UI scenes

| Scene | Root (type, script) | Key nodes (all `%` unless noted) | Exports / notes |
|---|---|---|---|
| `ui/selection_panel/selection_panel.tscn` | `SelectionPanel` (Panel, `selection_panel.gd`) | `PlayerIcon`, `PlayerName`, `PlayerTitle` (never filled), `PlayerDescription` (RichTextLabel), `PlayerContainer`/`WeaponContainer` (HBox; their placeholder buttons are freed in `_ready`), `ContinueButton` (CustomButton, not `%`) | `players` = 5 `UnitStats`, `start_weapon` = 11 tier-I `ItemWeapon`s (`selection_panel.tscn:41-42`) |
| `ui/start_menu/start_menu.tscn` | `StartMenu` (Panel, `start_menu.gd`) | `VBoxContainer/ContinueButton`, `VBoxContainer/NewGameButton` (CustomButton) | No UID in the header, script referenced by path |
| `ui/upgrade_panel/upgrage_panel.tscn` | `UpgragePanel` (Panel, `upgrage_panel.gd` → class `UpgradePanel`) | `ItemsContainer` (HBox, 4 placeholder UpgradeCards), `StatsContainer` | `upgrade_list` = 46 `ItemUpgrade` (`upgrage_panel.tscn:68`) |
| `ui/upgrade_card/upgrade_card.tscn` | `UpgradeCard` (Panel) | `Icon`, `Name`, `Description` (Label), `CustomButton` → `_on_custom_button_pressed` | `item_data: ItemUpgrade` (setter applies the tier style) |
| `ui/shop_panel/shop_panel.tscn` | `ShopPanel` (Panel, `shop_panel.gd`) | `ItemsContainer` (HBox, 4 placeholder ShopCards), `StatsContainer`, `Passives/PassivesContainer` (Grid), `Weapons/WeaponsContainer` (Grid), `VBoxContainer/NewWaveButton`, `CombineButton` %, `SellButton` | `shop_items` = 44 weapons + 4 passives (`shop_panel.tscn:96`). Preloads `SHOP_CARD_SCENE` `uid://3aptedc0ypht` |
| `ui/shop_card/shop_card.tscn` | `ShopCard` (Panel) | `ItemIcon`, `ItemName`, `ItemType`, `ItemDescription` (RichText), `BuyButton` (CustomButton) / `CoinsLabel` | `shop_item: ItemBase` |
| `ui/item_card/item_card.tscn` | `ItemCard` (Button) | `ItemIcon` (TextureRect) | `item: ItemBase` (setter: icon + tier style) |
| `ui/selection_card/selection_card.tscn` | `SelectionCard` (Button) | — | `set_icon(texture)` |
| `ui/stats_container/stats_container.tscn` | `StatsContainer` (Panel) | `HealthLabel`, `HPRegenLabel`, `LifeStealLabel`, `DamageLabel`, `LuckLabel`, `SpeedLabel`, `BlockLabel`, `HarvestingLabel` | Polls `Global.player.stats` every frame |
| `ui/coins_bag/coins_bag.tscn` | `CoinsBag` (HBoxContainer) | `TextureRect` (gold_1.png), `Coins` (Label) | Polls `Global.coins`; the coin fly target is `global_position + size/2` |
| `ui/health_bar.tscn` | `HealthBar` (Control) | `ProgressBar`, `HealthAmount` (Label) | `back_color`, `fill_color` (duplicated styleboxes) |
| `ui/floating_text/floating_text.tscn` | `FloatingText` (Node2D) | `ValueLabel` | `setup(text, color)` |
| `ui/custom_button/custom_button.tscn` | `CustomButton` (Button, no script) | — | Default text "select" |
| `coins/coins.tscn` | `Coins` (Area2D, `coins.gd`) layer 0, mask 1 (default) | `Shadow`, `AnimatedSprite2D` (gold_1–4), `CollisionShape2D` Circle r=63 | `move_speed 1000`, `collect_distance 15` |
| `effects/enemy_spawn_effect.tscn` | `EnemySpawnEffect` (Sprite2D, Spawn_mark.png) | `AnimationPlayer` autoplay `spawn` (0.8 s) | |
| `autoloads/sound_manager.tscn` | `SoundManager` (Node) | 10 × `AudioStreamPlayer` (-15 dB, bus SFX) | `stream_players` export lists all 10 |

## 6. Physics layers

Names from `project.godot` `[layer_names]`. Bit value = `1 << (layer-1)`, which is what `collision_layer` / `collision_mask` store in `.tscn`.

| Layer | Name | Bit value |
|---|---|---|
| 1 | Player | 1 |
| 2 | Enemy | 2 |
| 3 | HitboxEnemy | 4 |
| 4 | HurtboxEnemy | 8 |
| 5 | HitboxPlayer | 16 |
| 6 | HurtboxPlayer | 32 |

| Node | layer | mask | Source | Purpose |
|---|---|---|---|---|
| Player root (Area2D) | 1 (default) | 2 | `player_well_rounded.tscn:21` | Coins detect it; root shape is tiny (r≈1.41) |
| Enemy root (Area2D) | 2 | 1 (default) | `enemy_base.tscn:20` | Seen by weapon `RangeArea` and other enemies' `VisionArea` |
| Enemy `VisionArea` | 0 | 2 | `enemy_base.tscn:31-32` | Flocking push between enemies |
| Enemy `HitboxComponent` | 4 | 32 | `enemy_base.tscn:48-49` | Contact damage on the player |
| Enemy `HurtboxComponent` | 8 | 16 | `enemy_base.tscn:39-40` | Receives player hits |
| Player `HurtboxComponent` | 32 | 4 | `player_well_rounded.tscn:135-136` | Receives enemy contact / projectile hits |
| Weapon `RangeArea` | 0 | 2 | `weapon_base.tscn:25-26` | Target acquisition |
| Melee `Sprite2D/HitboxComponent` | 16 | 8 | each `scenes/weapons/melee/weapon_*.tscn` | Player melee damage |
| Player projectiles `HitboxComponent` | 16 | 8 | `projectile_pistol.tscn:19-20` (inherited by lazer/revolver/shotgun/smg) | Player ranged damage |
| Enemy projectile `HitboxComponent` | 4 | 32 | `projectile_enemy.tscn:12-13` | Shooter damage |
| `Coins` | 0 | 1 (default) | `coins.tscn:34` | `area_entered` from the player root → `collected = true` |
| `hitbox_component.tscn` / `hurtbox_component.tscn` bases | 1 / 1 (defaults) | 1 / 1 | no override in the component scenes | **Every instance must override both**, or it sits on the Player layer |

Hit detection is symmetric: a hurtbox's mask must include the hitbox layer (hurtbox emits `on_damaged`), and a hitbox's mask must include the hurtbox layer (hitbox emits `on_hit_hurtbox`, which projectiles use to despawn).
