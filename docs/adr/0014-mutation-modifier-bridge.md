# ADR 0014 – Mutation→Modifier-Bridge

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), game-designer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #5 Mod-freundlich, #7 testbar
- Voraussetzungen: ADR 0003 (ContentLoader), ADR 0007 (Combat), ADR 0010 (Modifier)
- Wird vorausgesetzt von: Player-Mutation-System (ADR Backlog)

---

## 1. Kontext

`MutationDef.stat_modifiers` ist ein `Dictionary[StringName, float]` —
deklarative Daten ohne Bedeutung im Code. ADR 0010 hat eine
Modifier-Pipeline geliefert, aber **nichts verbindet die zwei Welten**.

Was fehlt: eine **Bridge**, die aus `triceratops_horns.stat_modifiers =
{ damage_pct: 0.15, melee_range_pct: 0.10 }` eine konkrete Liste von
`DamageModifier`-Resourcen erzeugt — plus eine Liste von Stats, die
keine Combat-Modifier sind und vom Player-System gehandhabt werden müssen
(Player-Stats wie move_speed, max_health, pickup_radius).

Anforderungen v1:

- **Statisch + Pure Function** — `MutationModifierBridge.build(mut_def)`
  gibt deterministisch ein Result zurück, kein State, keine Side-Effects
- **Klar definiertes Mapping** — pro stat_key entweder Combat-Modifier
  oder Player-Stat (oder unbekannt → unhandled)
- **Kein Aggregations-Logik** — eine Mutation → eine Liste Modifier.
  Über mehrere Mutationen aggregieren ist Sache des Player-Mutation-Systems
  (eigenes ADR)
- **Mod-erweiterbar** — Mods dürfen neue stat_keys einführen; die Bridge
  sammelt Unbekanntes in `unhandled` statt zu fehlen

## 2. Optionen

### Option A — Statische Bridge-Klasse mit Mapping-Tabellen (empfohlen)

```gdscript
class_name MutationModifierBridge

const KNOWN_OUTGOING := [&"damage_pct", &"crit_chance", &"crit_damage_pct"]
const KNOWN_INCOMING := [&"armor_pct"]

static func build(mut: MutationDef) -> Dictionary:
    return {
        "outgoing": [...],
        "incoming": [...],
        "unhandled": {...}
    }
```

**Pro**
- Klein, klar, headless-testbar
- Pure Function — Tests sind trivial deterministisch
- Mod-Authoren sehen die Liste der bekannten Stats explizit

**Contra**
- Erweiterung erfordert Code-Edit (kein dyn. Plugin-Hook in v1)
- Mod-eigene Modifier-Klassen können nicht über die Bridge eingehängt
  werden (Mods müssen ihre Modifier dem Player direkt anhängen — das ist
  in Phase 1 OK, eigener ADR später)

### Option B — Modifier-Definition als eigene Resource

`MutationDef` bekommt ein zusätzliches `outgoing_modifiers: Array[DamageModifier]`,
content-author legt direkt Modifier-Resourcen an.

**Pro**
- Maximale Flexibilität — beliebige Modifier-Kombinationen
- Komplette Mod-Symmetrie

**Contra**
- BALANCE-Sheet wird unhandlich (jede Mutation hat einen Modifier-Sub-Tree)
- Doppelte Datenquelle — `stat_modifiers` UND Modifier-Liste
- ID-Stabilität schwerer (Modifier-Sub-Resourcen brauchen eigene UID-Disziplin)

### Option C — Dictionary-basiertes Mapping per Manifest

`config/mutation_stat_mapping.json` mit „damage_pct → MultiplierModifier(1+v)".

**Pro**
- Mods können Mapping ohne Code ändern

**Contra**
- Reflection-basierte Klassen-Instanziierung in GDScript ist holprig
- Validation in Tests aufwändiger
- Verfehlt das v1-Prinzip „klein und klar"

## 3. Empfehlung

**Option A** — statische Bridge-Klasse.

**Begründung**
- Konsistent mit ADR 0010 (Modifier sind Resources, Bridge ist Logik)
- Pure Function → 100% Test-Abdeckung möglich
- Kann später um dyn. Mapping (Option C) erweitert werden, ohne API-Bruch

**Mapping-Konvention (v1)**

| stat_key | Modifier | Argumentation |
|----------|----------|---------------|
| `damage_pct` | `MultiplierModifier(multiplier = 1.0 + v)` outgoing | Damage-Increase wirkt am Dealer |
| `crit_chance` | `CritModifier(chance = v, multiplier = 2.0 + crit_dmg_pct)` outgoing | Crit-Bündelung mit ggf. damage-pct |
| `crit_damage_pct` | siehe oben — wird in CritModifier gebündelt | nur sinnvoll mit crit_chance |
| `armor_pct` | `ArmorModifier(reduction_pct = v)` incoming | Defensive |

Alle anderen stat_keys (z.B. `move_speed_pct`, `max_health_pct`,
`pickup_radius_pct`, `melee_range_pct`) werden als **unhandled**
zurückgegeben — das Player-System wird sie später interpretieren.

**Edge-Cases**

- `crit_damage_pct` ohne `crit_chance`: NICHT als Modifier, sondern in
  unhandled (Crit-Schaden ohne Crit-Chance ist sinnlos)
- `damage_pct = 0.0` oder negativ: kein Modifier (kein 1×-Modifier-Spam)
- Bridge auf `null`-Mut: leeres Result, kein Crash
- Bridge auf Mutation OHNE stat_modifiers: leeres Result

**Result-Schema**

```gdscript
{
    "outgoing": Array[DamageModifier],
    "incoming": Array[DamageModifier],
    "unhandled": Dictionary[StringName, float]
}
```

Bewusst Dictionary statt eigenem Resource-Typ — Resource wäre Overkill
für ein One-Shot-Result, das nur durchgereicht wird.

## 4. Konsequenzen

**Positiv**
- triceratops_horns.tres ist ab jetzt **mathematisch wirksam**
- BALANCE.csv-Werte fließen direkt in die Combat-Math ein
- Player-System hat einen klaren Touchpoint: Bridge.build aufrufen,
  outgoing + incoming an Komponenten hängen, unhandled selber verarbeiten

**Negativ**
- Mapping-Tabelle ist Code (KNOWN_OUTGOING-Konstante). Neue stat_keys
  brauchen Code-Change + neuen Test.
- Mod-eigene stat_keys landen still in unhandled — das ist by design,
  aber Modder müssen das wissen.

**Risiken**
- **Risiko:** Mutation hat damage_pct=0.0 als „No-Op-Marker" — der wird
  vom v1 weggefiltert.
  → **Akzeptiert:** Mutation-Definitionen sollten keine 0-Stats haben;
  content-author achtet darauf.
- **Risiko:** crit_chance + crit_damage_pct kombiniert zu einem
  Modifier — bei mehreren Mutationen mit beiden Feldern fehlt
  Aggregations-Semantik.
  → **Mitigation:** Bridge ist per-Mutation, Aggregation passiert im
  Player-Mutation-System (separates ADR).

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/combat/mutation_modifier_bridge.gd`   Bridge-Klasse
- `tests/unit/test_mutation_modifier_bridge.gd`  gut-Tests

Berührt später:
- Player-Mutation-System: ruft `Bridge.build` und integriert Result
- mod-api-curator: KNOWN_OUTGOING / KNOWN_INCOMING sind Public-API
- naming-conventions.md: Liste der bekannten stat_keys aktualisieren

## 6. Folge-Entscheidungen (Backlog)

- ADR — Player-Mutation-System (Sammelt Modifier über pickup, Aggregation)
- ADR — Plugin-Hook für Mod-eigene stat_keys
- ADR — DamageDealer-Tags (z.B. damage_type-spezifische Modifier)
