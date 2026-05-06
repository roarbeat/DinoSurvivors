# Architecture Overview

> Vom `game-architect` gepflegt. Aktuelles System-Diagramm in Worten.

## Aktueller Stand (2026-05-06)

Phase 0a + EventBus + ContentLoader-Skelett stehen.

### Zentrale Bausteine

```
                    +----------------------+
                    |     EventBus         |  Autoload (ADR 0001)
                    |  (signal-only Hub)   |
                    +----------+-----------+
                               ^
        +----------------------+----------------------+
        |                      |                      |
   Producers              Consumers              EventRecorder
   - WaveSpawner          - HUD/UI               (Sidecar, geplant)
   - CombatSystem         - SaveSystem
   - BossController       - Achievements
   - PlayerInput          - VFX-Hooks
   - Mods                 - Mods

                    +----------------------+
                    |   ContentLoader      |  Autoload (ADR 0003)
                    |   eager registry     |
                    +----------+-----------+
                               |
            res://content/ + user://mods/<id>/content/
            type-indexed: mutations, enemies, bosses, …
            ID-Validation, Override-Handling
            feuert: content_loaded(type_count, item_count)
```

### Geplante Module (in Reihenfolge)

| Modul | Datei | Status | ADR |
|-------|-------|--------|-----|
| EventBus | `core/event_bus.gd` | **implementiert** | 0001 |
| ContentLoader | `core/content_loader.gd` | **implementiert** | 0003 |
| Resource-Schemas | `core/content/*.gd` | **implementiert** | 0003 |
| SaveSystem | `core/save_system.gd` | **implementiert** | 0002 |
| ModLoader | `core/mod_loader.gd` | **implementiert** | 0005 |
| RunState | `core/run_state.gd` | **implementiert** | 0006 |
| WaveSpawner | `core/wave_spawner.gd` | **implementiert** | 0006 |
| HealthComponent | `core/components/health_component.gd` | **implementiert** | 0007 |
| DamageDealer | `core/components/damage_dealer_component.gd` | **implementiert** | 0007 |
| DamageInfo | `core/combat/damage_info.gd` | **implementiert** | 0007 |
| DamageModifier-Familie | `core/combat/modifiers/*.gd` | **implementiert** | 0010 |
| MutationModifierBridge | `core/combat/mutation_modifier_bridge.gd` | **implementiert** | 0014 |
| PlayerMutations | `core/player_mutations.gd` | **implementiert** | 0015 |
| PlayerCharacter | `core/player/player_character.gd` + `.tscn` | **implementiert** | 0008 |
| EnemyMob | `core/enemy/enemy_mob.gd` + `.tscn` | **implementiert** | 0009 |
| RunScene | `core/run_scene/run.gd` + `.tscn` | **implementiert** | 0016 |
| EventRecorder | `core/event_recorder.gd` | offen | 0004 |

### Aktive ADRs

| Nr | Titel | Status |
|----|-------|--------|
| 0001 | Globaler EventBus | Accepted |
| 0002 | Save-System & Schema-Versionierung | Accepted |
| 0003 | ContentLoader & Resource-Konventionen | Accepted |
| 0004 | EventRecorder & Telemetrie-Format | Backlog |
| 0005 | Mod-Loader Boot-Reihenfolge | Accepted |
| 0006 | Run-Lifecycle, Wave-Spawner & Dino-Resources | Accepted |
| 0007 | Combat-Pipeline | Accepted |
| 0008 | Player-Character-Scene + Movement | Accepted |
| 0009 | Enemy-Mob-Pattern + Spawn-API | Accepted |
| 0016 | Run-Scene-Glue | Accepted |
| 0010 | Modifier-Pipeline | Accepted |
| 0011 | Hit-Detection v1 (distanz-basiert) | Accepted |
| 0013 | Auto-Spawn-Curves v1 (prozedural) | Accepted |
| 0017 | Enemy-Movement v1 (Direkt-Walk) | Accepted |
| 0018 | Visueller Stub + HP-Bar | Accepted |
| 0019 | Game-Over-Overlay + Run-Restart | Accepted |
| 0014 | Mutation→Modifier-Bridge | Accepted |
| 0015 | Player-Mutation-System | Accepted |
| 0006 | Hot-Reload-Workflow Dev | Backlog |

### 7 Kern-Prinzipien — Status

| # | Prinzip | Status |
|---|---------|--------|
| 1 | Data-driven alles | **adressiert** durch ADR 0003 |
| 2 | Event-Bus | **adressiert** durch ADR 0001 |
| 3 | Save-Versionierung | **adressiert** durch ADR 0002 |
| 4 | Lokalisierung Tag 1 | po-File-Stubs angelegt, tr() Convention dokumentiert |
| 5 | Mod-freundlich | **adressiert** durch ADR 0001 + 0003 + 0005 (mod.json + Public-API) |
| 6 | Stable Content-IDs | **adressiert** durch ADR 0003 (ID-Convention + Validation) |
| 7 | Systeme alleine testbar | unterstützt durch ADR 0001 + 0003 |

### Public-API-Surface (für mod-api-curator)

- alle 21 Signals in `core/event_bus.gd` (incl. content_loaded, run_started, run_ended, mutations_changed)
- ContentLoader-Methoden: `get`, `get_or_null`, `get_all`, `has`,
  `types`, `all_ids`
- Resource-Klassen: `ContentItem`, `MutationDef`, `EnemyDef`, `BossDef`
- Pfad-Konvention `res://content/<type>/` und `user://mods/<id>/content/<type>/`
