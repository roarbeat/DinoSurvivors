# DinoRogue

Roguelike-Survivor-likes mit Mutationssystem in Godot 4.6.

## Status

**v0.1.0 — Vertical-Slice mit data-driven Stack** (2026-05-06)

- ✅ EventBus (ADR 0001) — 22 Signals, 4-fach-Sync (Code/Test/Doku)
- ✅ ContentLoader (ADR 0003) — 6 Types: mutation/enemy/boss/dino/wave/sound
- ✅ SaveSystem (ADR 0002) — JSON, atomic-write, Schema-Migrations
- ✅ ModLoader (ADR 0005) — mod.json, Failure-Isolation, Override-Surface
- ✅ Combat-Pipeline (ADR 0007/0010/0014) — DamageInfo, HealthComponent,
  Modifier-Stack, Mutation→Modifier-Bridge
- ✅ PlayerCharacter + EnemyMob + BossMob (ADR 0008/0009/0025) —
  Component-Pattern, Group-Konventionen
- ✅ Run-Lifecycle (ADR 0006/0016/0019) — RunState-Maschine, Run-Scene-Glue,
  Game-Over-Overlay + Restart
- ✅ Hit-Detection + Movement (ADR 0011/0017) — distanz-basiert, headless-testbar
- ✅ Visuals (ADR 0018/0024/0027) — HP-Bar, Color-Differenzierung,
  Visual-Provider-Slot für Sprites
- ✅ HUD + Damage-Numbers (ADR 0020/0012)
- ✅ Mutation-Pick-Phase + Rarity-Weighting (ADR 0021/0022)
- ✅ 7 Mutationen, 4 Enemy-Variants, 1 Boss
- ✅ Auto-Spawn-Curves + WaveDef-Resolver (ADR 0013/0023/0026)
- ✅ Boss-Phasen-Schema (ADR 0029) — HP-Threshold-basierter Verhaltens-Wechsel
- ✅ SFX-Bus + SoundDef (ADR 0028) — Audio-Hooks bereit für Asset-Drop
- ✅ Persistente Meta-Progression (ADR 0030) — Bernstein überlebt Runs
- ✅ Test-Pipeline (GUT 9.4.0) — 29 Scripts, ~400 Tests, alle grün

Asset-Drop-Pass und Vertical-Slice-Polish folgen in v0.1.x — die ganze
Asset-frei lauffähige Mechanik steht.

## Architektur

Siehe [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) für die 7 Kern-Prinzipien
und Pattern-Dokumentation, [`docs/adr/`](docs/adr/) für die einzelnen
Architecture Decision Records.

Sub-Agent-Crew (13 Project-Scope Agents) liegt unter
[`.claude/agents/`](.claude/agents/) — siehe
[`.claude/agents/README.md`](.claude/agents/README.md).

## Tests

```bash
# Linux/Mac
./tools/run_tests.sh                            # alle Unit-Tests
./tools/run_tests.sh tests/unit/test_event_bus.gd  # einzelner Test

# Windows
.\tools\run_tests.ps1
```

CI läuft auf jedem Push und PR via [`.github/workflows/test.yml`](.github/workflows/test.yml).

**Voraussetzungen lokal:**
- Godot 4.6+ als `godot4` oder `godot` im PATH (oder `$GODOT` als Override)
- GUT 9.4.0 ist im Repo eingecheckt unter `addons/gut/` — keine separate Installation

**Headless-Befehl direkt:**
```bash
godot4 --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

## Content hinzufügen

Siehe [`docs/CONTENT.md`](docs/CONTENT.md) — Procedure für content-author und
Modder. Mods leben unter `user://mods/<mod_id>/content/<type>/`.

## Lizenz

(folgt — vor öffentlichem Release festlegen)
