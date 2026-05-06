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

## v1.1 (additive, 2026-05-06, ADR 0030 Persistente Meta-Progression)

**Kein Schema-Bruch, kein Migration-File nötig.**

Save bekommt einen optionalen `data.meta_progression`-Slot, in dem
MetaProgression seinen Currency-State persistiert:

```jsonc
{
  "schema_version": 1,
  "data": {
    "meta_progression": {
      "amber": 250        // beliebige weitere Currency-Keys (Mod-erweiterbar)
    }
  }
}
```

Saves vor v0.1.0 (ohne `data.meta_progression`) werden korrekt geladen
— `MetaProgression._on_save_loaded` checkt `data.get("meta_progression", null)`
und behält Default-State (alle Currencies = 0), wenn der Slot fehlt.

**Schreibe-Pfad:** `EventBus.save_requested` → MetaProgression schreibt
sich via `SaveSystem.set_field("meta_progression", {...})` rein →
SaveSystem.save() schreibt das ganze data-Dict atomar auf Disk.

**Lese-Pfad:** SaveSystem.load_save → updated `_data` → feuert
`save_loaded(version)` → MetaProgression liest sich raus.

**Wichtige SaveSystem-Korrektur (ADR 0030):** `save_loaded`-Signal
feuert ab v0.1.0 NACH dem `_data = loaded`-Assign, sodass Listener
über `SaveSystem.get_data()` direkt auf den geladenen State zugreifen
können. Vorher feuerte das Signal vor dem Assign — niemand außer
MetaProgression hat darauf gehört, daher kein Breaking Change für
bestehenden Code.

---

## (Künftige Versionen werden hier ergänzt)
