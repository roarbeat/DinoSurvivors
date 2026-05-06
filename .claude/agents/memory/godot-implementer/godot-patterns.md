# Godot Patterns

> Vom `godot-implementer` gepflegt. Projektspezifische Patterns die wir nutzen.

## EventBus (siehe ADR 0001 + ARCHITECTURE.md)

```gdscript
# Producer
EventBus.enemy_died.emit(enemy_id, global_position)

# Consumer (Method-Ref bevorzugt)
EventBus.enemy_died.connect(_on_enemy_died)

# Consumer (Lambda — IMMER manuell disconnecten)
var _cb: Callable = func(...): ...
EventBus.foo.connect(_cb)
# ... in _exit_tree(): EventBus.foo.disconnect(_cb)
```

## ContentLoader (siehe ADR 0003)

```gdscript
# Pflicht-Existenz: panic bei unbekannt
var mut: MutationDef = ContentLoader.get_item(&"mutation", &"triceratops_horns")

# Optional: null bei unbekannt
var mut := ContentLoader.get_or_null(&"mutation", id)

# Listing (Reihenfolge ist Discovery-Order, nicht für Gameplay verwenden)
for m in ContentLoader.get_all(&"mutation"):
    ...
```

NIE: `load("res://content/...")` direkt — nur über Loader.

## Naming

- Signal-Namen: `<noun>_<past-tense-verb>` (`enemy_died`, `wave_started`)
- Variablen: Englisch, snake_case
- Kommentare: Deutsch
- Resource-IDs: snake_case StringName, niemals umbenennen
- i18n-Keys: `<type>.<id>.<field>`

## Resource-Klassen

Jede ContentItem-Subklasse hat einen `validate() -> String`-Hook.
Leerer Return = OK, sonst Fehlertext. ContentLoader ruft das beim
Boot auf und verwirft ungültige Resources mit push_warning.

## Verbotene Anti-Patterns

- `print("Spieler gestorben")` als User-facing — IMMER `tr(...)`
- Direkter `SaveSystem.save()`-Call — IMMER über `EventBus.save_requested`
- `load("res://content/...")` direkt — IMMER über ContentLoader
- Hardcodierter Game-Inhalt im Code
- Hot-Path-Events (>100×/s) über EventBus — direkte Component-Refs
- ID-Renames (Save-/Mod-Breaking)
