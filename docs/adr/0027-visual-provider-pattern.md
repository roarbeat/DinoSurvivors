# ADR 0027 – Visual-Provider-Pattern

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer + shader-fx-specialist (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #5 Mod-friendly, #7 testbar
- Voraussetzungen: ADR 0008 (PlayerCharacter), ADR 0009 (EnemyMob), ADR 0024 (Visual-Diff Color), ADR 0025 (BossMob)
- Wird vorausgesetzt von: ADR — AnimatedSprite2D-State-Machine (eigenes ADR), ADR — Skeletal-Rigging

---

## 1. Kontext

Heute rendern Mobs (Player, Enemy, Boss) als `ColorRect`-Quadrate.
Die Farbe und Größe kommt aus der jeweiligen Def
(`body_color: Color`, `body_size: Vector2`, ADR 0024). Das ist
funktional, aber visuell flach.

Wenn echte Sprites kommen (`AnimatedSprite2D` mit Idle/Walk/Hit/Death-
Frames), brauchen wir einen Migrations-Pfad, der:

- **die ColorRect-Tests nicht bricht** (Backward-Kompatibilität)
- **per Mob-Typ unabhängig wechseln kann** (raptor_grunt = Sprite,
  pteranodon = ColorRect, bis Asset fertig ist)
- **Mods erlaubt eigene Visuals einzuhängen** ohne Core-Code zu touchen

Anforderungen v1:

- Neuer optionaler Slot `visual_scene: PackedScene` auf Defs
  (EnemyDef, DinoDef, BossDef)
- Wenn gesetzt, instanziert Mob die Scene und versteckt das ColorRect
- Wenn null, bleibt ColorRect-Mode aktiv (Default)
- HealthBar-Position basiert weiterhin auf `body_size` (oder neu:
  `visual_pivot_offset`) — Sprites müssen ihre Größe nicht im Def
  duplizieren, sondern können einen Pivot-Offset definieren

Bewusst NICHT in v1:

- AnimatedSprite2D-State-Machine (Idle/Walk/Hit/Death/Attack-Dispatch)
- Sprite-Scaling über Def
- Shader-Effekte (Hit-Flash, Death-Dissolve)
- Skeletal-Rigging / Bone-Animation

## 2. Optionen

### Option A — `visual_scene: PackedScene` auf Def (empfohlen)

```gdscript
class EnemyDef:
    @export var visual_scene: PackedScene  # optional, null = ColorRect-Mode
```

Im Mob:

```gdscript
func _apply_visuals(def: EnemyDef) -> void:
    if def.visual_scene != null:
        _instantiate_visual_scene(def.visual_scene)
        body.visible = false
    else:
        body.color = def.body_color
        body.size = def.body_size
```

**Pro**
- Mods können eigene Scenes einhängen, ohne Code zu schreiben
  (PackedScene-Reference im .tres reicht)
- Vollständig data-driven
- ColorRect bleibt der no-asset-Default

**Contra**
- 2 Code-Pfade in `_apply_visuals` (testbar, aber Code-Duplikation)

### Option B — Hardcoded if-Branch pro Enemy-ID

```gdscript
match def.id:
    &"raptor_grunt": instance(load("res://visual/raptor.tscn"))
    _:               body.color = def.body_color
```

**Pro**
- Einfacher zu lesen am Anfang

**Contra**
- Skaliert nicht — bei 50 Enemies + Mods entsteht ein riesiges match
- Modder müssten Core-Code patchen
- Nicht data-driven

### Option C — Eigener `visual_provider`-Component

Statt einer PackedScene auf der Def → eine VisualProvider-Resource,
die selbst eine Scene erzeugt.

**Pro**
- Erweiterbar für komplexe Visual-Logik (Color-Tinting, Procedural-Gen)

**Contra**
- Overengineered für v1 — Defs müssten doppelt referenzieren
- AnimatedSprite2D-Provider wäre 90% aller Cases — unnötiger Indirection-Layer

## 3. Empfehlung

**Option A** — `visual_scene: PackedScene` auf jeder Def.

**Begründung**
- Decken den 90%-Workflow ab (Sprite oder ColorRect)
- Modder bekommen die einfachst-mögliche Surface (PackedScene-Ref im .tres)
- Provider-Layer (Option C) bleibt offen, falls AnimatedSprite2D-Provider
  später Ergänzungen wie Tinting brauchen — aber das ist ein eigenes ADR
- ColorRect-Pfad bleibt erhalten → keine Test-Migration

**Schema-Erweiterungen**

```gdscript
# EnemyDef extends ContentItem
@export var visual_scene: PackedScene  # optional
@export var visual_pivot_offset: Vector2 = Vector2.ZERO  # für HealthBar-Anchor

# DinoDef extends ContentItem
@export var visual_scene: PackedScene
@export var visual_pivot_offset: Vector2 = Vector2.ZERO

# BossDef extends ContentItem
@export var visual_scene: PackedScene
@export var visual_pivot_offset: Vector2 = Vector2.ZERO
```

**Mob-Apply-Logik**

```gdscript
func _apply_visuals(def: EnemyDef) -> void:
    # body ist der vorhandene ColorRect (centered, set in scene)
    if def.visual_scene != null:
        _spawn_visual(def.visual_scene)
        if body != null: body.visible = false
        if health_bar != null: health_bar.position = -body.size * 0.5 + Vector2(0, -2) + def.visual_pivot_offset
        return
    # Fallback: ColorRect
    if body != null:
        body.color = def.body_color
        body.size = def.body_size
        body.position = -def.body_size * 0.5
        body.visible = true
    if health_bar != null:
        health_bar.position = Vector2(-def.body_size.x * 0.5, -def.body_size.y * 0.5 - 8)


func _spawn_visual(scene: PackedScene) -> void:
    var inst := scene.instantiate()
    if inst is Node:
        add_child(inst)
        # Sprite ist üblich Node2D — falls Node2D, kann es bei (0,0) bleiben
```

**Test-Strategie**

Beide Pfade werden getestet:
- `visual_scene = null` → ColorRect-Modus (existing tests laufen weiter)
- `visual_scene = preload(test_visual_stub.tscn)` → Scene wird hinzugefügt,
  ColorRect ist hidden

Test-Asset: `tests/fixtures/visual_stub.tscn` (Node2D mit ColorRect-Child),
deutlich genug, dass Tests die Instanz erkennen können.

## 4. Konsequenzen

**Positiv**
- **Sprite-Migration ist mechanisch**: Resource-Reference im .tres
  setzen, keine Code-Änderungen
- **ColorRect bleibt der no-asset-Modus** für noch nicht fertige Mobs
- **Modder können eigene Sprites einhängen** ohne Core-Patch
- Tests bleiben grün (additive API)

**Negativ**
- 2 Code-Pfade in `_apply_visuals` pro Mob-Typ → mehr Tests nötig
- HealthBar-Position-Berechnung muss beide Modi sauber bedienen

**Risiken**
- **Risiko:** Sprite-Scene hat keinen klaren Pivot, HealthBar driftet weg.
  → **Mitigation:** `visual_pivot_offset` per Def überschreibbar +
  Convention-Doc in CONTENT.md, dass Sprite-Wurzel auf (0,0) zentriert
  sein soll.

- **Risiko:** AnimatedSprite2D braucht später eigene API (play(),
  state-machine).
  → **Akzeptiert v1**: kein StateMachine-Dispatch in v1. Folge-ADR
  klärt Animation-Dispatch (z.B. EventBus.player_damaged → Sprite
  feuert "hit"-Animation).

## 5. Betroffene Dateien

Berührt:
- `core/content/enemy_def.gd` (+visual_scene, +visual_pivot_offset)
- `core/content/dino_def.gd` (+visual_scene, +visual_pivot_offset)
- `core/content/boss_def.gd` (+visual_scene, +visual_pivot_offset)
- `core/enemy/enemy_mob.gd` (`_apply_visuals` + `_spawn_visual`)
- `core/player/player_character.gd` (analog)
- `core/boss/boss_mob.gd` (analog)
- `tests/unit/test_enemy_mob.gd` (+Visual-Provider-Tests)
- `tests/unit/test_player_character.gd`
- `tests/unit/test_boss_mob.gd`
- `tests/fixtures/visual_stub.tscn` — Test-Helper-Scene

Anzulegen:
- `tests/unit/test_visual_provider.gd` — fokussierte Visual-Provider-Tests

## 6. Folge-Entscheidungen (Backlog)

- ADR — AnimatedSprite2D-State-Machine (Idle/Walk/Hit/Death-Dispatch)
- ADR — Sprite-Tinting für Variants (statt ColorRect.color → Modulate)
- ADR — Hit-Flash-Shader (white-flash für 100ms bei damage_taken)
- ADR — Sprite-Layering (z-index pro Mob-Type)
