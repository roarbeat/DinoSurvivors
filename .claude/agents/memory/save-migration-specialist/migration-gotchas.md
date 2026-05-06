# Migration Gotchas

> Vom `save-migration-specialist` gepflegt. Edge-Cases die uns gebissen haben.

## Pure-Function-Garantie

Migrations dürfen NIE:
- File-I/O machen (kein FileAccess, kein DirAccess)
- Globalen Singleton-State lesen oder ändern (kein EventBus, kein ContentLoader)
- Zufallszahlen verwenden ohne explizit gesetzten Seed
- Aktuelles Datum/Uhrzeit verwenden, AUSSER es wird in einem `_migrated_at`-
  Feld festgehalten (dann ist der Wert intentional und Test-fixierbar)

Migrations dürfen:
- Lesen: nur das übergebene Dictionary
- Schreiben: nur ins zurückgegebene Dictionary
- Konstanten und reine Helper-Funktionen verwenden

## schema_version IMMER setzen

Jede Migration MUSS am Ende `data["schema_version"] = TO_VERSION` setzen.
Der Runner warnt zwar, wenn das fehlt, aber das ist ein Bug-Indicator —
Migrations sollten das selbst tun.

## Backup-Discipline

Backups werden im SaveSystem gemacht, nicht in der Migration. Die Migration
sieht das File nie als File, nur als Dictionary.

## Tests pro Migration

Pro Migration:
1. Fixture `tests/fixtures/save_v<n>.json` (alter Save als Eingabe)
2. gut-Test der die Migration aufruft und Ausgabe prüft
3. Test der prüft: Migration ist deterministisch (zweimaliges
   Aufrufen mit gleichem Input gibt gleichen Output)

## (noch keine echten Bisswunden — Liste wächst mit Erfahrung)
