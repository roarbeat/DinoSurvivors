# ADR 0008 – Player-Character-Scene + Movement

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), game-designer + godot-implementer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #7 testbar
- Voraussetzungen: ADR 0006 (Run-Lifecycle), ADR 0007 (Combat), ADR 0010 (Modifier), ADR 0015 (PlayerMutations)
- Wird vorausgesetzt von: Hit-Detection (ADR 0011), Enemy-Spawn-System (ADR 0009)

---

## 1. Kontext

Bisher ist die ganze Combat-Math headless-testbar — aber kein Spieler-
Charakter existiert tatsächlich in einer Scene. Es ist Zeit für die erste
**echte Spielszene**: PlayerCharacter, der HealthComponent und
DamageDealerComponent zu einem Tree zusammenhängt, sich auf Eingaben bewegt
und auf gepickte Mutationen reagiert.

Anforderungen v1:

- **CharacterBody2D**-Subklasse `PlayerCharacter` als Player-Char
- **Daten-getrieben**: Stats kommen aus `DinoDef` (max_hp, base_speed,
  base_damage), nicht hardcoded
- **Komponenten anflanschen**: HealthComponent + DamageDealerComponent
  als Children
- **Mutations-Hook**: bei `EventBus.mutations_changed` werden die
  Komponenten-Modifier-Stacks aus `PlayerMutations.get_aggregated()`
  neu aufgebaut
- **Player-Stats-Application**: unhandled-Stats wie `max_health_pct`
  und `move_speed_pct` werden vom Player selbst auf seine Werte
  angewandt (Health = max_health × (1 + max_health_pct))
- **Movement-Logik testbar**: separate `_compute_velocity()`-Methode,
  die aus Input-Vector + base_speed + move_speed_pct den Geschwindigkeits-
  Vektor berechnet
- **Input via InputMap-Actions**: `move_up`, `move_down`, `move_left`,
  `move_right` — testbar via `InputMap`-Manipulation oder
  direkt über `_compute_velocity(Vector2)` ohne Input-System

Bewusst NICHT in v1:

- Animation, Sprite-Visualisierung, Sounds
- Hit-Detection (eigenes ADR 0011)
- Auto-Aim und Auto-Attack-Loop
- Pickup-Radius-Wirksamkeit (kommt mit Pickup-System)

## 2. Optionen

### Option A — CharacterBody2D mit Composition (empfohlen)

```
PlayerCharacter (CharacterBody2D, root)
├── HealthComponent (Node)
└── DamageDealerComponent (Node)
```

Player-Skript instantiiert die Komponenten in `_ready()` (oder sie
werden in der Scene angelegt). Modifier kommen aus PlayerMutations.

**Pro**
- Konsistent mit ADR 0007 (Component-Pattern)
- Movement-Logik kann in `_compute_velocity()` extrahiert werden →
  headless-testbar
- HealthComponent ist schon mit `is_player=true` ausgerüstet
- Stats kommen aus DinoDef → daten-getrieben

**Contra**
- Wenn Komponenten in `_ready()` per Code erstellt werden, sind sie
  in der Scene-Vorschau nicht sichtbar. Lösung: `.tscn` mit den
  Komponenten als Children, Script setzt nur Referenzen.

### Option B — Monolithic Player-Script

Ein Script mit eingebauten HP, Damage usw.

**Pro**
- Einfacher Boot

**Contra**
- Verletzt ADR 0007 (Component-Pattern)
- Nicht wiederverwendbar für Enemies/Bosses
- Tests brauchen den ganzen Scene-Kontext

### Option C — Mehrere Player-Scenes pro Dino

Pro Dino eine eigene `.tscn` (trex.tscn, raptor.tscn …).

**Pro**
- Custom-Visuals pro Dino

**Contra**
- Code-Duplikation für Movement und Combat-Glue
- Skaliert schlecht bei 10+ Dinos
- Kein Datenpfad „neue Mutationen wirken auf alle Dinos gleich"

## 3. Empfehlung

**Option A** — eine generische `PlayerCharacter.tscn` + `.gd`,
DinoDef-Stats werden zur Laufzeit gesetzt.

**Begründung**
- Konsistent mit Component-Pattern (ADR 0007)
- Movement-Logik headless-testbar (via `_compute_velocity()`)
- Skaliert für viele Dinos ohne Scene-Duplikation
- Visuelle Differenzierung kommt später über DinoDef.sprite-Felder
  (Backlog, eigenes ADR), nicht über separate Scenes

**Public-API**

```gdscript
class_name PlayerCharacter extends CharacterBody2D

func set_dino(dino: DinoDef) -> void
   # setzt Stats, baut Komponenten-Initialwerte
func get_dino() -> DinoDef
func get_health_component() -> HealthComponent
func get_dealer_component() -> DamageDealerComponent
func get_effective_max_hp() -> float
func get_effective_speed() -> float
func _compute_velocity(input_vec: Vector2) -> Vector2
   # pure: input_vec normalisiert × effective_speed
```

**Stats-Application**

Bei `set_dino()` und nach `mutations_changed`:
1. `effective_max_hp = dino.max_health × (1 + max_health_pct_unhandled)`
2. `effective_speed = dino.base_speed × (1 + move_speed_pct_unhandled)`
3. `damage_dealer.outgoing_modifiers = aggregated.outgoing`
4. `health.incoming_modifiers = aggregated.incoming`
5. `health.max_hp = effective_max_hp` (HP-Kappe wird ggf. nachjustiert)

**Movement**

```gdscript
func _physics_process(delta: float) -> void:
    var input := Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down"))
    velocity = _compute_velocity(input)
    move_and_slide()

func _compute_velocity(input_vec: Vector2) -> Vector2:
    return input_vec.normalized() * get_effective_speed() if input_vec.length() > 0 else Vector2.ZERO
```

**Input-Actions** (kommen mit project.godot Input-Map-Erweiterung):
`move_up`, `move_down`, `move_left`, `move_right`. Default-Bindings
für Tastatur (WASD + Pfeile) und Gamepad.

## 4. Konsequenzen

**Positiv**
- Erste **sichtbare** Spielszene — alle Math-Pipelines aus ADR 0006-0015
  werden visuell sichtbar
- DinoDef ist daten-getriebener Stats-Anker für alle Charaktere
- Mutations wirken auf Movement und HP, nicht nur auf Damage

**Negativ**
- Movement-Tests sind nicht 100% headless — _physics_process kann
  schwierig zu testen sein. Mitigation: `_compute_velocity()` ist die
  pure Berechnungsfunktion, die unit-testbar ist.

**Risiken**
- **Risiko:** HP wird über max gehoben durch max_health_pct, aber
  current_hp wird nicht angepasst. Spieler heilt unsichtbar.
  → **Akzeptiert:** in v1 setzt set_dino auf full-hp, mutations_changed
  läuft danach und kappt nur den Maximalwert. Wenn current_hp < new_max_hp,
  ist alles fine. Wenn current_hp > new_max_hp (z.B. armor-Mutation
  vom Aggregator entfernt → max_hp sinkt), wird current_hp gekappt.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/player/player_character.gd`        Script
- `core/player/player_character.tscn`      Scene mit Komponenten als Children
- `core/content/dino_def.gd`               (kein Change — character_scene-Field
                                            ist schon da)
- `content/dinos/trex.tres`                +character_scene-Reference
- `project.godot`                          Input-Actions move_*
- `tests/unit/test_player_character.gd`    gut-Tests

Berührt später:
- ADR 0009 — Enemy-Spawn-System (analoges Pattern für EnemyMob)
- ADR 0011 — Hit-Detection (Area2D auf Player)
- ADR 0012 — Damage-Number-VFX (lauscht auf health.damage_taken)

## 6. Folge-Entscheidungen (Backlog)

- ADR — Animations-System (Sprite, Anim-Player)
- ADR — Auto-Aim und Auto-Attack-Loop (Survivor-likes-Standard)
- ADR — Pickup-Radius-Wirksamkeit (XP-Magnet)
