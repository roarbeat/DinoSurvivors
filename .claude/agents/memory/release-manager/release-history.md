# Release History

> Vom `release-manager` gepflegt.

## (noch keine Public-Releases)

## Internal Tags

### v0.0.4 — 2026-05-06 — Phase 2: Spielbarer Mini-Game-Loop

**Hauptänderungen:**
- ADR 0011 Hit-Detection v1 (Auto-Attack + Touch-Damage + iframes)
- ADR 0017 Enemy-Movement v1 (Direkt-Walk)
- ADR 0018 Visueller Stub + HP-Bar
- ADR 0013 Auto-Spawn-Curves v1 (prozedural)
- ADR 0019 Game-Over-Overlay + Run-Restart

**Was zum ersten Mal funktioniert:**
- F5 zeigt einen vollständigen Spielloop:
  - Player läuft mit WASD (gelber Quadrat 24×24)
  - Raptoren laufen aktiv auf Player zu (rote Quadrate 16×16)
  - HP-Bars über jedem Mob reagieren in Echtzeit auf Damage
  - Player-Auto-Attack trifft Enemies in 80px-Radius
  - Touch-Damage mit 0.5s iframes
  - Auto-Spawn skaliert von 0.5/s (Welle 1) bis 5/s (Cap)
  - Spawn 400px außerhalb Player (zufälliger Winkel)
  - Bei Tod: Game-Over-Overlay mit Reason / Time / Wave
  - [Enter] → Cleanup → neuer Run

**Test-Suite:** 20 Scripts, 227 Tests, 434 Asserts — alle grün.

**Public-API-Surface:** unverändert auf Bus-Ebene (21 Signals), erweitert
um PlayerCharacter-Combat-API, EnemyMob-Movement-API, HealthBar,
GameOverOverlay.

**Repo-Bilanz:** 12507 Zeilen total (+2474 ggü. v0.0.3).

**Status:** Internal Tag. Phase 2 hat einen kompletten Loop.

### v0.0.3 — 2026-05-06 — Phase 1 vollständig: bootbares Skelett

**Hauptänderungen:**
- ADR 0015 Player-Mutation-System (Aggregator)
- ADR 0008 Player-Character-Scene + Movement
- ADR 0009 Enemy-Mob-Pattern + Spawn-API
- ADR 0016 Run-Scene-Glue (main_scene)

**Test-Suite:** 17 Scripts, 183 Tests, 367 Asserts.

### v0.0.2 — 2026-05-06 — Phase 1 Math-Pipeline

**Hauptänderungen:**
- ADR 0005 Mod-Loader & mod.json-Schema
- ADR 0006 Run-Lifecycle (RunState + WaveSpawner + DinoDef)
- ADR 0007 Combat-Pipeline
- ADR 0010 Modifier-Pipeline
- ADR 0014 Mutation→Modifier-Bridge

**Test-Suite:** 13 Scripts, 128 Tests, 263 Asserts.

### v0.0.1 — 2026-05-06 — Phase 0 Skelett

- 13 Sub-Agents in `.claude/agents/`
- ADR 0001 EventBus, 0002 SaveSystem, 0003 ContentLoader
- GUT 9.4.0 + CI-Pipeline

**Test-Suite:** 4 Scripts, 39 Tests, 97 Asserts.

---

## Pre-Release-Checkliste-Status (aktuell)

| Check | Tool | Stand 2026-05-06 (v0.0.4) |
|-------|------|---------------------------|
| Tests grün | `./tools/run_tests.sh` | ✅ 227/227 |
| Save-Migration getestet | gut + Fixtures | ✅ Pipeline tested |
| Mod-API-Kompatibilität | mod-api-curator | ✅ nur additiv ggü. v0.0.3 |
| BALANCE.csv aktuell | Diff | ✅ 5 Einträge synchron |
| CHANGELOG.md hat Eintrag | Lesen | ✅ v0.0.4-Block gefüllt |
| Headless-Boot | godot --quit-after | ✅ 60 Frames stabil |
| Version-Tag in Git | `git tag` | ⏳ vom User auszuführen |
| Build erzeugt | `./tools/build.ps1` | ⏳ Build-Tool fehlt |
| Patch-Notes | lore-writer | ⏳ erst ab v0.1 nötig |
| Steam-Branch | steamcmd | ⏳ erst ab Public-Beta |

## Roadmap

| Tag | Inhalt | Status |
|-----|--------|--------|
| v0.0.1 | Phase-0-Skelett | ✅ |
| v0.0.2 | Phase-1-Math-Pipeline | ✅ |
| v0.0.3 | Phase 1 vollständig: bootbares Skelett | ✅ |
| **v0.0.4** | **Phase 2: spielbarer Mini-Game-Loop** | ✅ bereit zum Tag |
| v0.0.5 | HUD (Run-Timer, Wave-Counter, gepickte Mutationen) | ⏳ |
| v0.0.6 | Damage-Number-VFX, Mutation-Pick-Phase nach Welle | ⏳ |
| v0.0.7 | Sprites, Animations, Sound | ⏳ |
| v0.0.8 | WaveDef als Content-Resource, Mix-Wellen | ⏳ |
| v0.1.0 | Vertical-Slice (1 Dino, 5+ Mutationen, 1 Boss, 10-Min-Run) | ⏳ |
