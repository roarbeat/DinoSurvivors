# ADR 0022 – Rarity-gewichtete Mutation-Picks

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), game-designer (konsultiert)
- Betrifft Prinzipien: #7 testbar
- Voraussetzungen: ADR 0021 (Mutation-Pick-Phase), ADR 0014 (Mutation-Bridge)
- Wird vorausgesetzt von: Reroll-Mechanik (eigenes ADR), Currency-System

---

## 1. Kontext

Pick-Phase wählt aktuell **uniform zufällig** aus allen verfügbaren
Mutationen (ADR 0021 §3). Mit 7 Mutationen — 4 Common, 3 Rare, 0 Epic,
0 Legendary — ist das jetzt schon problematisch: ein Rare ist 3/7 wahrscheinlich
zu sehen statt der gewünschten 25%.

Anforderungen v1:

- **Rarity-gewichtete Auswahl** mit Standard-Survivor-likes-Verteilung:
  - Common: 70%
  - Rare: 25%
  - Epic: 4.5%
  - Legendary: 0.5%
- **Without-Replacement**: ein Pick erscheint nicht zweimal in derselben
  Auswahl
- **Headless-testbar** mit RNG-Seed-Override (analog zu CritModifier
  in ADR 0010)
- **Robust gegen leere Pools**: wenn keine Mutation einer Rarity
  verfügbar ist, fällt das Gewicht auf 0 → andere Rarities bekommen
  proportional mehr

Bewusst NICHT in v1:

- Player-Stat-Modifier auf Pick-Chancen (z.B. „+10% Rare-Chance
  als Mutation-Effekt")
- Reroll gegen Currency
- Pity-Timer (Garantierter Epic nach N Picks)
- Boss-Wave-Pick-Boost (z.B. „nach Boss garantiert ein Rare+")

## 2. Optionen

### Option A — Weighted-Random im Pick-Overlay (empfohlen)

```gdscript
const RARITY_WEIGHTS: Dictionary = {
    &"common": 70.0,
    &"rare": 25.0,
    &"epic": 4.5,
    &"legendary": 0.5,
}

# Pro Pick:
var weight_sum := 0.0
for mut in available:
    weight_sum += RARITY_WEIGHTS.get(mut.rarity, 1.0)
var roll := _rng.randf() * weight_sum
var cumulative := 0.0
for mut in available:
    cumulative += RARITY_WEIGHTS.get(mut.rarity, 1.0)
    if roll <= cumulative:
        return mut
```

**Pro**
- Klein, headless-testbar
- Konsistent mit Crit-RNG-Pattern (ADR 0010)
- Modder können RARITY_WEIGHTS-Dictionary überschreiben

**Contra**
- Erfordert RNG-Override-Hook für Tests (analog zu CritModifier)

### Option B — Pre-Computed Pool nach Rarity

Pool nach Rarity vorab gruppieren, separat aus jeder Gruppe samplen.

**Pro**
- Eindeutiger pro Rarity

**Contra**
- Komplizierter bei < count verfügbaren
- Parameter-Drift: was wenn ein Rare nicht verfügbar ist? Weniger Picks?
  Andere Rarity? Logik wird verzweigter.

### Option C — Tier-System mit garantierten Slots

Slot 1 = Common, Slot 2 = Rare-or-better, Slot 3 = Epic-or-better.

**Pro**
- Spieler weiß: hier ist immer ein Rare oder besser

**Contra**
- Nicht klassischer Survivor-likes-Loop (Standard ist independent rolls)
- Schwer mit aktuell wenigen Mutationen pro Rarity zu balancieren

## 3. Empfehlung

**Option A** — Weighted-Random, RNG-Override für Tests.

**Begründung**
- Klein, minimaler Code-Change
- Gleiche RNG-Strategie wie CritModifier (ADR 0010) — Konsistenz
- Edge-Cases (kein Rare verfügbar) lösen sich von selbst:
  Weight = 0 → Rarity wird übersprungen

**Implementation-Sketch**

```gdscript
class_name MutationPickOverlay extends CanvasLayer

const RARITY_WEIGHTS: Dictionary = {
    &"common": 70.0, &"rare": 25.0, &"epic": 4.5, &"legendary": 0.5,
}
const FALLBACK_WEIGHT: float = 1.0   # für unbekannte Rarities

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func set_rng(rng: RandomNumberGenerator) -> void:
    _rng = rng

func _pick_random_mutations(count: int) -> Array[StringName]:
    var available: Array[MutationDef] = _collect_available()
    var picks: Array[StringName] = []
    for i in count:
        if available.is_empty():
            break
        var chosen := _weighted_pick_one(available)
        if chosen == null:
            break
        picks.append(chosen.id)
        available.erase(chosen)
    return picks

func _weighted_pick_one(pool: Array) -> MutationDef:
    var weight_sum := 0.0
    for m in pool:
        weight_sum += RARITY_WEIGHTS.get(m.rarity, FALLBACK_WEIGHT)
    if weight_sum <= 0.0:
        return null
    var roll := _rng.randf() * weight_sum
    var cumulative := 0.0
    for m in pool:
        cumulative += RARITY_WEIGHTS.get(m.rarity, FALLBACK_WEIGHT)
        if roll <= cumulative:
            return m
    return pool[-1]  # Floating-Point-Rounding-Schutz
```

**Test-Strategie**

- **Edge-Cases ohne RNG**: Pool mit nur Common → 100% Common,
  Pool leer → leeres Result, Pool mit < count → max-verfügbar
- **Determinismus mit Seed**: zweimal mit gleichem Seed → identische Picks
- **Verteilungs-Sanity**: 1000 Picks mit gleichmäßigem Pool → Common
  ~700×, Rare ~250×, ±5% Toleranz (statistisch)

## 4. Konsequenzen

**Positiv**
- **Strategische Pick-Phase**: Spieler erlebt seltene Mutationen
  als „big moment", Common-Picks sind häufig aber sinnvoll
- Konsistent mit Survivor-likes-Standard

**Negativ**
- Mit 0 Epic/Legendary in v1 sind 4.5/0.5% theoretisch — der Effekt
  zeigt sich erst mit erweitertem Pool. Akzeptabel: Math ist
  schon richtig, Content folgt.

**Risiken**
- **Risiko:** RARITY_WEIGHTS sind Code-Konstanten. Modder können sie
  nicht ohne Code-Change überschreiben.
  → **Mitigation v1**: const-Dictionary ist Public-API. Mods, die das
  ändern wollen, schreiben (vorerst) einen kleinen Patch oder warten
  auf eigenes Mod-Hook-ADR.

## 5. Betroffene Dateien & Systeme

Anzulegen / erweitern:
- `core/ui/mutation_pick_overlay.gd`              +Weighting + RNG-Override
- `tests/unit/test_mutation_pick_overlay.gd`      +Weighting-Tests

Berührt nicht:
- WaveSpawner, RunScene, andere Combat-Files

## 6. Folge-Entscheidungen (Backlog)

- ADR — Reroll-Mechanik mit Currency-Cost
- ADR — Pity-Timer (garantiertes Rare nach N Picks)
- ADR — Player-Stat-Modifiers für Pick-Chance (z.B. „Glück" als Stat)
- ADR — Mod-Hook für RARITY_WEIGHTS-Override
