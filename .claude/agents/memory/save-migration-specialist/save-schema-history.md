# Save Schema History

> Vom `save-migration-specialist` gepflegt. Vollständige Historie aller Schemas.
>
> Regel: einmal dokumentiert, NIEMALS löschen. Nur ergänzen.

---

## v1 — Initial-Release (2026-05-06, ADR 0002)

```jsonc
{
  "schema_version": 1,           // pflicht, immer erstes Feld
  "meta": {
    "created_at": "ISO8601",
    "last_played_at": "ISO8601",
    "game_version": "string",
    "last_save_reason": "string"  // wird beim Save automatisch gesetzt
  },
  "meta_progression": {
    "currencies": {
      "amber": 0                  // andere Currencies kommen mit Forschungs-Tree
    },
    "unlocked_dinos": ["trex"],   // Liste von Dino-IDs (Type "dino" — kommt mit Char-System)
    "research_progress": {}       // map<research_node_id, int>
  },
  "stats": {
    "total_runs": 0,
    "total_play_seconds": 0,
    "bosses_defeated": []         // Liste von Boss-IDs
  },
  "settings": {
    "master_volume": 1.0,
    "music_volume": 0.8,
    "sfx_volume": 1.0,
    "language": "de"
  },
  "mod_overrides_used": []        // wird vom ContentLoader-Override-System gefüllt
}
```

### ID-Felder, die gegen ContentLoader validiert werden

| Pfad | Type | Verhalten bei Miss |
|------|------|--------------------|
| `meta_progression.unlocked_dinos[]` | `dino` (kommt später) | log + skip |
| `stats.bosses_defeated[]` | `boss` | log, Eintrag bleibt im Save (Achievement-relevant) |

### Defaults pro Feld

Sie sind in `core/save_system.gd::_default_save()` zentralisiert.
Jede Migration MUSS Defaults für neue Felder setzen, sonst sind alte
Saves nach Migration unvollständig.

---

## (Künftige Versionen werden hier ergänzt)
