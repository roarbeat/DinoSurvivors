# Test Coverage

> Vom `test-engineer` gepflegt. Was getestet ist, was nicht.

## Stand 2026-05-06 — Phase 0 Skelett

### Ausführung

```bash
./tools/run_tests.sh
```

Letzter erfolgreicher Run:
- 3 Scripts, 29 Tests, 80 Asserts
- Laufzeit: ~30ms
- Alle grün

### Abgedeckt

| System | Test-File | Tests | Coverage |
|--------|-----------|-------|----------|
| EventBus | `test_event_bus.gd` | 7 | API-Surface, alle 18 Signals als Snapshot, Verhalten pro Domäne |
| ContentLoader | `test_content_loader.gd` | 10 | Discovery, Validation, ID-Convention, Type-Filter, Validate-Hook |
| SaveSystem | `test_save_system.gd` | 12 | Default-Schema, Roundtrip, set_field, EventBus-Hook, Migration-Runner |

### Nicht abgedeckt (Backlog)

- **Mod-Override-Verhalten** in ContentLoader — braucht Test-Mod-Fixture
  unter `tests/fixtures/mods/<test_mod>/content/...`
- **Migrations-Pure-Function-Test** — braucht echte v1_to_v2 Migration
  und Fixture
- **Save-Ref-Validation gegen ContentLoader** — fehlt expliziter Test
  mit fehlender Boss-ID
- **Atomic-Write-Crash-Resilience** — schwer zu testen, evtl. via
  Mocking von FileAccess (nicht trivial in GDScript)
- **Smoke-Scenes** — manuell verifiziert, nicht automatisiert

### Bekannte Warnings

- `Float/Int comparison` in test_save_then_load_yields_same_data —
  JSON-Roundtrip macht aus int 7 ein float 7.0. Akzeptabel für Werte,
  die sowieso als Stats interpretiert werden (saubere Lösung: `float()`
  beide Seiten oder spezifische int-Parser im Loader).

### Pipeline

- GUT 9.4.0 (im Repo unter `addons/gut/`)
- GitHub-Actions-Workflow `.github/workflows/test.yml` läuft auf
  push/PR gegen main + develop
- Pre-Merge: `./tools/run_tests.sh` muss grün sein (Code-Reviewer-Regel)
