# File Purpose Index

> Vom `godot-implementer` gepflegt. Was jede wichtige .gd-Datei tut.

## core/

| Datei | Zweck | ADR |
|-------|-------|-----|
| `event_bus.gd` | Globaler Signal-Hub als Autoload. 18 Signals, gruppiert nach Domäne. | 0001 |
| `content_loader.gd` | Type-indizierte Resource-Registry als Autoload. Eager Discovery beim Boot. | 0003 |
| `save_system.gd` | JSON-Save mit schema_version, atomic-write, Migrations-Pipeline. | 0002 |
| `mod_loader.gd` | Mod-Manifest-Parser, Discovery, Failure-Isolation. | 0005 |
| `run_state.gd` | State-Maschine (IDLE/RUNNING/ENDED), aktiver Dino, Run-Timer. | 0006 |
| `wave_spawner.gd` | Wave-Timer-Logik, Skelett ohne Spawns (Combat-ADR ergänzt). | 0006 |
| `player_mutations.gd` | Aggregator-Autoload, sammelt gepickte Mutationen, additives Stacking. | 0015 |

## core/player/

| Datei | Zweck | ADR |
|-------|-------|-----|
| `player_character.gd` | Generischer Player-Char, DinoDef-getrieben, Mutations-Hook. | 0008 |
| `player_character.tscn` | Scene mit Health + Dealer als Children. | 0008 |

## core/enemy/

| Datei | Zweck | ADR |
|-------|-------|-----|
| `enemy_mob.gd` | Generischer Enemy, EnemyDef-getrieben, enemy_id-Convention. | 0009 |
| `enemy_mob.tscn` | Scene mit Health + Dealer als Children. | 0009 |

## core/run_scene/

| Datei | Zweck | ADR |
|-------|-------|-----|
| `run.gd` | Glue-Skript: instantiiert Player, setzt spawn_root, startet RunState. | 0016 |
| `run.tscn` | main_scene mit PlayerSlot + EnemyContainer. | 0016 |

## core/ui/

| Datei | Zweck | ADR |
|-------|-------|-----|
| `health_bar.gd` | Wiederverwendbare HP-Bar, lokal an HealthComponent gebunden. | 0018 |
| `health_bar.tscn` | Bar-Scene mit BG + FG-ColorRect. | 0018 |
| `game_over.gd` | CanvasLayer-Overlay mit show_run_ended + hide_overlay. | 0019 |
| `game_over.tscn` | Overlay-Scene mit BG-Dimmer + StatsLabel. | 0019 |

## core/combat/

| Datei | Zweck | ADR |
|-------|-------|-----|
| `damage_info.gd` | DamageInfo-Resource (amount, type, source, crit, pierce). | 0007 |
| `damage_modifier.gd` | Modifier-Base-Resource, priority + apply(info)-Konvention. | 0010 |
| `mutation_modifier_bridge.gd` | Static build(MutDef) → {outgoing, incoming, unhandled}. | 0014 |
| `modifiers/flat_bonus_modifier.gd` | +N flat Damage. | 0010 |
| `modifiers/multiplier_modifier.gd` | ×N Damage. | 0010 |
| `modifiers/crit_modifier.gd` | Chance + Multiplier, set_rng-Hook für Tests. | 0010 |
| `modifiers/armor_modifier.gd` | Reduction-pct, respektiert pierce_armor (incoming-only). | 0010 |

## core/components/

| Datei | Zweck | ADR |
|-------|-------|-----|
| `health_component.gd` | HP-Container mit Hot-Path-take_damage und Bus-Death-Notify. | 0007 |
| `damage_dealer_component.gd` | Damage-Quelle mit Modifier-Hook. | 0007 |

## core/content/

| Datei | Zweck |
|-------|-------|
| `content_item.gd` | Abstract Base — id, i18n-keys, source_mod_id, override flag |
| `mutation_def.gd` | Mutation-Schema — rarity, stat_modifiers, tags |
| `enemy_def.gd` | Enemy-Schema — health, speed, damage, xp |
| `boss_def.gd` | Boss-Schema (Stub) — phases-Schema folgt |
| `dino_def.gd` | Player-Char-Schema — health, speed, damage, attack_rate, scene |

## core/save_migrations/

| Datei | Zweck |
|-------|-------|
| `_migration.gd` | Interface-Konvention (Pure Functions) — Doku-Stub |
| `_runner.gd` | Sequenzieller Migrations-Aufrufer, von SaveSystem genutzt |
| `v<n>_to_v<n+1>.gd` | Konkrete Migration (kommt mit erstem Schema-Bruch) |

## content/

| Pfad | Zweck |
|------|-------|
| `mutations/triceratops_horns.tres` | Common, Horn-Build, +15% Damage / +10% Melee-Range |
| `mutations/spinosaur_sail.tres` | Rare, Crit-Build, +10% Crit / +50% Crit-Dmg |
| `mutations/ankylosaur_plates.tres` | Common, Tank-Build, +20% Armor / +15% max HP |
| `dinos/trex.tres` | Erster Dino-Char (Allrounder, 120 HP / 15 DMG) |
| `enemies/raptor_grunt.tres` | Erster Schwarm-Gegner (25 HP / 8 DMG / 120 Speed) |

## tests/

| Pfad | Zweck |
|------|-------|
| `unit/test_event_bus.gd` | EventBus API-Surface + Verhalten, 18 Signals |
| `unit/test_content_loader.gd` | Discovery, Validation, Type-Filter, ID-Convention |
| `unit/test_save_system.gd` | Roundtrip, set_field, EventBus-Hook, Migration-Runner |
| `unit/test_mod_loader.gd` | Manifest-Parse, Discovery, Failure-Modi, EventBus-Signals |
| `unit/test_dino_def.gd` | DinoDef-Validation, ContentLoader-Roundtrip |
| `unit/test_run_state.gd` | State-Übergänge, Active-Dino, EventBus-Signals |
| `unit/test_wave_spawner.gd` | Wave-Lifecycle, Auto-Next, Run-End-Cleanup |
| `unit/test_damage_info.gd` | Resource-Validation, Factory, with_amount |
| `unit/test_health_component.gd` | take_damage, heal, died, Bus-Hooks |
| `unit/test_damage_dealer.gd` | Roundtrip, default_source_id, will_deal_damage |
| `unit/test_modifiers.gd` | Pure-Function, Priority-Sort, RNG-Determinismus, Chain-Tests |
| `unit/test_mutation_modifier_bridge.gd` | Mapping pro stat_key + End-to-End mit triceratops_horns |
| `unit/test_player_mutations.gd` | Pick/Remove/Reset, Aggregation mit drei Mutationen, run_started-Reset |
| `unit/test_player_character.gd` | Komponenten-Setup, _compute_velocity, mutations_changed-Hook, Damage-Roundtrip |
| `unit/test_enemy_mob.gd` | Scene-Hierarchie, setup-Roundtrip, enemy_died mit korrekter ID |
| `unit/test_run_scene.gd` | Player-Spawn, spawn_root, Run-Start, Demo-Spawn, Edge-Cases |
| `unit/test_hit_detection.gd` | Auto-Attack, Touch-Damage, iframes, Mutation-Pipeline-Roundtrip |
| `unit/test_health_bar.gd` | Set-Health, Damage/Heal-Reaktion, Death-Visibility, Re-Bind |
| `unit/test_game_over.gd` | Visibility, Stats-Format mit Reason/Time/Wave |
| `scenes/test_event_bus.tscn` + `.gd` | Manuelle Smoke-Scene mit Button pro Signal |
| `fixtures/save_v1.json` | Reference-Save für Roundtrip / künftige Migrations-Tests |
| `fixtures/mods/{example,broken,wrong_schema}_mod/` | Test-Mods für ModLoader-Suite |

## locale/

| Datei | Zweck |
|-------|-------|
| `de.po`, `en.po` | i18n-Stubs, gepflegt von localization-coordinator |

## Geplant (noch nicht implementiert)

- `core/event_recorder.gd` — Telemetrie-Sidecar (ADR 0004)
- `core/save_migrations/v1_to_v2.gd` — kommt mit erstem Schema-Bruch
