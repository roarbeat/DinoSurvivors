# DinoRogue – Modding-Anleitung

> Quelle: ADR 0005 (Mod-Loader). Diese Doku ist Public-API — Breaking Changes
> hier sind durch den `mod-api-curator` markiert und im CHANGELOG vermerkt.

## TL;DR

```
~/.local/share/godot/app_userdata/DinoRogue/mods/         # Linux
~/Library/Application Support/Godot/app_userdata/DinoRogue/mods/  # macOS
%APPDATA%\Godot\app_userdata\DinoRogue\mods\              # Windows

mods/
└── my_first_mod/
    ├── mod.json                                         # Pflicht
    └── content/
        └── mutations/
            └── my_horn.tres                             # extends MutationDef
```

Beim nächsten Game-Start: dein Mod wird automatisch geladen, wenn `mod.json`
gültig ist. Status siehst du im Output-Log und (später) in der Mod-UI.

## mod.json Schema (v1)

| Feld | Typ | Pflicht | Bedeutung |
|------|-----|---------|-----------|
| `schema_version` | int | ✅ | aktuell `1` |
| `id` | string | ✅ | snake_case, max 40 Zeichen, einmalig |
| `name` | string | ✅ | anzeigbarer Name (beliebige Sprache) |
| `version` | string | ✅ | SemVer (`1.0.0`) |
| `game_version_min` | string | ✅ | minimale unterstützte DinoRogue-Version |
| `game_version_max` | string | ⚪ | maximale unterstützte DinoRogue-Version |
| `author` | string | ⚪ | dein Name oder Pseudonym |
| `description` | string | ⚪ | Kurzbeschreibung |
| `dependencies` | array | ⚪ | Liste anderer Mods (siehe unten) |
| `content_types` | array | ⚪ | welche Types der Mod beisteuert (Hinweis-Daten) |
| `homepage` | string | ⚪ | URL |
| `license` | string | ⚪ | SPDX-ID, z.B. `MIT` |

**Reservierte ID-Präfixe:**
- `core_*` — nur Core-Content darf das nutzen, ModLoader weist Mods mit
  diesem Präfix ab.

**Beispiel `mod.json`:**

```json
{
    "schema_version": 1,
    "id": "horns_of_doom",
    "name": "Horns of Doom",
    "version": "1.2.0",
    "author": "Robin",
    "description": "Mehr Hörner. Härtere Hörner.",
    "game_version_min": "0.0.1",
    "content_types": ["mutation"],
    "license": "MIT"
}
```

## Content beisteuern

Lege `.tres`-Files in den passenden Type-Ordner:

```
my_first_mod/content/
├── mutations/    extends MutationDef
├── enemies/      extends EnemyDef
└── bosses/       extends BossDef
```

ID-Konventionen siehe [`docs/CONTENT.md`](CONTENT.md). Wichtigster Punkt:
**IDs sind unveränderlich** — wenn du eine ID einmal vergeben hast, bleibt sie
das, sonst brechen Saves von Spielern, die deinen Mod nutzen.

## Override-Regel

Dein Mod kann ein Core-Item **überschreiben**, indem du `override_existing = true`
im Resource setzt:

```gdscript
[resource]
script = ExtResource("1_mutdef")
id = &"triceratops_horns"          # gleiche ID wie Core
override_existing = true            # explizit zustimmen
rarity = &"epic"                    # geänderte Werte
...
```

**Standard-Verhalten** (`override_existing = false`): bei ID-Kollision wirft
der ContentLoader eine Warnung und ignoriert dein Resource. Das schützt vor
unbeabsichtigten Überschreibungen.

Bei Override:
- ContentLoader emittet eine Warning ins Log
- Override wird in `ContentLoader.overrides_applied()` gesammelt
- Save-Manifest hält `mod_overrides_used` fest, damit Cross-Mod-Konflikte
  nachvollziehbar sind

## EventBus subscribe (für Logik-Mods)

Die folgenden Signals sind Public-API und stabil zwischen Patch-Versionen
(siehe `agents/memory/mod-api-curator/public-api-surface.md`):

```gdscript
# Beispiel: dein Mod-Script abonniert
EventBus.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated(boss_id: StringName, run_time: float) -> void:
    print("Boss %s in %.1f s besiegt" % [boss_id, run_time])
```

Wichtige Signal-Gruppen:

- **Combat:** `enemy_died`, `player_damaged`, `player_died`
- **Wave:** `wave_started`, `wave_cleared`, `boss_spawned`, `boss_defeated`
- **Mutation:** `mutation_offered`, `mutation_picked`
- **Meta:** `xp_gained`, `level_up`, `currency_changed`
- **Save:** `save_requested`, `save_completed`, `save_loaded`
- **Mods:** `mod_loaded`, `mod_failed`
- **Boot:** `content_loaded`

Vollständige Liste mit Parametern: [`core/event_bus.gd`](../core/event_bus.gd).

## Failure-Modi (was schief gehen kann)

| Fehler | ModLoader-Verhalten |
|--------|---------------------|
| `mod.json` fehlt | Mod ignoriert, `mod_failed:missing_mod_json` |
| `mod.json` invalid JSON | `mod_failed:invalid_json` |
| Pflichtfeld fehlt | `mod_failed:missing_field:<feld>` |
| `id` Format-Verstoß | `mod_failed:invalid_id_format` |
| `id` reservierter Präfix | `mod_failed:reserved_prefix` |
| `id` Kollision mit anderem Mod | beide → `mod_failed:id_collision` |
| `manifest_schema_version` ≠ 1 | `mod_failed:manifest_schema_mismatch` |

Andere Mods und Core-Spiel laufen weiter.

## Geplant für künftige Versionen

- Topo-Sort über `dependencies` mit Cycle-Detection (ADR 0009 Backlog)
- Mod-UI in den Settings (ADR 0010 Backlog)
- Steam-Workshop-Integration (ADR 0011 Backlog)

## Compatibility-Versprechen

DinoRogue verspricht für die Public-API (EventBus-Signals + ContentLoader +
Resource-Schemas + mod.json-Schema):
- Keine **Breaking Changes** in **Patch-Versionen** (z.B. 0.1.x → 0.1.y)
- **Minor-Versionen** (0.1.x → 0.2.0) können Breaking Changes enthalten,
  werden aber im CHANGELOG mit `BREAKING (modders)` markiert und mit
  Migration-Guide versehen
- **Major-Versionen** sind die einzige Stelle, an der grundlegende API-Brüche
  passieren können
