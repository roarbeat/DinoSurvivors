# Known Flaky Tests

> Vom `test-engineer` gepflegt. Tests die manchmal failen, mit Verdachtsursache.

## Stand 2026-05-06

(noch keine flakies — Test-Suite ist deterministisch und schnell)

## Format-Vorschlag für Einträge

```
### test_<name> in <file>
- Symptom: ...
- Frequenz: ~1 von <n> Runs
- Verdacht: ...
- Workaround: ...
- Reproduziert wann: ...
```

## Hygiene-Regel

Wenn ein Test zweimal hintereinander out-of-the-blue rot wird:
sofort hier eintragen, NICHT „nochmal probieren" und ignorieren.
Flakies werden mit der Zeit zu Bug-Magnets.
