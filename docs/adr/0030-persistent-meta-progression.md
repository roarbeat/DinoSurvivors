# ADR 0030 – Persistente Meta-Progression

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer + game-designer + save-migration-specialist (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #2 EventBus, #3 Save-versioned, #5 Mod-friendly, #7 testbar
- Voraussetzungen: ADR 0001 (EventBus), ADR 0002 (SaveSystem), ADR 0023 (BossDef.reward_currency_amount), ADR 0025 (Boss-Spawn)
- Wird vorausgesetzt von: ADR — Meta-Shop (Bernstein gegen permanente Upgrades), ADR — Mehrere Currency-Typen

---

## 1. Kontext

Die ganze Pipeline ist auf Meta-Progression vorbereitet:

- `EventBus.currency_changed(currency: StringName, new_value: int)` existiert
  seit ADR 0001
- `BossDef.reward_currency_amount` existiert seit ADR 0023
- `SaveSystem` existiert seit ADR 0002 mit JSON-Persistenz und Schema-
  Migrations
- `EventBus.boss_defeated` feuert beim Boss-Tod

Aber **niemand verbindet die Punkte**. Boss-Defeat zahlt heute nichts
aus, kein Run-übergreifender Bernstein-Counter, Save-File enthält keine
Currency.

Anforderungen v1:

- **MetaProgression-Autoload** als zentraler Bernstein-Tracker
- **Auto-Reward bei boss_defeated**: BossDef.reward_currency_amount wird
  zu Bernstein addiert
- **Save/Load-Integration**: Bernstein wird im Save-File persistiert
- **Public-API für UI/Mods**: get_currency, add_currency, set_currency,
  list_currencies
- **EventBus-Driven**: kein direkter Aufruf von
  `MetaProgression.add_currency()` aus Game-Code — alles geht über Bus

Bewusst NICHT in v1:

- **Meta-Shop-UI** (Bernstein gegen permanente Upgrades)
- **Multiple Currency-Typen** (v1: nur Bernstein, Schema unterstützt
  mehrere — aber Game füllt nur einen)
- **Currency-Cap** (Max-Bernstein? In v1: kein Limit)
- **Currency-Drops von Enemies** (nicht nur Bossen) — eigenes ADR
- **Currency-Pickups als World-Items** (Coin-Sprites einsammeln) —
  eigenes ADR
- **Save-Manifest-Hash-Validation** (Mods können Currency-IDs
  registrieren, aber wir prüfen das nicht in v1)

## 2. Optionen

### Option A — MetaProgression als 9. Autoload, Dictionary-basiert (empfohlen)

```gdscript
# core/meta_progression.gd extends Node

const DEFAULT_CURRENCY: StringName = &"amber"

var _currencies: Dictionary = { &"amber": 0 }

func _ready():
    EventBus.boss_defeated.connect(_on_boss_defeated)
    EventBus.save_loaded.connect(_on_save_loaded)
    # Save-Trigger: bei jeder Currency-Änderung speichern wir nicht
    # automatisch — Game-Code feuert save_requested wenn nötig.

func get_currency(id: StringName = DEFAULT_CURRENCY) -> int
func add_currency(id: StringName, amount: int) -> void
func set_currency(id: StringName, value: int) -> void
func list_currencies() -> Dictionary

func _on_boss_defeated(boss_id, _run_time):
    var def := ContentLoader.get_or_null(&"boss", boss_id) as BossDef
    if def != null and def.reward_currency_amount > 0:
        add_currency(DEFAULT_CURRENCY, def.reward_currency_amount)
```

**Pro**
- Leichtgewichtig — Dictionary mit StringName-Keys ist Godot-idiomatisch
- Erweiterbar für Mods (eigene Currency-Keys)
- EventBus-driven, keine direkten Calls aus Game-Code

**Contra**
- Currency-IDs sind nirgends formal registriert — Tipp-Fehler in
  StringName fallen erst auf, wenn Save-File mehrere Keys hat
  (akzeptabel v1, eigenes ADR für Currency-Registry)

### Option B — Currency als ContentLoader-Type

`content/currencies/amber.tres` mit display_name_key, icon_scene, etc.

**Pro**
- Vollständig data-driven, Mod-tauglich
- UI-Code kann Icon + Name aus der Resource lesen

**Contra**
- Overengineered für v1 (nur 1 Currency)
- Wenn Currency-IDs in Code als StringName-Konstanten verwendet werden,
  muss die Resource trotzdem ID-Match prüfen

### Option C — RunState hält Currency als Field

Bernstein im RunState statt als Autoload.

**Pro**
- Weniger Autoloads

**Contra**
- RunState ist per-Run-State, Currency ist Run-übergreifend
- Mischt zwei Konzepte (Lifecycle vs. Persistenz)

## 3. Empfehlung

**Option A** — MetaProgression-Autoload, Dictionary-basiert.

**Begründung**
- Konsistent mit anderen Autoloads (PlayerMutations, RunState, …)
- Mods können eigene Currency-Keys ergänzen ohne Resource-Registry
- v1 hat genau 1 Currency (`amber`) — wenn mehr Currencies kommen,
  wird Currency-Registry-ADR geschrieben
- Save-Schema bleibt minimal (Dictionary serialize → JSON)

### Public-API

```gdscript
const DEFAULT_CURRENCY: StringName = &"amber"

## Liefert den aktuellen Wert einer Currency. 0 wenn unbekannt.
func get_currency(id: StringName = DEFAULT_CURRENCY) -> int

## Erhöht eine Currency um amount. Negative amounts sind erlaubt
## (= subtract). Feuert EventBus.currency_changed.
## Lower-cap bei 0 (keine negativen Currency-Werte).
func add_currency(id: StringName, amount: int) -> int  # Rückgabe = neuer Wert

## Setzt eine Currency direkt. Für Save-Load und Cheats.
## Feuert EventBus.currency_changed nur wenn Wert sich ändert.
func set_currency(id: StringName, value: int) -> void

## Liefert flat Dictionary {id: value} aller bekannten Currencies.
func list_currencies() -> Dictionary

## Reset auf Default-State. Wird vom Test-Code genutzt, NICHT vom
## Game-Code. Mod-API exponiert das nicht.
func _reset_for_test() -> void
```

### Auto-Reward auf boss_defeated

```gdscript
func _on_boss_defeated(boss_id: StringName, _run_time: float) -> void:
    var def := ContentLoader.get_or_null(&"boss", boss_id) as BossDef
    if def == null:
        return
    if def.reward_currency_amount > 0:
        add_currency(DEFAULT_CURRENCY, def.reward_currency_amount)
```

### Save-Integration

SaveSystem v1 hat `data: Dictionary` als generischen Container. Wir
schreiben Currency unter `&"meta_progression"`-Key:

```gdscript
# Save: MetaProgression hört NICHT auf save_requested — der SaveSystem
# liest die Currency vor dem Schreiben über einen "Provider"-Hook.
# Variante v1: MetaProgression registriert sich beim SaveSystem.
SaveSystem.register_provider(&"meta_progression", func(): return _currencies.duplicate())

# Load: SaveSystem feuert save_loaded, MetaProgression liest sich raus.
func _on_save_loaded(_version: int) -> void:
    var data := SaveSystem.get_data().get(&"meta_progression", {})
    for key in data.keys():
        _currencies[key] = int(data[key])
```

Tatsächlich: SaveSystem.set_field(&"meta_progression", _currencies) am
Ende jedes Runs (oder bei manuellen Save-Triggern). Provider-Pattern ist
für später (eigenes ADR).

### Schema-Migration

Save-Schema-v1 hatte `data: {}`. v0.1.0 fügt `data.meta_progression: {}`
hinzu — das ist additiv, **kein Schema-Bruch**, keine Migration-File
nötig. Saves vor v0.1.0 haben keinen `meta_progression`-Key →
MetaProgression startet mit Default-State (amber=0).

Doku-Update: `agents/memory/save-migration-specialist/save-schema-history.md`
bekommt einen v1.1-Eintrag (additive Felder).

## 4. Konsequenzen

**Positiv**
- **Boss-Defeat zahlt sich aus**: Spieler sieht Bernstein-Zähler steigen
- **Run-übergreifender Progress**: motiviert Wiederholungen
- **Foundation für Meta-Shop**: Bernstein ist die Currency, die im
  zukünftigen Shop ausgegeben wird (eigenes ADR)
- **Backward-Kompat**: Saves vor v0.1.0 lesen sauber mit amber=0

**Negativ**
- **MetaProgression hat zwei Verantwortlichkeiten**: Currency-Tracking +
  Auto-Reward-Listener. Akzeptiert v1 — bei Bedarf in zwei Klassen
  splitten (CurrencyTracker + RewardDispatcher).

**Risiken**
- **Risiko:** Save wird nicht ausgelöst, Bernstein geht beim Crash verloren.
  → **Mitigation v1:** RunScene feuert `save_requested(&"run_end")` bei
  player_died/boss_defeated/run_ended, sodass Bernstein automatisch
  persistiert wird.

- **Risiko:** Negative add_currency-Aufrufe machen Currency negativ.
  → **Mitigation:** Lower-cap bei 0 — `_currencies[id] = max(0, new_value)`.

## 5. Betroffene Dateien

Anzulegen:
- `core/meta_progression.gd` — Autoload
- `tests/unit/test_meta_progression.gd`

Berührt:
- `project.godot` — `MetaProgression` als 9. Autoload (nach SfxBus)
- `core/run_scene/run.gd` — feuert `save_requested(&"run_end")` bei
  player_died (Bernstein-Persistenz)
- `agents/memory/save-migration-specialist/save-schema-history.md`
  — v1.1-Eintrag (additive `meta_progression`-Section)
- `agents/memory/mod-api-curator/public-api-surface.md` — neue Section
  „MetaProgression-API"

## 6. Folge-Entscheidungen (Backlog)

- ADR — Meta-Shop-UI (Bernstein gegen permanente Upgrades)
- ADR — Currency-Registry (Multiple Currencies, ContentLoader-Type)
- ADR — Currency-Drops von Enemies (Schwarm-Currency, kleinere Beträge)
- ADR — Currency-Pickups als World-Items (Coin-Sprites einsammeln)
- ADR — Save-Provider-Pattern (statt set_field-Push)
