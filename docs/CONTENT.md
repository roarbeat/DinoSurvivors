# Content-Pipeline

> Wie der `content-author` (Agent oder Mensch) neuen Content anlegt.
> Spec-Quelle: ADR 0003.

## Vorgehen pro neuer Mutation/Gegner/Boss/Welle

1. **ID wählen**
   - snake_case, ASCII a–z + 0–9 + _, max 40 Zeichen
   - In `agents/memory/content-author/content-id-registry.md` prüfen,
     ob die ID schon existiert
   - Naming-Conventions in `agents/memory/content-author/naming-conventions.md`

2. **`.tres`-File anlegen**
   - Pfad: `res://content/<type>/<id>.tres`
   - Script: passende Resource-Klasse aus `res://core/content/`
   - Alle i18n-Keys folgen `<type>.<id>.<field>`
   - `source_mod_id = &""` für Core, `override_existing = false`
   - Templates in `agents/memory/content-author/content-templates.md`

3. **Translation-Keys ergänzen**
   - In `locale/de.po` UND `locale/en.po`
   - lore-writer-Agent triggern, falls Tooltip-Text noch nicht vorhanden
   - Konsistenz mit `agents/memory/localization-coordinator/translation-glossary.md`

4. **BALANCE.csv-Eintrag**
   - Eine Zeile pro Item mit den wichtigsten Stats
   - Notes-Spalte: Begründung der Wahl, Synergie-Hinweise

5. **Manuelle Verifikation**
   - Godot-Editor öffnen, Resource lädt ohne Error
   - Smoke-Run: `tests/scenes/test_event_bus.tscn` zeigt `content_loaded`
     mit gestiegenem item_count

6. **Memory aktualisieren**
   - ID in `content-id-registry.md` eintragen
   - Wenn neue Stat-Keys: in `naming-conventions.md` ergänzen

## Was NICHT der content-author tut

- `.gd`-Code schreiben (das ist `godot-implementer`)
- Bestehende IDs umbenennen (Prinzip 6 — niemals)
- Neue Stat-Felder erfinden ohne Rücksprache mit `game-architect`
  (das ist eine Schema-Änderung, kein Content-Add)

## Visual-Provider (ADR 0027)

`EnemyDef`, `DinoDef` und `BossDef` haben einen optionalen Slot
`visual_scene: PackedScene`. Damit wird eine eigene Visual-Scene statt
des ColorRect-Bodys angezeigt (z.B. AnimatedSprite2D mit Idle/Walk-
Frames).

**Convention für Visual-Scenes**

- Wurzel-Node ist `Node2D` (oder eine Subklasse wie `AnimatedSprite2D`)
- Pivot ist auf (0, 0) zentriert
- Bei abweichender Höhe `visual_pivot_offset` auf der Def setzen,
  damit die HealthBar korrekt sitzt

```gdscript
# Beispiel-EnemyDef mit Sprite
visual_scene = preload("res://art/raptor_grunt.tscn")
visual_pivot_offset = Vector2(0, -4)  # HealthBar 4px höher
```

Wenn `visual_scene` null bleibt, fällt der Mob auf den ColorRect-Mode
zurück (siehe ADR 0024 — `body_color`/`body_size`).

## Wave-Spezifika (Type `wave`, ADR 0026)

WaveDefs unterscheiden sich von Mutation/Enemy/Boss in einem Punkt:
**zwei Modi**, die sich gegenseitig ausschließen.

- **Curve-Default** (`is_default = true`, `target_wave_index = 0`)
  Genau **eine** WaveDef trägt das Flag. Definiert die Spawn-Curve
  (`base_spawn_rate`, `spawn_rate_per_wave`, `max_spawn_rate`) und
  optional einen Default-`enemy_pool` für alle Wellen ohne Override.

- **Wave-Override** (`is_default = false`, `target_wave_index = N`)
  Übersteuert eine bestimmte Welle. Felder, die hier gesetzt sind
  (Pool, Boss, Dauer), gewinnen über die Curve-Default.

```
content/waves/
├── wave_default.tres          ← genau einer mit is_default=true
├── wave_5_tyrannosaurus.tres  ← target_wave_index=5
└── wave_10_tyrannosaurus.tres ← target_wave_index=10
```

Der WaveSpawner-Resolver (siehe `core/wave_spawner.gd::get_wave_def_for`)
priorisiert: Override → Default → Konstanten-Fallback.

**Validate-Regeln** (vom ContentLoader gechecked, sonst Skip mit Warning):

- `is_default=true` UND `target_wave_index>0` ist invalid
- weder `is_default` noch `target_wave_index>0` ist invalid (ungenutzt)
- `boss_id` darf nur auf Override-WaveDefs gesetzt sein
- `max_spawn_rate >= base_spawn_rate`

Modder können „Welle 7 ist immer ein Pteranodon-Schwarm" definieren,
indem sie `wave_7_my_swarm.tres` mit `target_wave_index = 7` und
spezifischem `enemy_pool` ergänzen.

## Mod-Author-Variante

Mods folgen demselben Schema, nur unter `user://mods/<mod_id>/content/<type>/`.
Override eines Core-Items: `override_existing = true` im Resource setzen.
Loader emittiert Warning + listet in `ContentLoader.overrides_applied()`.
