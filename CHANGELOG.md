# Changelog

Alle nennenswerten Änderungen werden hier dokumentiert.
Format an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/)
angelehnt; SemVer ab 1.0.0.

## [Unreleased]

(noch keine Änderungen seit 0.0.4)

---

## [0.0.4] - 2026-05-06

> **Phase 2 — Spielbarer Mini-Game-Loop.** Combat-Interaktion, sichtbare
> Welt, Auto-Spawn, vollständige Run-Schleife. F5 zeigt jetzt ein
> echtes (wenn auch minimal-rendered) Survivor-likes-Spiel: Player läuft,
> Raptoren folgen, Damage fließt sichtbar, Tod öffnet Game-Over-Screen,
> Enter startet neuen Run.
>
> 5 neue ADRs (0011, 0013, 0017, 0018, 0019), 3 neue Test-Files, 44 neue
> Tests, +2474 Zeilen.
>
> Was fehlt für Vertical-Slice: HUD, Damage-Numbers, Mutation-Pick-Phase,
> Sprites — Phase 2.5 / Phase 3.

### Added
- **ADR 0019:** Game-Over-Overlay + Run-Restart — Loop ist geschlossen.
  Tod → Overlay → Enter → neuer Run.
- `core/ui/game_over.gd` + `.tscn` — CanvasLayer-Overlay über der
  Run-Scene, zeigt Reason / Time / Wave-erreicht.
- `core/run_scene/run.gd` erweitert um:
  - run_ended-Listener → Overlay einblenden
  - _input mit `restart`-Action + Guard auf RunState.is_ended()
  - `restart_run()` als headless-aufrufbarer Test-Hook
  - `_spawn_player_and_start()` als geteilter Setup-Pfad
- `core/run_scene/run.tscn` — GameOverLayer als Child instantiiert.
- `project.godot` — Input-Action `restart` (Enter + R).
- `tests/unit/test_game_over.gd` — 6 Tests (Visibility, Stats-Format).
- `tests/unit/test_run_scene.gd` erweitert um 4 Restart-Tests.

### Was sich verändert hat
- F5 hat jetzt einen vollständigen Spielloop:
  Run starten → kämpfen → sterben → Game-Over-Overlay → Enter → neuer Run

### Test-Suite
- 20 Scripts, 227 Tests, 434 Asserts — alle grün.

### Added
- **ADR 0013:** Auto-Spawn-Curves v1 (prozedural) — WaveSpawner spawnt
  selbst, mit Welle-skalierender Rate. Endloser Mini-Game-Loop.
- `core/wave_spawner.gd` erweitert um:
  - Konstanten: BASE_SPAWN_RATE, SPAWN_RATE_PER_WAVE, MAX_SPAWN_RATE,
    SPAWN_RADIUS_FROM_PLAYER
  - `_physics_process` mit Auto-Spawn-Tick (no-op wenn inactive)
  - `_tick_auto_spawn(delta)` als pure Test-Hook
  - `_do_auto_spawn()` — wählt Position + ruft spawn_enemy_at
  - `_spawn_rate_for_wave(idx)` linear + cap
  - `_enemy_id_for_wave(idx)` — v1 nur raptor_grunt
  - `_random_spawn_position()` — Player-relative Kreis
- `tests/unit/test_wave_spawner.gd` erweitert um 9 Auto-Spawn-Tests:
  Curve, Cap, Tick, Inactive-Skip, Run-End-Cleanup, Player-Center.

### Was sich verändert hat
- F5 zeigt jetzt einen **endlosen** Mini-Game-Loop:
  - Welle 1 (0.5/s) → Welle 2 (0.8/s) → ... → Welle 16+ (5.0/s cap)
  - Spawn-Position 400px außerhalb des Players (zufälliger Winkel)
  - Bei player_died stoppt Auto-Spawn

### Test-Suite
- 19 Scripts, 217 Tests, 420 Asserts — alle grün.

### Added
- **ADR 0018:** Visueller Stub + HP-Bar — Spiel ist erstmals
  visuell sichtbar bedeutungsvoll. Player als gelber Quadrat,
  Enemies als rote Quadrate, HP-Bars über jedem Mob reagieren in
  Echtzeit auf Damage.
- `core/ui/health_bar.gd` + `.tscn` — wiederverwendbare HealthBar-
  Komponente mit `set_health()`-API, lauscht auf damage_taken/healed/
  died, versteckt sich bei Tod.
- `core/player/player_character.tscn` + `.gd` — gelber Body
  (ColorRect 24×24), HealthBar-Child mit grüner Bar.
- `core/enemy/enemy_mob.tscn` + `.gd` — roter Body (ColorRect 16×16),
  HealthBar-Child mit oranger Bar.
- `tests/unit/test_health_bar.gd` — 8 Tests (Damage/Heal/Death/Re-bind).

### Was sichtbar wird
- F5 zeigt jetzt: Player läuft, Enemies bewegen sich, HP-Bars zeigen
  Schäden, tote Mobs bleiben liegen ohne Bar.
- Mutationen wirken sichtbar: ankylosaur_plates erhöht max_hp →
  HP-Bar bleibt länger voll.

### Test-Suite
- 19 Scripts, 208 Tests, 406 Asserts — alle grün.

### Added
- **ADR 0011:** Hit-Detection v1 (distanz-basiert) — erstmals
  tatsächliches Mini-Spiel: Player schlägt Enemies, Enemies fügen
  Touch-Damage zu.
- `core/player/player_character.gd` erweitert um:
  - `_update_hit_detection(delta)` als Tick im _physics_process
  - `_do_auto_attack()` — alle Enemies in attack_range damagen
  - `_check_touch_damage()` — Touch vom nähesten Enemy + iframes
  - `is_invulnerable()`, `get_attack_range()`-API
- `core/enemy/enemy_mob.gd` — Group-Konvention `&"enemy"`.
- `core/player/player_character.gd` — Group-Konvention `&"player"`.
- `tests/unit/test_hit_detection.gd` — 11 dedizierte Tests inkl.
  Mutation-Pipeline-Roundtrip, iframes-Lifecycle, Cross-Mutation-Check.

### Bewusste Designentscheidungen
- **KEIN Area2D / Physics**: pure Distanz-Math hält Tests deterministisch.
  Refactor zu Area2D bleibt offen falls Performance es verlangt.
- **iframes als globaler Player-Timer**, nicht per-Enemy-Cooldown —
  Multi-Player-Variante kommt mit eigenem ADR.
- **Touch-Damage vom nähesten Enemy** statt allen Enemies — sonst
  wird Player in einem Frame von einem Schwarm ausradiert.

### Test-Suite
- 18 Scripts, 194 Tests, 387 Asserts — alle grün (Hit-Detection-Pass).

- **ADR 0017:** Enemy-Movement v1 (Direkt-Walk) — Enemies laufen
  aktiv auf den nähesten Player zu. Spiel ist tatsächlich spielbar.
- `core/enemy/enemy_mob.gd` erweitert um:
  - `_physics_process(delta)` mit Movement-Tick + Death-Guard
  - `_move_toward_player(delta)` — pure Vector-Math, testbar
  - `_find_nearest_player()` — Group-Lookup mit Multi-Player-Support
  - `get_speed()` aus EnemyDef.speed
- `tests/unit/test_enemy_mob.gd` erweitert um 6 Movement-Tests:
  Direkt-Walk, Speed-aus-Def, Death-Guard, No-Player-Edge,
  Nähester-Player, Overlap-No-Movement.

### Bewusste Einschränkungen
- KEIN Physics (move_and_slide, Avoidance) — pure Distanz-Math
- KEIN NavMesh / Pathfinding — Direkt-Walk reicht für Survivor-likes
- KEIN AI-State-Machine — Backlog für Boss-Patterns

### Test-Suite
- 18 Scripts, 200 Tests, 396 Asserts — alle grün.

### Spiel-Status
- Mini-Spielbar: Player läuft mit WASD, Raptoren folgen automatisch,
  Auto-Attack + Touch-Damage + iframes greifen, Mutationen wirken.

### Gotcha aufgedeckt
- **Group-Pollution zwischen Test-Suites:** `queue_free()` ist async,
  Group-Membership lebt einen Frame länger. Bei Tests, die
  `get_nodes_in_group()` nutzen, im before_each explizit
  `remove_from_group()` für Pollution-Schutz aufrufen.
  → eingetragen in `agents/memory/godot-implementer/gotchas.md`.

---

## [0.0.3] - 2026-05-06

> **Phase 1 vollständig — Game ist erstmals bootbar.** Alle Logik-
> Pipelines (Lifecycle, Combat, Modifier, Bridge, Aggregation,
> Player-Char-Scene, Enemy-Spawn, Run-Scene-Glue) sind implementiert
> und End-to-End headless verifiziert. F5 in Godot startet einen
> Run mit Trex-Player und Demo-Spawn-Hook für Raptoren.
>
> 4 neue ADRs (0008, 0009, 0015, 0016), 5 neue Test-Files, 55 neue
> Tests, +2358 Zeilen. Erstmals 10k Zeilen total.
>
> Was fehlt für „spielbar": Hit-Detection, Sprites, HUD —
> Phase 2.

### Added
- **ADR 0015:** Player-Mutation-System (Aggregator) — sammelt gepickte
  Mutationen, aggregiert ihre stat_modifiers additiv über alle Picks,
  baut konsolidierte Modifier-Listen.
- `core/player_mutations.gd` — Autoload, Public-API
  (`pick`, `remove`, `reset`, `has`, `get_picked`, `get_aggregated`).
  Subscribed `run_started` → automatischer Reset zwischen Runs.
- `core/event_bus.gd` — neues Signal `mutations_changed()`.
  EventBus-Total: 21 Signals.
- `content/mutations/spinosaur_sail.tres` — Rare, +10% Crit / +50% Crit-Dmg.
- `content/mutations/ankylosaur_plates.tres` — Common, +20% Armor / +15% max HP.
- `tests/unit/test_player_mutations.gd` — 17 Tests inkl. additives
  Stacking, Cap-Verhalten, run_started-Reset, Cross-Mutation-Aggregation.
- BALANCE.csv + locale/{de,en}.po — 2 neue Mutationen ergänzt.
- 7. Autoload `PlayerMutations` in project.godot.

- **ADR 0008:** Player-Character-Scene + Movement — erste echte Scene
  im Repo. Generischer `PlayerCharacter` (CharacterBody2D), DinoDef-
  getrieben, Mutations-Hook, Component-Pattern wie ADR 0007.
- `core/player/player_character.gd` + `.tscn` — Scene mit Health- und
  Dealer-Children. Public-API: `set_dino`, `get_dino`,
  `get_health_component`, `get_dealer_component`, `get_effective_max_hp`,
  `get_effective_speed`, `_compute_velocity` (pure, testbar).
- `core/player/player_character.tscn` — Scene-Setup mit Komponenten.
- `content/dinos/trex.tres` — `character_scene` jetzt mit
  PackedScene-Reference auf `player_character.tscn`.
- `project.godot` — Input-Map mit `move_left/right/up/down` Actions
  (Keyboard WASD + Pfeile).
- `tests/unit/test_player_character.gd` — 17 Tests inkl. Komponenten-
  Setup, Movement-Math, Mutations-Hook, Damage-Roundtrip mit Player-Dealer.

### Was sichtbar wird
- Mutationen wirken jetzt auf einen tatsächlichen Player-Character —
  nicht mehr nur in isolierten Komponenten-Tests. End-to-End-Beispiel
  im Test: triceratops_horns (15% Damage) + ankylosaur_plates (20% Armor
  + 15% max HP) → Player-HP 138 statt 120, Player-Damage 17.25 statt 15.

- **ADR 0009:** Enemy-Mob-Pattern + Spawn-API — Vollständiger Kreis
  ContentLoader → Spawn → Combat → Death-Signal.
- `core/enemy/enemy_mob.gd` + `.tscn` — generischer Enemy, analog zu
  PlayerCharacter. EnemyDef-getrieben, enemy_id-Convention erfüllt.
- `core/wave_spawner.gd` — `set_spawn_root`, `get_spawn_root`,
  `spawn_enemy_at(enemy_id, pos)` ergänzt. DEFAULT_ENEMY_SCENE
  als Fallback wenn EnemyDef.scene null ist.
- `content/enemies/raptor_grunt.tres` — `scene`-Reference auf
  `enemy_mob.tscn`.
- `tests/unit/test_enemy_mob.gd` — 11 Tests (Scene-Setup, setup-API,
  Death-Pfad). `test_wave_spawner.gd` um 4 Spawn-Tests erweitert.

### Kreis verifiziert
- Test `test_death_emits_enemy_died_with_correct_id`:
  ContentLoader.get → setup → take_damage(999) → EventBus.enemy_died
  mit `&"raptor_grunt"` und korrekter Position.

- **ADR 0016:** Run-Scene-Glue — Glue-Scene zwischen Logik und Sicht.
  Erstmals **bootbar**: F5 in Godot startet einen Run mit Trex-Player
  und 3 spawn-baren Raptoren.
- `core/run_scene/run.gd` + `.tscn` — `main_scene`, Container-Konvention
  (`PlayerSlot` + `EnemyContainer`), defensive Re-Entry-Logik bei
  Hot-Reload. Test-Hook `_spawn_demo_enemies()` für visuelle Verifikation.
- `project.godot` — `run/main_scene = res://core/run_scene/run.tscn`.
- `tests/unit/test_run_scene.gd` — 7 Tests inkl. End-to-End-Setup,
  WaveSpawner-Wiring, RunState-Trigger, Demo-Spawn, Edge-Case mit
  ungültiger dino_id.

### Was zum ersten Mal funktioniert
- `godot --path . --main-scene res://core/run_scene/run.tscn` (oder F5
  im Editor) startet eine spielbare Run-Szene.
- Player + EnemyContainer + Run-Lifecycle + Mutations-Pipeline +
  Spawn-API laufen End-to-End in einer einzigen Scene zusammen.

### Test-Suite
- 17 Scripts, 183 Tests, 367 Asserts — alle grün.

### Notes for Modders
- Neuer Public-API-Touchpoint: `EventBus.mutations_changed` — feuert
  nach jedem Pick/Remove/Reset.
- `PlayerMutations.get_aggregated()` liefert bereits additiv gestackte
  Modifier — Mods, die individuelle Picks brauchen, nutzen
  `get_picked()`.

---

## [0.0.2] - 2026-05-06

> **Phase 1 — Lifecycle + Combat + Modifier + Bridge.** Alle Game-Math-
> Pipelines stehen und sind End-to-End headless verifiziert. Mutationen
> aus dem `content/`-Ordner sind ab dieser Version mathematisch wirksam.
> 4 neue ADRs, 7 neue Test-Files, 99 neue Tests.

### Added
- **ADR 0005:** Mod-Loader & mod.json-Schema — explicit lifecycle für Mods,
  Manifest-Validierung, Failure-Isolation pro Mod.
- `core/mod_loader.gd` — Autoload, Public-API
  (`discover`, `list_active`, `get_manifest`, `is_loaded`, `failed_mods`).
- `tests/unit/test_mod_loader.gd` — 10 Tests, 17 Asserts.
- `tests/fixtures/mods/{example_mod, broken_mod, wrong_schema_mod}/` —
  Test-Mod-Fixtures für Discovery, Manifest-Validation und Failure-Modi.
- `docs/MODDING.md` — Mod-Author-Anleitung mit mod.json-Schema, Override-
  Regeln, EventBus-Subscribe, Failure-Modi, Compat-Versprechen.
- `agents/memory/mod-api-curator/public-api-surface.md` — vollständiger
  Public-API-Snapshot (18 Signals, ContentLoader-API, Resource-Schemas,
  mod.json-Schema, Save-Format, Pfad-Konventionen).
- `project.godot` — `ModLoader` als 4. Autoload (Reihenfolge:
  EventBus → ContentLoader → SaveSystem → ModLoader).

- **ADR 0006:** Run-Lifecycle, Wave-Spawner & Dino-Resources — erstes
  echtes Game-System auf der Public-API.
- `core/content/dino_def.gd` — Player-Char-Schema (health, speed, damage,
  attack_rate, pickup_radius, character_scene).
- `core/run_state.gd` — Autoload, State-Maschine (IDLE/RUNNING/ENDED),
  Public-API: `start`, `end`, `reset`, `is_running`, `is_idle`, `is_ended`,
  `get_active_dino`, `get_run_time`, `get_current_wave`, `get_last_end_reason`.
- `core/wave_spawner.gd` — Autoload, Logik-Skelett für Wave-Timer ohne
  Spawns. Public-API: `set_wave_duration`, `get_wave_duration`, `is_active`,
  `current_wave`.
- `content/dinos/trex.tres` — erste DinoDef (Allrounder, 120 HP / 15 DMG).
- `core/content_loader.gd` — neuer Type `dino` in TYPE_CONFIG.
- `core/event_bus.gd` — 2 neue Signals: `run_started(dino_id)`,
  `run_ended(reason, run_time)`. Total: 20 Signals.
- `tests/unit/test_dino_def.gd` + `test_run_state.gd` + `test_wave_spawner.gd`
  — 26 neue Tests (zusätzlich zu den 39 vorhandenen).
- `locale/{de,en}.po` — `dino.trex.name` / `dino.trex.tooltip` Stubs.
- `BALANCE.csv` — trex-Eintrag.

### Test-Suite
- 7 echte Test-Scripts, 65 Tests, 149 Asserts — alle grün.
- Test-Pipeline-Lerneintrag im `gotchas.md`: **Class-Cache-Stale-Issue**
  nach Anlegen neuer `class_name`-Klassen muss vor Tests
  `godot --headless --import` laufen, sonst Parse-Errors.

- **ADR 0007:** Combat-Pipeline mit Component-Pattern und DamageInfo-Resource.
  Hot-Path-Trennung: take_damage als direkter Call, Bus nur für bedeutsame
  Events.
- `core/combat/damage_info.gd` — Resource (amount, damage_type, source_id,
  is_crit, pierce_armor). Convenience-Factory `DamageInfo.make()`.
- `core/components/health_component.gd` — HP-Container mit lokalen Signals
  (damage_taken, healed, died) und globaler Bus-Notify (player_damaged,
  player_died, enemy_died).
- `core/components/damage_dealer_component.gd` — Hook-Punkt für Modifier-
  Pipeline (kommt mit ADR 0010), default_source_id-Substitution.
- `content/enemies/raptor_grunt.tres` — erster Enemy (25 HP / 8 DMG / 120 Speed).
- `tests/unit/test_damage_info.gd` + `test_health_component.gd` +
  `test_damage_dealer.gd` — 27 neue Tests.
- `BALANCE.csv` — raptor_grunt-Eintrag.
- `locale/{de,en}.po` — `enemy.raptor_grunt.*` keys.
- `agents/memory/mod-api-curator/public-api-surface.md` — neuer Abschnitt
  „Combat-Komponenten" mit DamageInfo-Schema, HealthComponent- und
  DamageDealer-API. Public-API ist jetzt 4-fach dokumentiert.

### Test-Suite
- 11 Scripts (10 echte + 1 leerer Slot), 92 Tests, 193 Asserts — alle grün.

- **ADR 0010:** Modifier-Pipeline (Crit, Bonus, Multiplier, Armor) —
  daten-getriebene Modifikatoren, Pure-Function-Konvention, Priority-Sort.
- `core/combat/damage_modifier.gd` — Base-Resource (priority + apply).
- `core/combat/modifiers/{flat_bonus,multiplier,crit,armor}_modifier.gd`
  — vier konkrete Modifier-Klassen.
- `core/components/damage_dealer_component.gd` — `outgoing_modifiers`
  + `add_modifier`/`remove_modifier` + Sort-Cache.
- `core/components/health_component.gd` — `incoming_modifiers` + selbe
  API. Modifier werden VOR HP-Reduce angewandt.
- `tests/unit/test_modifiers.gd` — 22 Tests inkl. Pure-Function-Garantie,
  Priority-Sort, RNG-Determinismus, Chain auf beiden Komponenten.
- `agents/memory/mod-api-curator/public-api-surface.md` — Modifier-API
  als Public-Surface dokumentiert.

### Test-Suite
- 12 Scripts, 114 Tests, 224 Asserts — alle grün.

- **ADR 0014:** Mutation→Modifier-Bridge — verbindet
  `MutationDef.stat_modifiers` mit der Modifier-Pipeline aus ADR 0010.
  Pure-Function `MutationModifierBridge.build(mut)` erzeugt typisierte
  Modifier-Resourcen.
- `core/combat/mutation_modifier_bridge.gd` — statische Klasse,
  KNOWN_OUTGOING/KNOWN_INCOMING-Konstanten als Public-API,
  build()-Function mit Edge-Case-Handling für null/empty/unbekannte stats.
- `tests/unit/test_mutation_modifier_bridge.gd` — 14 Tests inkl.
  Pure-Function-Garantie + End-to-End-Smoke gegen triceratops_horns.
- `agents/memory/mod-api-curator/public-api-surface.md` — Bridge-API
  als Public-API dokumentiert.

### Was jetzt funktioniert
- `triceratops_horns.tres` ist mathematisch wirksam: `damage_pct=0.15`
  → MultiplierModifier(1.15) outgoing → 10 Damage wird zu 11.5
  beim Target. End-to-End verifiziert.

### Test-Suite
- 13 Scripts, 128 Tests, 263 Asserts — alle grün.

### Notes for Modders
- Mods brauchen jetzt eine `mod.json` (siehe `docs/MODDING.md`).
  Verzeichnisse ohne Manifest werden ignoriert.
- Reservierter ID-Präfix `core_*` für Mods nicht zulässig.
- Public-API ist mit v0.0.1 stabilisiert (Patch- und Minor-Compat-Versprechen
  siehe MODDING.md).

---

## [0.0.1] - 2026-05-06

> **Phase-0-Skelett** — internal tag, kein Public-Release. Architektonische
> Grundlagen (EventBus, ContentLoader, SaveSystem) stehen, sind getestet
> und über CI verifiziert.

### Added
- **Phase 0a:** 13 Project-Scope Sub-Agents in `.claude/agents/`
  (game-architect, game-designer, content-author, lore-writer,
  godot-implementer, shader-fx-specialist, code-reviewer, test-engineer,
  balance-analyst, save-migration-specialist, mod-api-curator,
  release-manager, localization-coordinator).
- **ADR 0001:** Globaler EventBus als zentrales Nervensystem
  (Autoload-Singleton mit getypten Signals).
- `core/event_bus.gd` — initialer Signal-Set für Combat, Wave/Spawn,
  Mutation, Meta-Progression, Save/Lifecycle, Modding.
- `tests/unit/test_event_bus.gd` — gut-Unit-Tests (Surface- und Verhaltens-
  Checks).
- `tests/scenes/test_event_bus.tscn` — manuelle Smoke-Test-Scene.
- `docs/ARCHITECTURE.md` — Architektur-Hauptdokument mit 7 Prinzipien.
- `project.godot` — minimale Godot-4-Projekt-Datei mit EventBus-Autoload.

- **ADR 0003:** ContentLoader & Resource-Konventionen — eager Discovery,
  Type-Class-Validation, ID-Uniqueness, Mod-Override-Handling.
- `core/content_loader.gd` — type-indizierte Registry, Public-API
  (`get_item`, `get_or_null`, `get_all`, `has_item`, `types`,
  `all_ids`, `overrides_applied`, `reload`).
- `core/content/{content_item,mutation_def,enemy_def,boss_def}.gd` —
  Resource-Schemas mit `validate()`-Hook.
- `content/mutations/triceratops_horns.tres` — erste echte Mutation
  als End-to-End-Pipeline-Validation.
- `locale/de.po`, `locale/en.po` — i18n-Stubs vom localization-coordinator.
- `BALANCE.csv` — initialisiert mit erstem Mutation-Eintrag.
- `docs/CONTENT.md` — Procedure für content-author + Mod-Authoren.
- EventBus erweitert um `content_loaded(type_count, item_count)`.

- **ADR 0002:** Save-System & Schema-Versionierung — JSON-Persistenz,
  atomic-write, Migrations-Pipeline, ContentLoader-Ref-Validation.
- `core/save_system.gd` — Autoload, Public-API
  (`save`, `load_save`, `get_data`, `set_field`, `delete_save`,
  `has_save_file`, `export_path`).
  Subscribet `EventBus.save_requested`, emittet `save_completed` und
  `save_loaded(version)` (mit Original-Version VOR Migration).
- `core/save_migrations/_migration.gd` + `_runner.gd` — Konvention und
  sequenzieller Migrations-Aufrufer.
- `tests/unit/test_save_system.gd` — Roundtrip, set_field, EventBus-Hook,
  Migration-Runner-Verhalten.
- `tests/fixtures/save_v1.json` — Reference-Fixture für künftige
  Migration-Tests.
- `project.godot` — `SaveSystem` als drittes Autoload, `config/version`
  ergänzt für Save-Header.

- **Test-Pipeline:** GUT 9.4.0 als Submodul-frei eingecheckt unter
  `addons/gut/`. Tests laufen headless via `tools/run_tests.sh`
  (POSIX) oder `tools/run_tests.ps1` (Windows).
- **CI:** `.github/workflows/test.yml` — Godot 4.3 headless + GUT-Run
  auf push/PR.
- **Test-Suite:** 3 Scripts, 29 Tests, 80 Asserts — alle grün
  (Stand: 2026-05-06).
- Lambda-Capture-Bugs in EventBus-Tests durch GUT's `watch_signals` +
  `assert_signal_emitted_with_parameters` ersetzt — GDScript-Lambdas
  haben keine Closure-Write-Through-Semantik.

### Save-Format (v1)
- Pfad: `user://saves/save.json`
- Backup: `user://saves/save_previous.json` (vor jedem Save)
- Migration-Backups: `user://saves/save_backup_v<n>.json`
- Schema-Doku in `agents/memory/save-migration-specialist/save-schema-history.md`

### Notes for Modders
- ContentLoader ist die zweite Public-API-Fläche neben EventBus.
  Mods leben unter `user://mods/<mod_id>/content/<type>/`.
- Override eines Core-Items via `override_existing = true` im Mod-Resource;
  Loader emittiert Warning und sammelt in `ContentLoader.overrides_applied()`.
- Save-Format (v1) ist JSON und damit Save-Editor-Mod-tauglich.
  schema_version ist erstes Feld, save_backup_v<n>.json sind Migration-Backups.
