extends Node
## Globaler EventBus — zentrales Nervensystem von DinoRogue.
##
## Implementiert ADR 0001. Reine Signal-Drehscheibe ohne Logik.
## Producer feuern Signals via `EventBus.<signal>.emit(...)`,
## Consumer verbinden in `_ready()` mit `EventBus.<signal>.connect(...)`.
##
## REGELN (verbindlich):
##   - Signal-Namen: <noun>_<past-tense-verb> (z.B. enemy_died)
##   - Maximal 3 Parameter pro Signal, alle getypt
##   - Keine Hot-Path-Events (>100×/s) — solche Events laufen direkt zwischen
##     Komponenten, NICHT über den Bus
##   - Alle Signals zählen als Public-API für Mods. Renames sind Breaking
##     Changes — vor jeder Änderung mod-api-curator konsultieren.
##
## Lebenszyklus:
##   Bei Lambdas IMMER `disconnect()` im `_exit_tree()` der Subscriber-Node
##   aufrufen. Bei Method-Refs erledigt Godot das automatisch beim Free.

# ---------------------------------------------------------------------------
# --- Combat ---
# ---------------------------------------------------------------------------
## Gegner ist gestorben. Quelle: Damage-System.
signal enemy_died(enemy_id: StringName, position: Vector2)

## Spieler hat Schaden bekommen. NICHT für Hot-Path-Streaming gedacht —
## nur signifikante Damage-Ticks (Boss-Treffer, Burst-Damage).
signal player_damaged(amount: float, source_id: StringName)

## Spieler ist gestorben — leitet Run-Ende ein.
signal player_died()

# ---------------------------------------------------------------------------
# --- Wave / Spawn ---
# ---------------------------------------------------------------------------
## Eine neue Welle hat begonnen.
signal wave_started(wave_index: int, difficulty: float)

## Welle ist abgeräumt — alle Gegner tot oder Timer abgelaufen.
signal wave_cleared(wave_index: int)

## Boss wurde gespawnt — UI/Music/VFX hängen sich hier rein.
signal boss_spawned(boss_id: StringName, position: Vector2)

## Boss besiegt. `run_time` ist Sekunden seit Run-Start.
signal boss_defeated(boss_id: StringName, run_time: float)


# ---------------------------------------------------------------------------
# --- Run-Lifecycle ---
# ---------------------------------------------------------------------------
## Run beginnt mit dem gewählten Dino. Reset von Per-Run-State der Listener.
signal run_started(dino_id: StringName)

## Run endet (Spieler tot, Quit, finaler Boss). `run_time` in Sekunden.
signal run_ended(reason: StringName, run_time: float)

# ---------------------------------------------------------------------------
# --- Mutation / Build ---
# ---------------------------------------------------------------------------
## Mutations-Auswahl wird dem Spieler angeboten.
signal mutation_offered(choices: Array)

## Spieler hat eine Mutation ausgewählt.
signal mutation_picked(mutation_id: StringName)

## Aggregator hat sich geändert (pick/remove/reset). Listener
## bauen ihre Modifier-Stacks neu. Siehe ADR 0015.
signal mutations_changed()

# ---------------------------------------------------------------------------
# --- Meta-Progression ---
# ---------------------------------------------------------------------------
## XP gesammelt — getrennt von Currency, da XP ein Run-internes Konzept ist.
signal xp_gained(amount: int)

## Player-Level erhöht.
signal level_up(new_level: int)

## Persistente Währung hat sich geändert (Bernstein, Forschung, etc.).
signal currency_changed(currency: StringName, new_value: int)

# ---------------------------------------------------------------------------
# --- Save / Lifecycle ---
# ---------------------------------------------------------------------------
## Save anfordern. `reason` z.B. "auto", "menu_quit", "wave_end".
## Game-Code feuert NIE direkt SaveSystem.save() — immer dieses Signal.
signal save_requested(reason: StringName)

## Save erfolgreich auf Disk geschrieben.
signal save_completed()

## Save erfolgreich geladen. `schema_version` ist die Version VOR Migration.
signal save_loaded(schema_version: int)

# ---------------------------------------------------------------------------
# --- Modding ---
# ---------------------------------------------------------------------------
## Mod wurde erfolgreich geladen.
signal mod_loaded(mod_id: StringName)

## Mod konnte nicht geladen werden. `error` ist Dev-/Log-String, NICHT
## User-facing — UI-Strings liefert localization-coordinator.
signal mod_failed(mod_id: StringName, error: String)



# ---------------------------------------------------------------------------
# --- Content / Boot ---
# ---------------------------------------------------------------------------
## ContentLoader hat alle Resources gescannt und registriert.
## `type_count` = Anzahl Types (Mutationen, Gegner, …),
## `item_count` = Summe aller registrierten Einträge.
signal content_loaded(type_count: int, item_count: int)

# ---------------------------------------------------------------------------
# --- Debug-Hilfen ---
# ---------------------------------------------------------------------------

## Liefert die Liste aller deklarierten Signal-Namen. Nützlich für
## EventRecorder, Test-Scenes und Modding-Doku-Generatoren.
func list_signals() -> Array[String]:
	var names: Array[String] = []
	for sig in get_signal_list():
		names.append(sig["name"])
	return names

## Loggt jedes Signal mit Argumenten in den Output. NUR für Debug-Sessions.
## Nicht in Release-Builds aktivieren — Performance-Kosten.
func enable_debug_logging() -> void:
	for sig in get_signal_list():
		var sig_name: String = sig["name"]
		var cb := func(_a = null, _b = null, _c = null) -> void:
			print("[EventBus] %s args=(%s, %s, %s)" % [sig_name, _a, _b, _c])
		connect(sig_name, cb)
