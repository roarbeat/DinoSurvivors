# ADR 0018 – Visueller Stub + HP-Bar

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), shader-fx-specialist (konsultiert)
- Betrifft Prinzipien: #7 testbar
- Voraussetzungen: ADR 0007 (HealthComponent), ADR 0008 (Player), ADR 0009 (Enemy)
- Wird vorausgesetzt von: Sprites + Animations (eigenes ADR), HUD (eigenes ADR)

---

## 1. Kontext

Das Spiel ist seit ADR 0017 spielbar — aber unsichtbar. F5 zeigt eine
leere Bühne mit Logik dahinter. Mit minimalem Aufwand wollen wir es
**sichtbar bedeutungsvoll** machen:

- Player als gelber Quadrat
- Enemies als rote Quadrate
- HP-Bar über jedem Body, die in Echtzeit auf Damage reagiert

Anforderungen v1:

- **ColorRect-Stubs** statt Sprites (Sprites kommen mit eigenem ADR)
- **Eine HealthBar-Klasse**, die für Player und Enemy gleich funktioniert
- **Reaktion auf HealthComponent-Signals** (damage_taken, healed, died)
- **Headless-testbar**: `get_displayed_pct()` als Test-Hook
- **Kein Bus-Aufruf**: HP-Bar listened lokal an einer HealthComponent —
  pro Mob ihre eigene Bar

Bewusst NICHT in v1:

- Animierte Bars (Lerp, Tween)
- Damage-Number-VFX (eigenes ADR 0012)
- Sprites / Animations
- Sub-Bar-Mechaniken (Shield-Layer, Armor-Anzeige)

## 2. Optionen

### Option A — HealthBar als eigene Scene + Klasse (empfohlen)

```
HealthBar (Node2D, root)
├── Background  (ColorRect, dunkelgrau, 30×4)
└── Foreground  (ColorRect, grün/rot, BAR_WIDTH × pct)

class_name HealthBar
func set_health(hp: HealthComponent) -> void
func get_displayed_pct() -> float
```

PlayerCharacter und EnemyMob bekommen jeweils ein `HealthBar`-Child,
das im Script-`_ready` mit der eigenen HealthComponent verbunden wird.

**Pro**
- DRY: ein Code-Pfad, zwei Konsumenten
- Wiederverwendbar für Boss-Bars (anderes Layout, gleicher Hook)
- Test-friendly: HealthBar isoliert testbar mit Mock-HealthComponent

**Contra**
- Eine Scene mehr im Repo

### Option B — HP-Bar inline in Player und Enemy

Direkt im Script ColorRect zeichnen.

**Pro**
- Weniger Files

**Contra**
- Code-Duplikation
- Visuelles Tweaking braucht zwei Stellen

### Option C — Custom-Drawing via _draw()

`_draw()` + `queue_redraw()` bei Damage.

**Pro**
- Kein ColorRect-Boilerplate

**Contra**
- _draw() ist schwerer testbar
- Bei vielen Mobs ineffizient (jeder Frame _draw)

## 3. Empfehlung

**Option A** — HealthBar als eigene Scene + Klasse.

**Begründung**
- Konsistent mit Component-Pattern (ADR 0007)
- Boss-Bars werden nur Layout ändern, Logik bleibt
- Tests können HealthBar mit synthetischer HealthComponent füttern

**Visual-Spec**

| Element | Player | Enemy |
|---------|--------|-------|
| Body-Größe | 24×24 px | 16×16 px |
| Body-Farbe | gelb (`#FFD000`) | rot (`#D03030`) |
| HP-Bar-Width | 30 | 20 |
| HP-Bar-Height | 4 | 3 |
| HP-Bar-Y-Offset | -20 | -14 |
| HP-Bar-BG-Farbe | `#202020` | `#202020` |
| HP-Bar-FG-Farbe | grün → rot per pct (für Player optional, v1 grün) | rot konstant |

**HealthBar-API**

```gdscript
class_name HealthBar extends Node2D

@export var bar_width: float = 30.0
@export var bar_height: float = 4.0
@export var fg_color: Color = Color.GREEN

func set_health(hp: HealthComponent) -> void   # connectet alle Signals
func get_displayed_pct() -> float              # für Tests
```

**Lifecycle**

1. `set_health(hp)`:
   - Disconnect ggf. vorigen HealthComponent
   - Connect `damage_taken`, `healed`, `died`
   - Initial `_update_visual()`
2. Bei `damage_taken` / `healed`: `_update_visual()`
3. Bei `died`: `visible = false`

## 4. Konsequenzen

**Positiv**
- **F5 ist endlich sichtbar bedeutungsvoll**: Player läuft als gelbes
  Quadrat, Raptoren als rote Quadrate, HP-Bars schrumpfen bei Hits
- HealthBar wiederverwendbar für Boss-UI

**Negativ**
- ColorRects sind hässlich — Sprites kommen mit eigenem ADR.
  Akzeptiert für v1 — Performance-fokussiert.

**Risiken**
- **Risiko:** ColorRect ist Control, normalerweise im UI-Layer. Auf einem
  Node2D-Mob ist die Render-Reihenfolge implizit z.
  → **Mitigation:** Tests rendern nicht; im Editor ist Reihenfolge gut sichtbar.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/ui/health_bar.gd` + `.tscn`
- `tests/unit/test_health_bar.gd`

Berührt:
- `core/player/player_character.tscn` + `.gd` (Body + HealthBar Children)
- `core/enemy/enemy_mob.tscn` + `.gd` (Body + HealthBar Children)

## 6. Folge-Entscheidungen (Backlog)

- ADR — Sprites + Animations (Sprite-Frames pro Dino, Enemy-Variants)
- ADR — Damage-Number-VFX (ADR 0012)
- ADR — HUD (HP-Bar im Screen-Space)
