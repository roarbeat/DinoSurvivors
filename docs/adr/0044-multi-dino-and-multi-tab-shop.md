# ADR 0044 – Multi-Dino + Multi-Tab-Shop

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer + content-author + game-designer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #5 Mod-friendly, #6 Stable Content-IDs, #7 testbar
- Voraussetzungen: ADR 0008 (DinoDef), ADR 0030 (MetaProgression), ADR 0040 (Meta-Shop + UpgradeDef)
- Wird vorausgesetzt von: ADR — Char-Select-UI

---

## 1. Kontext

ADR 0040 hat den Meta-Shop für Stat-Upgrades eingeführt. v0.4.0 schließt
den Meta-Loop, indem zusätzliche **spielbare Dinos** als Käufe
ermöglicht werden:

- v1 hat genau einen Dino (`trex`)
- Nach v0.4.0: 3 Dinos (`trex` Default-unlocked, `velociraptor` + `stegosaurus`
  Bernstein-locked)
- Shop bekommt Multi-Tab-Layout: "STATS" und "DINOS"

Anforderungen v1:

- **`UpgradeDef.category: StringName`** (default `&"stat"`, alternativ `&"dino_unlock"`)
- **`DinoDef.unlock_upgrade_id: StringName`** (optional, leer = always-unlocked)
- **`MetaProgression.is_dino_unlocked(dino_id)`** prüft via Upgrade-Level
- **Multi-Tab-Shop-UI** mit Tab-Buttons "STATS" / "DINOS"
- **Backward-Kompat**: trex bleibt ohne unlock_upgrade_id → always-unlocked

Bewusst NICHT in v1:

- **Char-Select-UI vor Run-Start** (eigenes ADR)
- **Dino-Stats-Vergleich** im Shop ("trex vs velociraptor")
- **Cosmetic-Dinos** (gleiche Stats, anderer Look)
- **Dino-spezifische Upgrades** (jeder Dino hat eigene Stat-Upgrades)

## 2. Empfehlung

### UpgradeDef-Erweiterung

```gdscript
# core/content/upgrade_def.gd
@export var category: StringName = &"stat"
@export var unlock_dino_id: StringName = &""  # nur für category="dino_unlock"
```

`category` ist Schema-Slot — Modder können beliebige Kategorien
einführen (z.B. `"cosmetic"`). Default `"stat"` deckt alle bisherigen
Upgrades.

### DinoDef-Erweiterung

```gdscript
# core/content/dino_def.gd
@export var unlock_upgrade_id: StringName = &""  # leer = always-unlocked
```

Wenn gesetzt, ist der Dino erst spielbar wenn das entsprechende Upgrade
bei `level >= 1` ist.

### MetaProgression-API

```gdscript
func is_dino_unlocked(dino_id: StringName) -> bool:
    var def := ContentLoader.get_or_null(&"dino", dino_id) as DinoDef
    if def == null: return false
    if String(def.unlock_upgrade_id) == "": return true  # always-unlocked
    return get_upgrade_level(def.unlock_upgrade_id) >= 1
```

### Shop-Overlay Multi-Tab

```gdscript
# core/ui/shop_overlay.gd
@export var current_tab: StringName = &"stat"

func set_tab(tab: StringName):
    current_tab = tab
    refresh_list()

func _refresh_list():
    # Filter Upgrades nach current_tab (== category)
    for item in ContentLoader.get_all(&"upgrade"):
        if item.category != current_tab: continue
        # build row
```

UI: zwei Tab-Buttons oben, klicken setzt `current_tab` und triggert
`refresh_list()`.

### Initial-Content

```
content/dinos/
├── trex.tres                  # default unlocked
├── velociraptor.tres          # unlock_upgrade_id = "dino_unlock_velociraptor"
└── stegosaurus.tres           # unlock_upgrade_id = "dino_unlock_stegosaurus"

content/upgrades/
├── stronger_jaws.tres         # category = "stat" (existing, default)
├── tougher_hide.tres          # category = "stat"
├── faster_legs.tres           # category = "stat"
├── sharper_eyes.tres          # category = "stat"
├── dino_unlock_velociraptor.tres   # category = "dino_unlock", cost 200, max_level=1
└── dino_unlock_stegosaurus.tres    # category = "dino_unlock", cost 300, max_level=1
```

Velociraptor: schneller, weniger HP (Glaskanone)
Stegosaurus: langsamer, mehr HP (Tank)

## 3. Konsequenzen

**Positiv**
- **Meta-Shop-Loop wird tiefer**: Spieler hat klares Ziel beyond Stats —
  neuen Dino unlocken
- **Modder-tauglich**: jeder neue Dino braucht nur eine .tres + ein
  Unlock-Upgrade
- **Saubere Pattern**: kein Hack, alles über UpgradeDef.category

**Negativ**
- **Kein Char-Select**: Player kann nur via @export (`RunScene.dino_id`)
  oder Mod-Override den Dino wechseln. Char-Select-UI = eigenes ADR.

**Risiken**
- **Risiko:** Player setzt `dino_id = velociraptor` ohne Unlock.
  → **Mitigation v1:** RunScene loggt eine Warning, fällt aber auf trex
  zurück. Hard-Failure wäre Spielspaß-Bremse.

## 4. Betroffene Dateien

Anzulegen:
- `content/dinos/velociraptor.tres`
- `content/dinos/stegosaurus.tres`
- `content/upgrades/dino_unlock_velociraptor.tres`
- `content/upgrades/dino_unlock_stegosaurus.tres`
- `tests/unit/test_multi_dino.gd`

Berührt:
- `core/content/upgrade_def.gd` — `+ category`, `+ unlock_dino_id`
- `core/content/dino_def.gd` — `+ unlock_upgrade_id`
- `core/meta_progression.gd` — `+ is_dino_unlocked(dino_id)`
- `core/ui/shop_overlay.gd` — Tab-Filter
- `core/run_scene/run.gd` — bei dino_id-Lookup checkt Unlock,
  fällt auf trex zurück wenn locked
- locale + BALANCE + content-id-registry
- ARCHITECTURE/CHANGELOG/public-api-surface

## 5. Folge-Entscheidungen (Backlog)

- ADR — Char-Select-UI vor Run-Start
- ADR — Dino-Stats-Vergleich im Shop
- ADR — Cosmetic-Dinos (gleicher Stat, anderer Look)
- ADR — Dino-spezifische Stat-Upgrades
- ADR — Achievement-basierte Unlocks (zusätzlich zu Bernstein-Käufen)
