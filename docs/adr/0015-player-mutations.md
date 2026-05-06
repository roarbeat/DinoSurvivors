# ADR 0015 – Player-Mutation-System (Aggregator)

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), game-designer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #2 EventBus, #7 testbar
- Voraussetzungen: ADR 0006 (Run-Lifecycle), ADR 0010 (Modifier), ADR 0014 (Bridge)
- Wird vorausgesetzt von: Mutation-Pick-UI, Player-Char-Scene

---

## 1. Kontext

Bridge (ADR 0014) übersetzt **eine** MutationDef in Modifier-Resourcen.
Was fehlt: ein Player-System, das **mehrere** gepickte Mutationen sammelt
und ihre Stats aggregiert. Konkret: zwei Mutationen mit `damage_pct=0.15`
und `damage_pct=0.20` sollen zu *einem* `MultiplierModifier(1.35)` werden,
nicht zwei separaten Modifiers (additives Stacking, wie es bei
Survivor-likes Standard ist).

Anforderungen v1:

- **Autoload-Aggregator** — `PlayerMutations` hält die Liste gepickter
  Mutationen und stellt aggregierte Modifier zur Verfügung
- **Run-Lifecycle-bewusst** — bei `run_started` resetet sich der Aggregator
  (Mutationen sind run-internal, nicht persistent)
- **Aggregations-Regeln explizit dokumentiert** — additiv für %-Stats,
  einmalig pro pick (kein Doppel-Pick)
- **Mod-erweiterbar** — Mods können später eigene Aggregations-Strategien
  einhängen (Backlog)
- **Komplett headless-testbar** — kein Scene-Setup, kein UI

## 2. Optionen

### Option A — Autoload-Aggregator (empfohlen)

```
PlayerMutations (Autoload)
├── _picked: Array[StringName]     # Pick-Reihenfolge
├── pick(id), remove(id), reset()
├── get_picked() -> Array[StringName]
└── get_aggregated() -> Dictionary  # {outgoing, incoming, unhandled}
```

**Pro**
- Cross-cutting Concern (HUD, Save, Achievements wollen den Stand wissen)
- Klar zentralisiert — eine Single-Source-of-Truth
- Subscribed `run_started` → automatischer Reset
- Komplett unit-testbar (kein Scene)

**Contra**
- Ein Autoload mehr (jetzt 7) — Boot-Order-Disziplin

### Option B — Component am Player-Char

Mutations-Liste lebt am Player-Node, andere Systeme greifen via
Group/Singleton-Lookup zu.

**Pro**
- Lifetime an Player-Scene gebunden — Cleanup automatisch

**Contra**
- HUD/UI/Save brauchen `get_tree().get_first_node_in_group("player")`
- Tests brauchen Scene-Setup
- Save-System hat keinen klaren Zugriffspunkt

### Option C — Stat-Bag direkt auf Player

Player-Char hat `stat_bag: Dictionary`, jede Mutation schreibt direkt
ihre stat_modifiers rein. Modifier werden on-demand gebaut.

**Pro**
- Sehr flach, kein Aggregations-Code

**Contra**
- Gepickte Mutations-Liste ist nicht erkennbar (wichtig für UI/Save/Achievements)
- Doppel-Pick-Schutz fehlt strukturell
- Aggregations-Reihenfolge unklar bei mehrfachen Picks

## 3. Empfehlung

**Option A** — Autoload-Aggregator.

**Begründung**
- Konsistent mit RunState/WaveSpawner als Autoloads (ADR 0006)
- Run-Lifecycle-Hook über EventBus.run_started ist trivial und idiomatisch
- Aggregations-Regeln bleiben an einer Stelle — leicht zu reviewen,
  leicht zu testen
- Public-API ist symmetrisch: pick/remove/reset/get — wie bei einer
  Inventar-Klasse

**Aggregations-Regeln (v1)**

| Stat-Bereich | Regel | Cap |
|--------------|-------|-----|
| `damage_pct` | additiv über Mutationen | kein Cap |
| `crit_chance` | additiv | clamp auf 1.0 |
| `crit_damage_pct` | additiv | kein Cap |
| `armor_pct` | additiv | clamp auf 1.0 |
| Unbekannte (`move_speed_pct` etc.) | additiv pro Key | kein Cap |

Additives Stacking ist die Survivor-likes-Standard-Konvention. Multiplikatives
Stacking (z.B. „elite Mutationen multiplizieren statt zu addieren") ist
eine spätere Erweiterung — eigenes ADR.

**Public-API**

```gdscript
PlayerMutations.pick(mut_id: StringName) -> bool       # false bei unbekannt oder bereits gepickt
PlayerMutations.remove(mut_id: StringName) -> bool
PlayerMutations.reset() -> void
PlayerMutations.get_picked() -> Array[StringName]
PlayerMutations.has(mut_id: StringName) -> bool
PlayerMutations.get_aggregated() -> Dictionary
   # { "outgoing": Array[DamageModifier],
   #   "incoming": Array[DamageModifier],
   #   "unhandled": Dictionary[StringName, float] }
```

`get_aggregated()` ist eine **reine Berechnung** auf der aktuellen
Pick-Liste. Cache-Invalidation passiert implizit durch
pick/remove/reset.

**EventBus-Integration**

Neues Signal: `mutations_changed()`. Wird gefeuert nach jedem
pick/remove/reset, damit HUD und Player-Combat-Komponenten ihre
Modifier-Stacks neu aufbauen.

**Run-Lifecycle**

```gdscript
func _ready() -> void:
    EventBus.run_started.connect(_on_run_started)

func _on_run_started(_dino_id: StringName) -> void:
    reset()
```

## 4. Konsequenzen

**Positiv**
- Mutationen wirken erstmals in der Praxis: Player kann mehrere picken,
  Stats stacken sauber
- HUD-Integration ist trivial: auf `mutations_changed` lauschen,
  `get_picked()` rendern
- Save-System kann gepickte Mutationen einfach abspeichern (in v1 nicht
  nötig, da run-internal)

**Negativ**
- Aggregations-Regeln sind im Code — neue %-Stats müssen explizit
  ergänzt werden (Konsequenz von ADR 0014's Mapping-Tabelle)

**Risiken**
- **Risiko:** Eine Mutation hat sowohl einen bekannten als auch einen
  unbekannten stat_key (z.B. damage_pct + custom_mod_stat) — die
  unhandled-Stats werden korrekt aggregiert, aber Listener müssen sie
  selbst interpretieren.
  → **Akzeptiert:** das ist by design (Player-Stat-System bekommt sie).

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/player_mutations.gd`              Autoload, Aggregator
- `core/event_bus.gd`                     +1 Signal: `mutations_changed`
- `tests/unit/test_player_mutations.gd`   gut-Tests
- `project.godot`                         PlayerMutations als 7. Autoload
                                          (NACH RunState — subscribt run_started)

Berührt später:
- Mutation-Pick-UI: triggert `pick(id)`
- Player-Combat-Setup: liest `get_aggregated()`, hängt Modifier auf
  HealthComponent/DamageDealer
- Save-System: optional (Run-State-Save, eigenes ADR)

## 6. Folge-Entscheidungen (Backlog)

- ADR — Multiplikatives Stacking für „elite"-Mutationen
- ADR — Mutation-Pick-UI
- ADR — Mod-Hook für eigene Aggregations-Strategien
