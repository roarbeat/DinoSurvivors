# ADR 0043 – Zweiter Boss (Triceratops Charge) + Zweite Map

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer + content-author + game-designer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #5 Mod-friendly, #7 testbar
- Voraussetzungen: ADR 0025 (Boss-Spawn), ADR 0026 (WaveDef), ADR 0036 (MapDef), ADR 0038 (Boss-Abilities)
- Wird vorausgesetzt von: ADR — Boss-Variations-Pool

---

## 1. Kontext

v0.2.0 hat genau einen Boss (`tyrannosaurus_prime` mit Stomp-Ability)
und eine Map (`default`). Das validiert die Pipeline, aber nicht die
**Modder-Surface**: Können Designer/Modder eigene Bosse + Maps via .tres
ergänzen, ohne Code zu ändern? Antwort prüfen wir, indem wir es selbst
machen.

Anforderungen v1:

- **Zweiter Boss**: `triceratops_charge` mit eigener Ability `BossCharge`
  (kurzer Move-Burst Richtung Player, hoher Damage)
- **Zweite Map**: `forest_clearing` (12×12 Grid statt 8×8, anderes
  Pfad-Pattern)
- **Boss-Wave-Rotation**: WaveDef-Override für Welle 5 = T-Prime,
  Welle 10 = Triceratops, Welle 15 = T-Prime, Welle 20 = Triceratops
- **Tests** verifizieren das Modder-Pattern: nur .tres-Files, kein
  Code-Touch im Game-Code

Bewusst NICHT in v1:

- **Random-Boss-Selection** (Boss zufällig aus Pool ziehen)
- **Boss-Specific-Drops** (jeder Boss droppt eigenes Item)
- **Map-Selection-UI** (Player wählt Map vor Run-Start)
- **Multi-Map-Phasen** (Map wechselt mid-Run)

## 2. Empfehlung

### BossCharge — neue Ability

`core/content/abilities/boss_charge.gd extends BossAbility`:
- `charge_speed: float = 600.0`  Pixel/Sekunde während Charge
- `charge_duration: float = 0.5` Sekunden
- `damage: float = 35.0`         pro Treffer-Tick

`trigger(boss)` startet einen Charge-Timer auf dem Boss. Während
des Charges:
- Boss bewegt sich mit `charge_speed * direction_to_player_at_trigger`
- Touch-Damage wird angewandt (Player kann iframen)
- Nach `charge_duration` endet der Charge (Boss kehrt zu Standard-
  Movement zurück)

Implementation als `_charge_state: Dictionary` auf dem BossMob —
einfacher als ein Hidden-Timer-Node.

### TriceratopsCharge-Boss

`content/bosses/triceratops_charge.tres`:
- max_health = 1000
- speed = 60   (langsamer als T-Prime im Standard)
- damage = 35  (höher als T-Prime: aggressiv im Charge)
- body_color = (0.5, 0.4, 0.25)  matschbraun
- 3 Phasen: Spawn / Mid (66%) / Rage (33%)
- Phase 1 (Mid): BossCharge mit cooldown=8s, damage=30
- Phase 2 (Rage): BossCharge mit cooldown=5s, damage=40
- reward_currency_amount = 75 (höher als T-Prime: er ist zäher)

### Forest-Clearing-Map

`content/maps/forest_clearing.tres`:
- grid_size = (12, 12)
- path_row = 6, path_col = 6
- decoration_density = 0.30 (mehr Blumen — "Wald")
- biome_label_key = "map.forest_clearing.banner"

### Boss-Wave-Rotation

WaveSpawner.`_resolve_boss_id_for_wave` nutzt heute Konstante:
```
return &"tyrannosaurus_prime"
```

Wir erweitern via WaveDef-Override:

```
content/waves/wave_5_tyrannosaurus.tres   # T-Prime (existing)
content/waves/wave_10_triceratops.tres    # NEU — Triceratops
content/waves/wave_15_tyrannosaurus.tres  # NEU — T-Prime wieder
content/waves/wave_20_triceratops.tres    # NEU — Triceratops endgame
```

Bestehende `wave_10_tyrannosaurus.tres` wird ersetzt durch
`wave_10_triceratops.tres`. WaveSpawner-Code bleibt unverändert —
der Resolver liest die WaveDefs.

## 3. Konsequenzen

**Positiv**
- **Modder-Pattern validiert**: Boss + Map + Ability + Wave alles
  data-driven, kein Game-Code-Touch
- **Variation**: Welle 10 fühlt sich anders an als Welle 5 (charging
  Triceratops vs. stomping T-Rex)
- **Foundation für Boss-Pool**: Random-Selection-ADR baut auf diesem
  Pattern auf

**Negativ**
- **BossCharge braucht Movement-Override** im BossMob (Boss überschreibt
  sein normales Direkt-Walk während Charge). Akzeptabel — sauber via
  `_charge_state`-Flag.

**Risiken**
- **Risiko:** Charge-Movement-Code kollidiert mit Phase-Speed-Multiplier.
  → **Mitigation:** Während Charge wird `_move_toward_player` durch
  `_apply_charge_movement` ersetzt. `get_speed()` ist nicht relevant
  während Charge (Speed kommt aus Ability).

## 4. Betroffene Dateien

Anzulegen:
- `core/content/abilities/boss_charge.gd`
- `content/bosses/triceratops_charge.tres`
- `content/maps/forest_clearing.tres`
- `content/waves/wave_10_triceratops.tres`
- `content/waves/wave_15_tyrannosaurus.tres`
- `content/waves/wave_20_triceratops.tres`
- `tests/unit/test_boss_charge.gd`

Berührt:
- `core/boss/boss_mob.gd` — `_charge_state`, `_apply_charge_movement`
- `content/waves/wave_10_tyrannosaurus.tres` — wird durch
  `wave_10_triceratops.tres` ersetzt (alte Datei kann bleiben aber
  hat dann keinen Effekt mehr da Welle 10 nun einen anderen Override hat)
- locale + BALANCE
- Doku

## 5. Folge-Entscheidungen (Backlog)

- ADR — Random-Boss-Selection-Pool
- ADR — Boss-Specific-Drops
- ADR — Map-Selection-UI
- ADR — Multi-Map-Phasen
