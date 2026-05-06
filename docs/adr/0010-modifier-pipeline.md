# ADR 0010 – Modifier-Pipeline (Crit, Bonus, Multiplier, Armor)

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), game-designer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #2 EventBus, #5 Mod-freundlich, #7 testbar
- Voraussetzungen: ADR 0007 (Combat-Pipeline), ADR 0003 (ContentLoader)
- Wird vorausgesetzt von: Mutation→Effect-Bridge (späteres ADR), Boss-Mechaniken

---

## 1. Kontext

Combat-Pipeline (ADR 0007) hat HealthComponent + DamageDealerComponent +
DamageInfo geliefert. Was fehlt: **die Pipeline, die DamageInfo verändert,
bevor er bei der HealthComponent ankommt** — Crit, Lifesteal, Armor,
Damage-Multipliers.

Anforderungen v1:

- **Modifier als Resources** (kein Code-pro-Effekt) — Mutationen können
  Modifier deklarativ einsetzen, Mods können eigene Subklassen einführen
- **Outgoing-Pipeline** auf DamageDealerComponent — applied bevor das Target
  `take_damage()` sieht
- **Incoming-Pipeline** auf HealthComponent — applied auf eingehende
  DamageInfo bevor HP reduziert wird (für Armor, Damage-Resistance)
- **Deterministische Reihenfolge** — Modifier haben `priority: int`,
  niedrige Priorität läuft zuerst
- **Pure-Function-Konvention** — `apply(info) -> DamageInfo` returns NEUE
  Resource, modifiziert die alte nicht
- **Testbar ohne RNG-Risiko** — Crit-Modifier akzeptiert deterministischen
  RandomNumberGenerator-Override für Unit-Tests

Bewusst NICHT in v1:

- Mutation→Modifier-Bridge (kommt mit eigenem ADR — der definiert, wie
  `triceratops_horns.stat_modifiers["damage_pct"] = 0.15` zu einem
  konkreten Modifier-Resource wird)
- Lifesteal (braucht Source-Health-Reference, mehr als reine DamageInfo-Modifikation)
- Status-Effekte (DoT, Slow) — eigene Klasse von Effekten

## 2. Optionen

### Option A — Modifier-Resources mit `apply(info) -> DamageInfo` (empfohlen)

Pro Effekt eine Resource-Subklasse von `DamageModifier`. Modifier-Liste
ist auf Komponenten als `Array[DamageModifier]` exposed, beim Damage-Flow
wird die Liste nach `priority` sortiert und sequenziell angewandt.

**Pro**
- Daten-getrieben (Prinzip #1) — Mutationen sind .tres-Files mit Modifiern
- Pure Functions sind testbar wie ADR-0002-Migrations
- Mods können eigene Modifier-Subklassen einführen
- Reihenfolge ist explizit (priority), nicht Connection-Order-abhängig

**Contra**
- Eine Indirection mehr als „direkt im DamageDealer rumrechnen"

### Option B — Modifier als Callables auf einem Bus

Auf dem `will_deal_damage`-Signal lauschen, info modifizieren.

**Pro**
- Keine neuen Klassen
- Mod-Hook geschenkt

**Contra**
- Reihenfolge unklar (Connection-Order)
- Keine Daten-Repräsentation → Mutationen brauchen weiterhin Code-Glue
- Modifier-Disable/Enable schwierig

### Option C — Stat-Aggregation auf dem Player

Player hat `damage_bonus_pct: float`, alle Mutationen schreiben in dieses
Stat-Bag. DamageInfo wird einfach per `player.damage_bonus_pct`
multipliziert.

**Pro**
- Sehr einfach, sehr performant

**Contra**
- Nur per-Player anwendbar — Boss-Damage-Modifier brauchen wieder eigenen Pfad
- Kein klares Crit-Signal (Crit ist binäres Outcome, nicht Stat-Bag)
- Keine source-spezifische Mod (z.B. „nur Lifesteal von Horn-Mutation")

## 3. Empfehlung

**Option A** — DamageModifier-Resources mit Pure-Function-Apply.

**Begründung**
- Konsistent mit ADR 0003 (Daten-getrieben) und ADR 0002
  (Pure-Function-Migrations als Vorbild)
- Komplett headless-testbar — kein Scene-Setup, kein Spieler-Char nötig
- Mod-API: Modifier-Klassen können von Mods registriert werden
  (analog zu DamageInfo-damage_types — offene Convention)

**Modifier-Hierarchie**

```
Resource
└── DamageModifier (abstract)
    ├── priority: int                         # niedrig zuerst
    ├── apply(info: DamageInfo) -> DamageInfo # pure function
    │
    ├── FlatBonusModifier                     # +N flat
    │   └── bonus_amount: float
    ├── MultiplierModifier                    # ×N
    │   └── multiplier: float
    ├── CritModifier                          # chance + multiplier
    │   ├── chance: float (0..1)
    │   ├── multiplier: float (z.B. 2.0)
    │   └── _rng: RandomNumberGenerator       # Tests dürfen das überschreiben
    └── ArmorModifier (incoming-only)         # reduziert eingehenden Damage
        ├── reduction_pct: float (0..1)
        └── # respektiert info.pierce_armor
```

**Reihenfolge-Konvention (priority)**

| Range | Bedeutung |
|-------|-----------|
| 0..99 | Pre-Calc (Source-Stat-Multiplier) |
| 100..199 | Flat-Boni (FlatBonusModifier) |
| 200..299 | Multiplier (Crit, Damage-%) |
| 300..399 | Defensive (Armor — nur incoming) |
| 400..499 | Post-Calc (Damage-Cap, Min-Damage) |

Default-Priority pro Klasse:
- FlatBonusModifier: 150
- MultiplierModifier: 250
- CritModifier: 250 (gleich wie Multiplier — beide sind ×N, Reihenfolge
  wird durch Insert-Order entschieden bei Tie)
- ArmorModifier: 300

**Modifier-Stack auf Komponenten**

```gdscript
# DamageDealerComponent
@export var outgoing_modifiers: Array[DamageModifier] = []

# HealthComponent
@export var incoming_modifiers: Array[DamageModifier] = []
```

Der DamageDealer sortiert seine Liste einmal beim Hinzufügen via
`add_modifier(m)` (oder beim ersten `deal_damage`-Call) und ruft sie
sequenziell auf.

**Apply-Chain (im DamageDealer.deal_damage)**

```gdscript
var current := info
for mod in _sorted_outgoing:
    current = mod.apply(current)
target.take_damage(current)
```

**Pure-Function-Garantie**

Jeder Modifier MUSS eine Kopie zurückgeben, NIE die übergebene Resource
mutieren. Tests prüfen das via Identity-Check.

**RNG-Determinismus (CritModifier)**

```gdscript
class_name CritModifier extends DamageModifier

@export var chance: float = 0.1
@export var multiplier: float = 2.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func set_rng(rng: RandomNumberGenerator) -> void:
    _rng = rng

func apply(info: DamageInfo) -> DamageInfo:
    if _rng.randf() <= chance:
        return info.with_amount(info.amount * multiplier)._marked_crit()
    return info
```

Tests injizieren ein RNG mit fixed seed.

## 4. Konsequenzen

**Positiv**
- Mutationen werden in eigenem ADR (Backlog) zu Modifier-Sets übersetzt
  — die Math passiert hier, der Rest ist Glue
- Headless-testbar mit deterministischen Edge-Cases (chance=0, chance=1)
- Mod-Authoren können neue Modifier-Subklassen einführen

**Negativ**
- Modifier-Liste auf Komponenten ist Array — bei sehr vielen Modifiers
  (z.B. 50+) ist das O(n²) wegen Sort-on-Insert. Praktisch unkritisch
  (Player hat selten >20 Modifier).
- Pure-Function-Konvention nicht erzwungen — Reviewer muss aufpassen.

**Risiken**
- **Risiko:** Modifier ändert Resource in-place (verletzt Pure-Function).
  → **Mitigation:** Tests auf Identity-Check; godot-implementer-gotchas-Memory
- **Risiko:** Crit-Modifier ohne RNG-Override liefert in Tests
  nicht-deterministische Ergebnisse.
  → **Mitigation:** chance=0 / chance=1 für Edge-Case-Tests, set_rng() für
  Seed-Tests.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/combat/damage_modifier.gd`             Base-Resource (abstract)
- `core/combat/modifiers/flat_bonus_modifier.gd`
- `core/combat/modifiers/multiplier_modifier.gd`
- `core/combat/modifiers/crit_modifier.gd`
- `core/combat/modifiers/armor_modifier.gd`
- `core/combat/damage_info.gd`                 +`is_crit`-Setter via Helper
- `core/components/damage_dealer_component.gd` +`outgoing_modifiers`
- `core/components/health_component.gd`        +`incoming_modifiers`
- 5 Test-Files unter `tests/unit/`

## 6. Folge-Entscheidungen (Backlog)

- ADR — Mutation→Modifier-Bridge (`stat_modifiers` → konkrete Resources)
- ADR — Lifesteal als Source-Side-Effect-Modifier
- ADR — Status-Effekte (DoT, Slow, Stun) — eigene Effect-Klasse, nicht Modifier
