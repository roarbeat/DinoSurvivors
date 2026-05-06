# ADR 0040 – Meta-Shop-UI + UpgradeDef

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer + game-designer + content-author (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #2 EventBus, #3 Save-versioned, #5 Mod-friendly, #7 testbar
- Voraussetzungen: ADR 0003 (ContentLoader), ADR 0008 (PlayerCharacter), ADR 0010 (Modifier-Pipeline), ADR 0014 (Mutation→Modifier-Bridge), ADR 0030 (MetaProgression)
- Wird vorausgesetzt von: ADR — Shop-Layout-Themes, ADR — Multi-Tab-Shop

---

## 1. Kontext

ADR 0030 hat Bernstein-Currency als persistenten Counter eingeführt.
Boss-Defeat zahlt 50 Bernstein, Save persistiert. Aber **niemand kann
Bernstein ausgeben** — die Currency akkumuliert, ohne Wirkung. Es
fehlt der Loop:

```
Run → Bernstein verdienen → Run-Ende → SHOP → Upgrade kaufen →
Nächster Run mit Buff
```

Anforderungen v1:

- **`UpgradeDef`-Content-Resource** mit Cost-Curve, max_level,
  stat_modifiers (gleiches Schema wie MutationDef.stat_modifiers für
  Konsistenz)
- **Shop-Overlay-UI** auf eigenem CanvasLayer mit Liste der
  verfügbaren Upgrades, Cost, Current-Level, Buy-Button
- **`MetaProgression.purchase_upgrade(id)`** API:
  - Prüft ob Bernstein reicht
  - Subtrahiert Cost
  - Erhöht Upgrade-Level
  - Persistiert via SaveSystem
  - Feuert `EventBus.upgrade_purchased`
- **Player-Buffs aus Upgrades** wirken via `MutationModifierBridge`
  (analog zu Mutationen) — gleicher Modifier-Stack
- **Shop-Trigger**: GameOver-Overlay zeigt einen "SHOP"-Button →
  Shop-Overlay öffnen

Bewusst NICHT in v1:

- **Multi-Tab-Shop** (Stat-Upgrades / Dino-Unlocks / Cosmetics) — eigenes ADR
- **Cost-Currency-Wahl** (in v1 nur Bernstein, später mehrere)
- **Upgrade-Dependency-Tree** ("X benötigt Y level 3 zuerst")
- **Refund** (gekaufte Upgrades zurückgeben)
- **UI-Animation/Polish** (UI ist funktional, Style kommt mit echten
  Sprites in v0.2.x)
- **Shop-Scene als eigene Scene** statt Overlay (für v1 reicht Overlay)

## 2. Empfehlung

### UpgradeDef-Schema

```gdscript
class_name UpgradeDef extends ContentItem

## Maximales Level (1 = Single-Buy, 5 = 5-Stage-Upgrade).
@export var max_level: int = 1

## Cost-Curve: cost_per_level[level] = Bernstein-Kosten für level→level+1.
## Wenn weniger Einträge als max_level, wird der letzte Eintrag wiederholt.
@export var cost_per_level: Array[int] = [50]

## Stat-Modifiers pro Level. value[level] = Modifier-Werte.
## Schema gleich wie MutationDef.stat_modifiers (z.B. "damage_pct", 0.05)
@export var stat_modifiers_per_level: Array[Dictionary] = [{}]

## Currency-Type. v1: nur "amber". Mehrere Currencies kommen mit
## eigenem ADR.
@export var cost_currency: StringName = &"amber"
```

### MetaProgression-Erweiterung

```gdscript
const UPGRADE_LEVELS_KEY: String = "upgrade_levels"
var _upgrade_levels: Dictionary = {}  # upgrade_id → int

func get_upgrade_level(id: StringName) -> int
func get_upgrade_cost(id: StringName) -> int   # Cost für nächsten Level-Up
func can_afford_upgrade(id: StringName) -> bool
func purchase_upgrade(id: StringName) -> bool  # true bei Erfolg

func _on_save_loaded(_v):
    # ... existing ...
    _upgrade_levels = SaveSystem.get_data().get("upgrade_levels", {})

func _on_save_requested(_r):
    # ... existing ...
    SaveSystem.set_field("upgrade_levels", _upgrade_levels.duplicate())
```

### EventBus-Erweiterung

```gdscript
signal upgrade_purchased(upgrade_id: StringName, new_level: int)
```

EventBus-Total: 23 → **24 Signals**.

### Player-Stat-Application

`PlayerCharacter._apply_stats` aggregiert heute nur Mutationen. Wir
erweitern es, sodass es auch Meta-Upgrades inkludiert:

```gdscript
# Bisheriges Aggregat
var agg := PlayerMutations.get_aggregated()

# Neu: Upgrades draufaddieren
var meta_mods := MetaProgression.get_aggregated_modifiers()
for m in meta_mods["outgoing"]: agg["outgoing"].append(m)
for m in meta_mods["incoming"]: agg["incoming"].append(m)
for k in meta_mods["unhandled"]:
    agg["unhandled"][k] = float(agg["unhandled"].get(k, 0.0)) + meta_mods["unhandled"][k]

_apply_stats_internal(agg)
```

`MetaProgression.get_aggregated_modifiers()` baut Modifier aus den
gekauften Upgrade-Levels (gleicher Code-Pfad wie
`MutationModifierBridge.build_aggregated`).

### Shop-Overlay-UI

```gdscript
# core/ui/shop_overlay.gd extends CanvasLayer
# - layer = 90 (zwischen MutationPickLayer und GameOverLayer)
# - PROCESS_MODE_WHEN_PAUSED (UI-only, kein Spielfluss)
# - Liste aller UpgradeDefs aus ContentLoader
# - Pro Upgrade: name + cost + buy-button
# - On-Click → MetaProgression.purchase_upgrade(id)
```

### GameOver-Hook

GameOver-Overlay bekommt einen "SHOP"-Button neben "Restart". Click
öffnet Shop-Overlay. Optional in v1 auch via Pause-Menü (kommt mit
eigenem ADR).

### Initial-Upgrades

```
content/upgrades/
├── stronger_jaws.tres        max_level=3, cost [50, 100, 200],
│                              damage_pct +0.05/level
├── tougher_hide.tres         max_level=3, cost [50, 100, 200],
│                              max_health_pct +0.10/level
├── faster_legs.tres          max_level=3, cost [40, 80, 160],
│                              move_speed_pct +0.10/level
└── sharper_eyes.tres         max_level=2, cost [80, 200],
                              pickup_radius_pct +0.20/level
```

## 3. Konsequenzen

**Positiv**
- **Loop ist geschlossen**: Bernstein hat Bedeutung
- **Modder-tauglich**: `upgrade` als 8. Content-Type
- **Pattern-konsistent**: nutzt MutationModifierBridge, gleicher
  Stat-Aggregat-Code-Pfad

**Negativ**
- **UI-Komplexität**: Shop-Overlay ist mehr als HUD/GameOver — braucht
  Buttons, Liste, State-Management
- **Save-Schema-Erweiterung**: `upgrade_levels` als neues Feld

**Risiken**
- **Risiko:** Player kauft Upgrade mit ungültiger ID (z.B. Mod-Drop) →
  Save kaputt.
  → **Mitigation:** `purchase_upgrade` validiert via ContentLoader.

- **Risiko:** Save-Migration: alte Saves haben kein
  `upgrade_levels`-Feld.
  → **Mitigation:** Default `{}` beim Load (analog ADR 0030).

## 4. Betroffene Dateien

Anzulegen:
- `core/content/upgrade_def.gd`
- `content/upgrades/{stronger_jaws, tougher_hide, faster_legs, sharper_eyes}.tres`
- `core/ui/shop_overlay.gd` + `.tscn`
- `tests/unit/test_upgrade_def.gd`
- `tests/unit/test_shop_overlay.gd` (UI-Tests)

Berührt:
- `core/content_loader.gd` — TYPE_CONFIG +`upgrade`
- `core/meta_progression.gd` — `+ purchase_upgrade`,
  `+ get_upgrade_level`, `+ get_aggregated_modifiers`
- `core/event_bus.gd` — `+ upgrade_purchased(...)`
- `tests/unit/test_event_bus.gd`, `test_meta_progression.gd`
- `core/player/player_character.gd` — `_apply_stats` inkludiert
  Meta-Modifier
- `core/ui/game_over.gd` + `.tscn` — Shop-Button
- `agents/memory/save-migration-specialist/save-schema-history.md` — v1.2
- `agents/memory/mod-api-curator/public-api-surface.md`
- `BALANCE.csv`, `locale/{de,en}.po`
- `docs/CONTENT.md`

## 5. Folge-Entscheidungen (Backlog)

- ADR — Multi-Tab-Shop (Stat / Dino / Cosmetic)
- ADR — Upgrade-Dependency-Tree
- ADR — Refund-Mechanik (gekaufte Upgrades zurückgeben)
- ADR — Multiple-Currency-Typen
- ADR — Pause-Menu mit Shop-Zugang
- ADR — Shop-UI-Polish (Animation, 9-Slice, Sprites)
