# ADR 0024 – Visuelle Enemy-Differenzierung

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), shader-fx-specialist (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #7 testbar
- Voraussetzungen: ADR 0009 (EnemyMob), ADR 0023 (Enemy-Variants)
- Wird vorausgesetzt von: Sprites-ADR (eigenes), Boss-Spawn-ADR

---

## 1. Kontext

Phase 3 hat 4 Enemy-Typen mit unterschiedlichen Stat-Profilen — visuell
sind sie aber alle identische rote 16×16-Quadrate. Spieler unterscheidet
sie nur über das Verhalten (Speed, HP-Bar-Schrumpfen). Klein, aber
sichtbarer Unterschied wäre für Game-Feel goldwert.

Anforderungen v1:

- **EnemyDef-Felder** für visuelle Variation: `body_color` (Color) und
  `body_size` (Vector2)
- **Daten-getrieben**: Stats und Visuals beide über die EnemyDef-Resource
- **Backward-kompatibel**: alte EnemyDef-Files ohne neue Felder fallen
  auf default-Werte zurück (rot, 16×16)
- **HealthBar-Skalierung**: bei größerem Body wandert die HP-Bar mit
  nach oben (sonst überlappt sie den Body)
- Bewusst **noch keine Sprites** — ColorRect-Variation ist genug für
  Phase-3-Polish. Sprites sind eigenes ADR.

## 2. Optionen

### Option A — body_color + body_size auf EnemyDef (empfohlen)

```gdscript
# EnemyDef:
@export var body_color: Color = Color(0.82, 0.18, 0.18)  # rot default
@export var body_size: Vector2 = Vector2(16, 16)         # default

# EnemyMob.setup(def, pos):
$Body.color = def.body_color
$Body.size = def.body_size
$Body.offset_left = -def.body_size.x / 2
$Body.offset_top = -def.body_size.y / 2
$Body.offset_right = def.body_size.x / 2
$Body.offset_bottom = def.body_size.y / 2
$HealthBar.position.y = -(def.body_size.y / 2) - 8
```

**Pro**
- Daten-getrieben, klein
- Backward-kompatibel — Defaults greifen
- Mod-Authoren können neue Enemies mit eigenem Look ohne Code-Change
- Headless-testbar: setup() setzt Felder direkt

**Contra**
- ColorRect-Variation sieht weiterhin "indie" aus, aber genau das wollen
  wir in v1 — Sprites sind späterer Polish.

### Option B — Sprite-Frames pro EnemyDef

EnemyDef bekommt `texture: Texture2D` Field, EnemyMob hat ein Sprite2D
statt ColorRect.

**Pro**
- Echte visuelle Identität

**Contra**
- Wir haben keine Sprite-Assets in v1
- Sprite-Editor / Asset-Pipeline ist eigenes Thema
- ADR-Größe wächst rapidly (Animation, Frame-Strip-Format, Pivot, …)

### Option C — Procedural Shapes via Polygon2D

Komplexere Formen (Dreieck für Pteranodon, Trapez für Tank …).

**Pro**
- Mehr Charakter ohne Sprites

**Contra**
- Polygon-Daten als Resource-Field unhandy
- Größere Komplexität für minimalen visuellen Gewinn

## 3. Empfehlung

**Option A** — body_color + body_size.

**Begründung**
- Konsistent mit ADR 0018 (HP-Bar als ColorRect)
- Smooth Pfad zu Sprites: später wird body_color/size durch
  texture/sprite_frames ersetzt, EnemyMob bekommt einen weiteren
  Visual-Mode (Sprite oder ColorRect)
- Schnell sichtbarer Polish-Gewinn

**Color-Konvention v1**

| Enemy | Color | Size | Begründung |
|-------|-------|------|------------|
| raptor_grunt | rot `#D03030` | 16×16 | Default — der Standard |
| pteranodon | himmelblau `#5AB8E8` | 14×14 | Flieger = blau, klein = fragil |
| raptor_alpha | dunkelrot `#A02020` | 22×22 | Größer als grunt, dunklere Farbe = stärker |
| armored_carnotaurus | braungrau `#7A6850` | 28×28 | Tank-Größe, Erdton = "armored" |
| tyrannosaurus_prime (Boss-Stub) | dunkelviolett `#3A1850` | 40×40 | Nicht spawnable in v1 |

**HealthBar-Skalierung**

```
hp_bar_y = -(body_size.y / 2) - 8
```

8px Abstand zwischen Body-Oberkante und HP-Bar — visuell konsistent
über alle Größen.

## 4. Konsequenzen

**Positiv**
- **Visueller Hit-Recognition**: Spieler erkennt sofort, welche
  Bedrohung kommt
- Pool-Curve (ADR 0023) wird sichtbar erlebbar
- Mod-Pfad: neue Enemies haben Visual ohne Code

**Negativ**
- ColorRect-Variation ist immer noch ColorRect. Echter Sprite-Polish
  kommt mit eigenem ADR.

**Risiken**
- **Risiko:** Visuell sehr große Bodies (Carnotaurus 28×28) überlappen
  HP-Bar bei kleinen Spawns.
  → **Mitigation:** HealthBar.bar_width skaliert nicht — sie bleibt 20px,
  egal wie groß der Body ist. Optisch akzeptabel.

## 5. Betroffene Dateien & Systeme

Anzulegen / erweitern:
- `core/content/enemy_def.gd` (+body_color, +body_size)
- `core/enemy/enemy_mob.gd` (setup() applied Visuals)
- `content/enemies/*.tres` (3 Files mit neuen Werten)
- `tests/unit/test_enemy_mob.gd` (+Visual-Tests)

Berührt nicht:
- BossDef bekommt das Field nicht in v1 (Boss-Spawn ist eh Backlog)

## 6. Folge-Entscheidungen (Backlog)

- ADR — Sprites + AnimatedSprite2D pro EnemyDef
- ADR — Visual-Customization für DinoDef (Player-Char-Sprites)
- ADR — Polygon-basierte Body-Shapes (statt nur ColorRect)
