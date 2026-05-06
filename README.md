# DinoRogue

Roguelike-Survivor-likes mit Mutationssystem in Godot 4.3.

## Status

Phase 0 — architektonisches Skelett:

- ✅ EventBus (ADR 0001) — globaler Signal-Hub mit 18 Signals
- ✅ ContentLoader (ADR 0003) — type-indizierte Resource-Registry
- ✅ SaveSystem (ADR 0002) — JSON-Save mit Schema-Migrations
- ✅ Test-Pipeline (GUT 9.4.0) — 29 Tests, alle grün
- ⏳ Mod-Loader (ADR 0005) — geplant
- ⏳ Gameplay-Systeme (Combat, Wave-Spawner, …) — folgen

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
- Godot 4.3+ als `godot4` oder `godot` im PATH (oder `$GODOT` als Override)
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
