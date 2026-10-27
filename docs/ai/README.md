# AI reference docs

Deep reference for agents working on this Godot 4.5 game. `CLAUDE.md` at the repo root stays the short overview (commands, architecture, conventions). These files hold the details it links to. Everything here was read from the code on `master` at `0acbae2`, with file:line references. When the code changes, update the matching section. A line number is a pointer, so re-check it before editing.

| File | Read it when you… | Contents |
|---|---|---|
| [`signals-and-flow.md`](signals-and-flow.md) | add or debug a signal, touch the wave/shop/upgrade loop, pausing, or saving | Every `Global` bus signal and local signal (emitter, args, connection, handler), built-in connections in `.tscn`, the step-by-step run lifecycle StartMenu → SelectionPanel → wave → UpgradePanel → Shop → next wave, `game_paused` transitions and who honors them, save/load points and the save JSON format, what persists between waves |
| [`scene-tree.md`](scene-tree.md) | add or edit a scene, node path, `%Unique` name, hitbox, hurtbox or collision layer | Node tree of `arena.tscn`, unit/enemy/player/weapon/projectile/UI scenes with types, scripts and key exports, the scene inheritance graph with UIDs, the physics layer table (bit values and which node uses which layer/mask) |
| [`data-catalog.md`](data-catalog.md) | balance numbers, add a character/enemy/weapon/item/wave, or answer "what does X do" | Tables of every character, enemy (+ per-wave growth), weapon tier and upgrade chain (+ sell prices), upgrade, passive and wave. Endless-mode spawn scaling, tier probability config with computed odds, tier colors/styles, prices, audio |
| [`known-issues.md`](known-issues.md) | before fixing a bug, before relying on a mechanic, or when something "doesn't work" | Gameplay bugs, risky patterns (shared mutated `UnitStats`, string stat ids), dead code and unused stats, a full misspelling table, drift between `CLAUDE.md` and the code. None of it is fixed |

Conventions used here:
- Paths are relative to the repo root (`res://` stripped). `file.gd:12` or `file.gd:12-20` points at lines in that file.
- In data tables, `*` marks a script default that the `.tres` doesn't store.
- Identifiers are spelled exactly as in code, misspellings included (`upgrage_panel`, `damege_increase_pre_wave`, `Shoter`, …).

Related: the task skills in `.claude/skills/*/SKILL.md` (for example `add-enemy`) give step-by-step recipes. These docs are the reference those recipes rely on.

Quick verification of a claim: `grep -n "<identifier>" -r scenes autoloads resources --include='*.gd' --include='*.tscn' --include='*.tres'`. For runtime facts (UID resolution, shared resources), use a temporary `res://_tmp_<prefix>_check.tscn` harness as described in `CLAUDE.md`.
