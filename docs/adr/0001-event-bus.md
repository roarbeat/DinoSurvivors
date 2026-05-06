# ADR 0001 – Globaler EventBus als zentrales Nervensystem

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), Haupt-Agent
- Betrifft Prinzipien: #2 Event-Bus, #5 Mod-freundlich, #7 testbare Systeme

---

## 1. Kontext

DinoRogue muss eine Vielzahl voneinander entkoppelter Systeme koordinieren:
Wellen-Spawner, Mutationssystem, Boss-Logik, VFX, UI/HUD, Telemetrie, Save-System,
Achievements, Mod-Hooks. Diese Systeme dürfen sich nicht direkt referenzieren
(sonst entsteht ein Spaghetti-Graph), und sie müssen alleine testbar sein
(Prinzip #7). Außerdem ist der EventBus der zentrale **Public-API-Anker für Mods**
(Prinzip #5) – Modder dürfen Signals subscriben, ohne in den Game-Code zu greifen.

## 2. Optionen

### Option A – Autoload-Singleton mit `signal`-Definitionen (empfohlen)

Eine `EventBus.gd` als Godot-Autoload mit ausschließlich `signal`-Deklarationen
und keiner Logik. Producer rufen `EventBus.enemy_died.emit(...)`, Consumer
verbinden in `_ready()` mit `EventBus.enemy_died.connect(_on_enemy_died)`.

**Pro**
- Idiomatisches Godot-4-Pattern, Tooling-Support (Godot kennt Signals nativ)
- Statisch typisierbare Parameter (`signal enemy_died(enemy_id: StringName, pos: Vector2)`)
- Inspector zeigt Verbindungen an, gut debuggbar
- Modder können `EventBus.enemy_died.connect(...)` direkt aus Mod-Scripts aufrufen
- Headless-tauglich (Tests können Signals emittieren ohne Scene)

**Contra**
- Keine eingebaute Möglichkeit, Events zu queuen oder zu replayen
- Bei sehr vielen Signals wird `EventBus.gd` lang – braucht Disziplin

### Option B – Generischer `dispatch(event_name: StringName, payload: Dictionary)`

Ein Bus mit einer einzigen `dispatch()`-Funktion und String-IDs als Event-Typen.
Subscriber registrieren über `subscribe("enemy_died", callable)`.

**Pro**
- Schema-frei, einfach um neue Events zu erweitern
- Events trivial serialisierbar (für Replay/Telemetrie)
- Mod-API kann komplett dynamisch sein

**Contra**
- Keine Typsicherheit – Tippfehler im Event-Namen fallen erst zur Laufzeit auf
- Kein IDE-Support (Autocomplete, Go-to-Definition fehlen)
- Erfordert eigene Subscriber-Verwaltung & Lifetime-Handling
- Performance: Dictionary-Payloads sind teurer als getypte Args

### Option C – Mehrere themen-spezifische Busse (CombatBus, MetaBus, UIBus, …)

Aufteilung auf 3–5 fachliche Busse statt eines globalen.

**Pro**
- Fach-Domänen klarer getrennt, jede Datei kürzer
- Mod-Sichtbarkeit pro Domäne fein steuerbar

**Contra**
- Cross-Domain-Events (z.B. „Boss tot → Telemetrie + UI + Save“) brauchen Routing
- Modder müssen wissen, *welcher* Bus zuständig ist
- Höhere Einstiegshürde, Refactoring teuer wenn Aufteilung nicht passt

## 3. Empfehlung

**Option A** – ein einzelner Autoload-Singleton `EventBus` mit getypten Signals.

**Begründung**
- Beste Balance aus Typsicherheit, Tooling und Mod-Eignung
- Konsistent mit dem 7-Prinzipien-Set (Prinzip #2 wörtlich genommen)
- Falls die Datei zu groß wird, splitten wir später in `EventBus`,
  `EventBusUI`, `EventBusMeta` (Option C als Migration *aus* A heraus). Diese
  spätere Aufteilung ist günstig, weil die Aufruf-Sites trivial umbiegbar sind.
- Telemetrie-Replay (Vorteil von Option B) bauen wir als **Sidecar**: ein
  `EventRecorder.gd`, das sich auf alle EventBus-Signals verbindet und sie
  als Dictionary loggt. So bekommen wir B's Vorteile ohne dessen Nachteile.

**Konventionen**
- Signal-Namen: `<noun>_<past-tense-verb>` → `enemy_died`, `wave_started`,
  `mutation_picked`, `save_loaded`
- Payload: maximal 3 Parameter, alle getypt; bei mehr → eigene `Resource`
  (z.B. `EnemyDeathInfo`)
- Signal-Definitions-Reihenfolge in `EventBus.gd` gruppiert nach Domäne
  mit Block-Kommentar: `# --- Combat ---`, `# --- Meta-Progression ---`
- Modding-API: alle Signals in `EventBus.gd` gelten als **public API**
  und sind in MODDING.md aufgeführt. Renames sind Breaking Changes
  (mod-api-curator notify pflicht).
- Save-Trigger: `EventBus.save_requested.emit(reason: StringName)`,
  niemals direkter `SaveSystem.save()`-Call aus Game-Code

## 4. Konsequenzen

**Positiv**
- Systeme bleiben entkoppelt und einzeln testbar (Prinzip #7)
- Modder können von Tag 1 Events abonnieren
- EventRecorder gibt uns Telemetrie & Replay quasi geschenkt

**Negativ**
- `EventBus.gd` muss diszipliniert gepflegt werden, sonst wird sie ein
  Mülleimer für alles
- Signal-Renames sind Mod-Breaking → Naming muss von Anfang an stimmen
- Lebenszyklus: bei `queue_free()` muss disconnected werden (Godot macht das
  bei Node-Refs zwar automatisch, aber bei Lambdas nicht zuverlässig)

**Risiken & Mitigationen**
- **Risiko:** Performance-Probleme bei Hot-Path-Signals (z.B. `enemy_damaged` 60×/Frame).
  → **Mitigation:** Hot-Path-Events nicht über Signals laufen lassen, sondern
  über direkte Komponenten-Interfaces; nur „bedeutende" State-Changes über Bus.
  Faustregel: Wenn ein Event > 100×/Sekunde feuern könnte, kein Signal.
- **Risiko:** Modder verbinden sich mit später deprecated Signal.
  → **Mitigation:** Deprecation-Warnings in `_ready()` von EventBus loggen,
  mod-api-curator pflegt `deprecated-warnings.md`.

## 5. Betroffene Dateien & Systeme

Anzulegen (durch godot-implementer):
- `core/event_bus.gd` (Autoload)
- `project.godot` – Autoload-Eintrag „EventBus"
- `core/event_recorder.gd` (Sidecar, optional in Phase 0 noch nicht)
- `tests/scenes/test_event_bus.tscn` + `tests/unit/test_event_bus.gd`
- `docs/MODDING.md` – Abschnitt „Event-Subscription für Mods"
- `docs/ARCHITECTURE.md` – EventBus als zentrales Pattern dokumentieren

Berührt später:
- jedes neue Game-System (Spawner, Combat, Boss, UI, Save, Telemetrie, Mods)
- mod-api-curator: Initial-Eintrag in `public-api-surface.md`
- test-engineer: Test-Scene für isoliertes Signal-Testing

## 6. Folge-Entscheidungen (Backlog)

- ADR 0002 – Save-System & Schema-Versionierung (Prinzip #3)
- ADR 0003 – ContentLoader & Resource-Konventionen (Prinzipien #1, #5, #6)
- ADR 0004 – EventRecorder & Telemetrie-Format
- ADR 0005 – Mod-Loader Boot-Reihenfolge
