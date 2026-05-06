# Engine-Gotchas

> Vom `godot-implementer` gepflegt. Engine-Quirks die uns schon gebissen haben.

## Signal-Lifecycles

- **Method-Refs** (`signal.connect(self.method)`) werden bei `queue_free()`
  automatisch disconnected.
- **Lambdas** werden NICHT automatisch disconnected. Beim Subscriber im
  `_exit_tree()` selbst `disconnect()` aufrufen — sonst Leaks und
  Aufrufe an freigegebene Objekte.

## Autoload-Reihenfolge

`EventBus` MUSS vor allen anderen Autoloads stehen, die Signals abonnieren
wollen — sonst läuft `connect()` ins Leere. Reihenfolge in
`project.godot` unter `[autoload]` zählt.

## StringName vs String

Signal-Argumente, IDs und i18n-Keys nutzen `StringName` (`&"foo"`), nicht
`String`. Vergleiche sind O(1), Hash-stabil, weniger Allocations.

## (noch keine weiteren Einträge)

## Resource-Loading & Hot-Reload

- Godot's ResourceLoader cached `.tres`-Files. Bei Code-Änderungen an
  Resource-Schemas im Editor: Engine-Restart sicherstellen, sonst sieht
  man alte Daten. ContentLoader.reload() ist Dev-Hilfe, nicht Allheilmittel.
- Script-Vergleich von Resources: NIEMALS class_name-Strings vergleichen
  (fragil), sondern `script.resource_path` durch `get_base_script()`-Kette
  walken. So macht es ContentLoader._script_matches().

## DirAccess Mod-Pfade

- `user://` ist auf Linux/macOS in `~/.local/share/godot/app_userdata/<name>/`,
  auf Windows in `%APPDATA%\Godot\app_userdata\<name>\`. Mod-Authoren
  müssen das wissen — wird in MODDING.md dokumentiert sobald Mod-Loader steht.
- `DirAccess.dir_exists_absolute()` ist günstiger als `open()` + null-check;
  fehlende Mod-Verzeichnisse sind erwartet (kein Fehler-Warning).

## GUT-Helper-Returns sind untyped

Beim Schreiben von Tests darauf achten:

```gdscript
# Falsch — Parse-Error: "Cannot infer the type of 'params'"
var params := get_signal_parameters(EventBus, "foo")
var count := get_signal_emit_count(EventBus, "foo")

# Richtig — explizite Typ-Annotation
var params: Array = get_signal_parameters(EventBus, "foo")
var count: int = get_signal_emit_count(EventBus, "foo")
```

Symptom: `Failed to load script ... Parse error` und ein lautloses
`Ignoring script ... because it does not extend GutTest`.
Das Test-File wird einfach ausgelassen, ohne dass die Suite rot wird —
sehr leise, leicht zu übersehen!

Cross-Check: nach Test-Lauf-Output `Scripts N` mit erwarteter Anzahl
abgleichen. Wenn `N` weniger ist als erwartet → ein Test-File hatte
einen Parse-Error.

## GDScript-Lambdas haben keine Closure-Write-Through-Semantik

```gdscript
# Falsch — captured bleibt nach dem emit() unverändert
var captured: int = -1
var cb := func(v: int): captured = v
EventBus.foo.connect(cb)
EventBus.foo.emit(42)
assert(captured == 42)  # FAILS

# Richtig — GUT's idiomatisches Pattern
watch_signals(EventBus)
EventBus.foo.emit(42)
assert_signal_emitted(EventBus, "foo")
var params: Array = get_signal_parameters(EventBus, "foo")
assert(params[0] == 42)

# Alternativ — Member-Variable ODER Array-by-ref
var _received: Array = []
func test_x():
    EventBus.foo.connect(_received.append)  # by-ref Mutation
    EventBus.foo.emit(42)
    assert(_received[0] == 42)
```

GDScript-Lambdas können äußere Variablen LESEN (capture by value), aber
Schreibzugriffe wirken nicht zurück. Member-Variables und Arrays
funktionieren wegen By-Reference-Semantik.


## GDScript-Type-Inferenz scheitert bei dict.get()-Returnwerten

```gdscript
# Falsch — Parse-Error: "Cannot infer the type of 'x' variable"
var x := float(my_dict.get("key", 0.0))

# Richtig — explizite Annotation
var x: float = float(my_dict.get("key", 0.0))
```

Tritt auf, weil `Dictionary.get()` Variant zurückgibt und `float()` davon
nicht statisch Typ-inferiert. Selbe Klasse Bug wie bei GUT-Helper-Returns.
Faustregel: **bei jedem `:=` mit `dict.get(...)` oder GUT-Helpern lieber
Typ explizit annotieren.**


## Group-Pollution zwischen Test-Suites

`queue_free()` ist async — Nodes verschwinden erst beim nächsten
process_frame. **Group-Membership** wird gleichzeitig erst dann
freigegeben. Folge: Tests, die `get_tree().get_nodes_in_group(&"foo")`
nutzen, sehen Mobs aus vorigen Suites, die noch GC-warten.

```gdscript
# Falsch — Test sieht Group-Reste vom vorigen Test
func before_each() -> void:
    spawn_my_enemy()
    var hits := player._do_auto_attack()  # findet auch alte Enemies!

# Richtig — explizit aus Group entfernen vor dem Test
func before_each() -> void:
    for node in get_tree().get_nodes_in_group(&"enemy"):
        if is_instance_valid(node):
            node.remove_from_group(&"enemy")
    spawn_my_enemy()
    var hits := player._do_auto_attack()  # nur eigene Mobs
```

Symptom: Tests laufen isoliert grün, in der Suite rot. Faustregel:
**bei jedem before_each, das Group-Lookups macht, vorher die Group cleanen.**
