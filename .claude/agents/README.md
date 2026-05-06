# DinoRogue – Sub-Agent-Crew

Dieses Verzeichnis enthält die 13 Project-Scope Sub-Agents für DinoRogue,
spezifiziert in `DinoRogue_SubAgents.md` (Phase 0a).

## Übersicht

| # | Agent | Modell | Memory | Rolle |
|---|---|---|---|---|
| 1 | game-architect | opus | project | Architektur-Entscheidungen, ADRs |
| 2 | game-designer | sonnet | project | Balance & Mechanics |
| 3 | content-author | sonnet | project | Content-Resources (.tres) |
| 4 | lore-writer | sonnet | project | Flavor-Text, Tooltips, DE/EN |
| 5 | godot-implementer | sonnet | project | GDScript-Implementation |
| 6 | shader-fx-specialist | sonnet | project | Comic-Shader, VFX |
| 7 | code-reviewer | sonnet | user | Pre-Merge Review |
| 8 | test-engineer | sonnet | project | Test-Scenes, gut-Tests |
| 9 | balance-analyst | sonnet | project | Telemetrie & Balance-Patches |
| 10 | save-migration-specialist | sonnet | project | Save-Schema-Migrations |
| 11 | mod-api-curator | sonnet | project | Modding-API-Stabilität |
| 12 | release-manager | sonnet | project | Build, Steam-Upload, Patch-Notes |
| 13 | localization-coordinator | sonnet | project | po-Files, Übersetzungen |

## Aufruf

Automatisch via Description-Matching, oder explizit:

```
> Use the game-architect subagent to outline the EventBus design.
> Use the godot-implementer subagent to wire up SaveSystem.gd.
```

## Memory

Pro Agent ein Unterordner unter `memory/<agent-name>/` mit den im jeweiligen
Agent-Prompt vorgesehenen Files. Aktuell mit Boilerplate initialisiert –
die Agents erweitern und pflegen ihre Memory-Files selbst.

## Erweiterung

Die Agent-Liste ist ein Startpunkt, kein Endzustand. Wenn nach 1–2 Monaten
Aufgaben immer wieder ohne passenden Agent auftauchen: neuen Agent ergänzen
und in dieser README eintragen.
