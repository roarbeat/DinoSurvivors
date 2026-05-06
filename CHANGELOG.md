# Changelog

Alle nennenswerten Änderungen werden hier dokumentiert.
Format an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/)
angelehnt; SemVer ab 1.0.0.

## [Unreleased]

(noch keine Änderungen seit 0.4.0)

---

## [0.4.0] - 2026-05-06

> **Phase 6 — Content-Erweiterung + Mood-Reference-Approximation.**
> Map sieht erstmals nach erhabener Plattform aus (Dirt-Sides +
> Decorations + Charcoal-Background). Player ist als grüner Raptor
> erkennbar. Zweiter Boss (Triceratops Charge) auf Welle 10/20.
> Zweite Map (Forest Clearing 12×12) liegt im Content-Pool. Drei
> spielbare Dinos (trex always-unlocked, velociraptor + stegosaurus
> via Bernstein-Käufe). Multi-Tab-Shop mit STATS/DINOS.
>
> 4 neue ADRs (0041 Visual-Polish, 0042 Raptor-Composite, 0043
> Triceratops+Forest, 0044 Multi-Dino+Tab-Shop). Modder-Surface ist
> jetzt 8 ContentLoader-Types + 24 EventBus-Signals.
>
> Save-Schema bleibt v1.2 — keine Migration nötig. Saves von 0.0.x
> bis 0.4.0 laden alle sauber.

### Added
- **ADR 0044:** Multi-Dino + Multi-Tab-Shop — drei spielbare Dinos
  (trex/velociraptor/stegosaurus), Multi-Tab-Shop mit STATS und
  DINOS-Tabs.
- `core/content/upgrade_def.gd` — `+ category: StringName = &"stat"`,
  `+ unlock_dino_id: StringName`.
- `core/content/dino_def.gd` — `+ unlock_upgrade_id: StringName`.
- `core/meta_progression.gd` — `+ is_dino_unlocked(dino_id)`.
- `core/ui/shop_overlay.gd` — Multi-Tab-System (Tab-Bar mit STATS und
  DINOS, `set_tab()`/`get_tab()`-API, Filter via `def.category`).
- `core/run_scene/run.gd` — `_resolve_unlocked_dino_id()` Fallback.
- `content/dinos/velociraptor.tres` (80 HP / 240 Speed, 200 amber unlock)
- `content/dinos/stegosaurus.tres` (200 HP / 130 Speed, 300 amber unlock)
- `content/upgrades/dino_unlock_velociraptor.tres`
- `content/upgrades/dino_unlock_stegosaurus.tres`
- `tests/unit/test_multi_dino.gd` — 17 Tests.

### Spielfühl-Konsequenz (v0.4.0 gesamt)
- **Map sieht nach erhabener Plattform aus** (Dirt-Sides + Blumen
  + Crystals + Charcoal-Background) — Mood-Reference deutlich näher
- **Player als grüner Raptor erkennbar** statt gelbes Quadrat
- **Wechselnde Boss-Encounters**: T-Prime stomps, Triceratops charges
- **Loop ist tiefer**: Bernstein → Stat-Upgrades + Dino-Unlocks
- **Drei Spielstile**: Allrounder / Glaskanone / Tank

### Public-API additiv (v0.4.0 gesamt)
- `UpgradeDef.category`, `unlock_dino_id`
- `DinoDef.unlock_upgrade_id`
- `MetaProgression.is_dino_unlocked(dino_id)`
- `ShopOverlay.set_tab(tab)`, `get_tab()`, `current_tab` @export
- `BossCharge` Resource-Schema + `compute_charge_velocity` (static)
- `BossMob.start_charge(charge)`, `is_charging()`
- `IsoWorld.decoration_density`, `side_face_depth`
- ContentLoader hat **8 Types**, **3 Dinos**, **2 Bosse**, **2 Maps**

### Project-Version
- `config/version` von `0.2.0` → **`0.4.0`**

---

### Added
- **ADR 0043:** Zweiter Boss + Zweite Map — Modder-Surface validiert
  durch eigenen Boss + Map nur via .tres-Files (kein Code-Touch).
- `core/content/abilities/boss_charge.gd` — `BossCharge extends BossAbility`
  mit `charge_speed`, `charge_duration`, `damage`. Pure-Function-
  `compute_charge_velocity(boss_pos, player_pos, speed)`.
- `content/bosses/triceratops_charge.tres` — neuer Boss:
  - 1000 HP / 75 Bernstein
  - Phase 1 Mid (66%): Charge cd=8s, 30 dmg
  - Phase 2 Rage (33%): Charge cd=5s, 40 dmg, schneller
  - Tint braun, etwas schneller im Endgame
- `content/maps/forest_clearing.tres` — 12×12 Map mit
  decoration_density implizit (lese aus IsoWorld), camera_padding (60,40)
- `content/waves/wave_10_triceratops.tres` — überschreibt Welle 10
  von T-Prime auf Triceratops (alte ID wave_10_tyrannosaurus jetzt
  als wave_25_tyrannosaurus für target_wave_index=25)
- `content/waves/wave_15_tyrannosaurus.tres` — Welle 15 → T-Prime
- `content/waves/wave_20_triceratops.tres` — Welle 20 → Triceratops
- `core/boss/boss_mob.gd` erweitert um:
  - `_charge_state: Dictionary` (velocity, remaining, damage)
  - `start_charge(charge: BossCharge)` — Public-API von Ability gerufen
  - `_apply_charge_movement(delta)` — überschreibt Direkt-Walk
  - `is_charging()` — Test-/UI-Hook
- `tests/unit/test_boss_charge.gd` — 14 Tests (Pure-Math,
  Boss-Wiring, Charge-State, Wave-Rotation, Map-Loading).
- locale/{de,en}.po um Triceratops + Forest-Clearing-Keys.
- BALANCE.csv um 2 neue Einträge (jetzt 30 total).

### Boss-Wave-Rotation
- Welle 5: T-Prime (Stomp in Rage)
- Welle 10: Triceratops (Charge in Mid + Rage)
- Welle 15: T-Prime
- Welle 20: Triceratops
- Welle 25: T-Prime (alte wave_10 nun hier)

### Public-API additiv
- `BossCharge` Resource-Schema
- `BossCharge.compute_charge_velocity(...)` (static)
- `BossMob.start_charge(charge)`, `is_charging()` -> bool
- ContentLoader hat jetzt **2 Bosse** und **2 Maps**

### Added
- **ADR 0042:** Raptor-Composite-Visual — `trex.tres` bekommt
  Polygon2D-Composite als Default-Visual. Player rendert nicht mehr
  als gelbes Quadrat sondern als grüner Velociraptor mit Schwanz,
  Beinen, Kopf, Auge und Rücken-Akzent.
- `art/player/raptor_composite.tscn` — Node2D mit 8 Polygon2D-
  Children (Tail, BackLeg, FrontLeg, Body, Head, Jaw, Eye,
  BackRidge), Farben aus `Palette.PLAYER_BODY` (mid green) und
  `Palette.PLAYER_ACCENT` (dark green).
- `content/dinos/trex.tres` — `visual_scene` jetzt mit Reference
  auf `raptor_composite.tscn`, `visual_pivot_offset = (0, -4)`.
- `tests/unit/test_visual_provider.gd` — Default-trex-Test
  angepasst (visual_scene ist jetzt nicht mehr null).

### Spielfühl-Konsequenz
- Player ist visuell als **grüner Raptor** erkennbar — Mood-
  Reference deutlich näher
- ColorRect-Mode bleibt Fallback wenn `visual_scene = null`
  (Backward-Kompat für Test-Mocks)

### Added
- **ADR 0041:** Iso-Map-Visual-Polish — Mood-Reference-Annäherung
  ohne echte Sprite-PNGs. IsoWorld zeigt jetzt:
  - **Dirt-Side-Faces** an unterer/rechter Plattform-Kante
    (Trapez-Polygon2D mit Gradient DIRT_SIDE_TOP→BOTTOM)
  - **Decorations** (programmatisch): Blumen rot/gelb/lila
    + Crystal-Spike grün, deterministisch via Tile-Hash-RNG
  - **BG_CHARCOAL-Background** als CanvasLayer-Child (layer=-100)
- `core/world/iso_world.gd` erweitert um:
  - `@export var decoration_density: float = 0.20`
  - `@export var side_face_depth: float = 18.0`
  - `_build_tiles` erstellt jetzt zusätzlich `Sides`- und
    `Decorations`-Container
  - `_is_edge_tile`, `_make_side_polygon`, `_build_decorations`,
    `_make_random_decor`, `_make_flower_polygon`, `_make_crystal_polygon`
- `core/run_scene/run.tscn` — neues `BackgroundLayer` (CanvasLayer
  -100) mit ColorRect in Palette.BG_CHARCOAL.
- `tests/unit/test_iso_world.gd` — `+ 6 Visual-Polish-Tests`.

### Spielfühl-Konsequenz
- Map sieht erstmals nach **erhabener Plattform** aus (Dirt-Sides
  zeigen die Plattform-Tiefe)
- **Blumen + Crystals** geben der Map Charakter — nicht mehr
  uniformer Tile-Mesh
- **Charcoal-Background** statt Default-Grau — passt zur Mood-Reference

### Public-API additiv
- `IsoWorld.decoration_density: float` (@export)
- `IsoWorld.side_face_depth: float` (@export)

---

## [0.2.0] - 2026-05-06

---

## [0.2.0] - 2026-05-06

> **Phase 5 — Loop geschlossen.** Bernstein hat jetzt Bedeutung:
> Run → Bernstein verdienen → Shop → Upgrade kaufen → Buff im
> nächsten Run. Tyrannosaurus Prime stomps in Rage-Phase und schüttelt
> dabei die Camera. Iso-World mit Smooth-Camera-Follow + Auto-Bounds +
> Padding läuft visuell sauber. Modder-Surface ist 9 Content-Types
> + 24 EventBus-Signals.
>
> 11 neue ADRs (0030–0040), 1 neuer Autoload (MetaProgression),
> 4 neue EventBus-Signals (boss_ability_used, boss_phase_changed,
> currency_changed, upgrade_purchased), neue Iso-World-/Camera-/
> Audio-/Shop-Infrastruktur, ~3500 neue Test-Zeilen.
>
> Save-Schema bleibt v1 (alle Erweiterungen sind additive Slots
> unter `data.*`). Saves von 0.0.x laden sauber als 0.2.0.

### Added
- **ADR 0040:** Meta-Shop-UI + UpgradeDef — permanente Upgrade-Pipeline.
  4 initiale Upgrades (stronger_jaws, tougher_hide, faster_legs,
  sharper_eyes) mit gestuften Costs. Shop-Overlay auf CanvasLayer 90.
- `core/content/upgrade_def.gd` — UpgradeDef-Resource (max_level,
  cost_per_level, stat_modifiers_per_level, cost_currency).
- `content/upgrades/{stronger_jaws,tougher_hide,faster_legs,sharper_eyes}.tres`
  — 4 Initial-Upgrades, total 14 Levels Käufe für 1280 Bernstein.
- `core/content_loader.gd` — neuer Type `upgrade`. ContentLoader hat
  jetzt **8 Types** (mutation, enemy, boss, dino, wave, sound, map, upgrade).
- `core/meta_progression.gd` erweitert um:
  - `purchase_upgrade(id)`, `get_upgrade_level(id)`, `get_upgrade_cost(id)`
  - `can_afford_upgrade(id)`, `list_upgrade_levels()`
  - `get_aggregated_modifiers()` (Bridge zu Modifier-Pipeline)
  - Save/Load-Erweiterung: `upgrade_levels`-Slot
- `core/event_bus.gd` — neues Signal
  `upgrade_purchased(upgrade_id, new_level)`. EventBus-Total: 23 → **24 Signals**.
- `core/ui/shop_overlay.gd` + `.tscn` — CanvasLayer 90, listet alle
  Upgrades, Buy-Button per Row.
- `core/run_scene/run.tscn` — `ShopLayer` als Child instantiiert.
- `core/player/player_character.gd` — `get_aggregated_or_empty()`
  mergt PlayerMutations + MetaProgression additiv. Subscribes
  `EventBus.upgrade_purchased`.
- `tests/unit/test_upgrade_def.gd` — 14 Tests.
- `tests/unit/test_meta_progression.gd` — `+ 12 Upgrade-Tests`
  (purchase, can_afford, max_level, signal, save/load-roundtrip).
- locale/{de,en}.po um 8 upgrade.*-Keys.
- BALANCE.csv um 4 Upgrade-Einträge (jetzt 28 total).

### Save-Schema (v1.2, additive)
- `data.upgrade_levels: Dictionary[upgrade_id → int]`. Saves vor v0.2.0
  ohne diesen Slot werden korrekt geladen (Default `{}`).

### Public-API additiv
- `UpgradeDef`-Schema mit max_level/cost_per_level/stat_modifiers_per_level
- `MetaProgression.purchase_upgrade()`, `get_upgrade_level()`,
  `get_upgrade_cost()`, `can_afford_upgrade()`, `list_upgrade_levels()`,
  `get_aggregated_modifiers()`
- `EventBus.upgrade_purchased(id, new_level)`
- `ShopOverlay.show_shop()`, `hide_shop()`, `refresh_list()`
- ContentLoader hat jetzt 8 Types

### Spielfühl-Konsequenz
- **Loop ist geschlossen**: Spieler stirbt → Save speichert Bernstein →
  Shop öffnen → "Stronger Jaws" Lv 1 für 50 Bernstein kaufen →
  Nächster Run macht +5% Damage permanent
- Bernstein hat jetzt klares Ziel: Bossen jagen, Upgrades kaufen,
  stärker zurückkehren

### Test-Suite
- 35 Scripts, ~530 Tests (Sandbox-Cache zeigt teilweise stale-counts,
  Windows-Files sind aktuell).

---

### Added
- **ADR 0039:** Custom-Shake-Profiles — pro EventBus-Signal eigenes
  ShakeProfile (Trauma + Decay + MaxOffset). Modder können Custom-
  Profiles registrieren. Boss-Abilities (ADR 0038) bekommen jetzt
  ihren eigenen Shake (Stomp = 0.5 trauma).
- `core/world/shake_profile.gd` — Resource (trauma_amount,
  decay_per_second, max_offset) mit validate().
- `core/world/profiles/profile_player_damaged.tres` (0.3 trauma)
- `core/world/profiles/profile_boss_defeated.tres` (0.7 trauma)
- `core/world/profiles/profile_boss_stomp.tres` (0.5 trauma)
- `core/world/run_camera.gd` erweitert um:
  - `PROFILE_PLAYER_DAMAGED`, `PROFILE_BOSS_DEFEATED`, `PROFILE_BOSS_STOMP`
    Konstanten (preloaded)
  - `add_trauma_from_profile(profile)` API
  - `register_signal_profile(signal_name, profile)` Mod-API
  - `register_ability_profile(ability_id, profile)` für boss_ability_used
  - `get_signal_profile(signal_name)` / `get_ability_profile(id)`
  - `_on_boss_ability_used`-Subscription
  - Default-Mappings im _ready: player_damaged, boss_defeated,
    tyrannosaurus_stomp
- `tests/unit/test_run_camera.gd` — `+ 11 Profile-Tests`
  (Default-Mappings, Custom-Override, Schema-Validate,
  EventBus-Integration).

### Public-API additiv
- `ShakeProfile` Resource-Schema
- `RunCamera.add_trauma_from_profile(profile)`
- `RunCamera.register_signal_profile(name, profile)`
- `RunCamera.register_ability_profile(id, profile)`
- `RunCamera.get_signal_profile(name)`, `get_ability_profile(id)`
- `RunCamera.PROFILE_*` Konstanten

### Spielfühl-Konsequenz
- Stomp-Damage in Rage-Phase löst spürbaren Camera-Shake aus —
  Spieler fühlt das Gewicht des Bosses
- Modder können ihre eigenen Boss-Abilities mit eigenen Shake-
  Profiles ausstatten

### Backward-Kompatibilität
- Wenn kein Profile gemappt ist, fällt RunCamera auf hardcoded
  `trauma_on_player_damaged` etc. zurück (ADR 0035-Verhalten)

---

### Added
- **ADR 0038:** Boss-Abilities-Schema — BossPhase kann jetzt eine
  Liste von BossAbility-Resources tragen, die periodisch ausgelöst
  werden. Erste konkrete Ability: BossStomp (AOE-Damage).
- `core/content/boss_ability.gd` — Base-Resource (id, cooldown,
  initial_delay, virtual `trigger`).
- `core/content/abilities/boss_stomp.gd` — `BossStomp extends BossAbility`:
  - `radius: float`, `damage: float`
  - `find_player_health_in_radius(center, radius, players)` als pure
    static (Test-Hook)
- `core/content/boss_phase.gd` — `+ abilities: Array[BossAbility]`.
- `core/boss/boss_mob.gd` — `_tick_abilities(delta)` im
  `_physics_process`, per-Ability-Cooldown via `_ability_cooldowns`-Dict,
  Reset bei Phase-Wechsel.
- `core/event_bus.gd` — neues Signal
  `boss_ability_used(boss_id, ability_id, position)`.
  EventBus-Total: 22 → **23 Signals**.
- `tests/unit/test_event_bus.gd` — KNOWN_SIGNALS um `boss_ability_used`
  ergänzt.
- `content/bosses/tyrannosaurus_prime.tres` — Rage-Phase bekommt
  `tyrannosaurus_stomp` (cooldown=4s, radius=140px, damage=25).
- `tests/unit/test_boss_abilities.gd` — 14 Tests:
  - BossAbility/BossStomp-Schema-Defaults und Validate
  - Pure-Function `find_player_health_in_radius` mit close/far/no-health
  - BossPhase.abilities-Array
  - tyrannosaurus_prime-Wiring (Rage-Phase hat Stomp)
  - BossMob-Tick: initial_delay, Cooldown, Phase-Reset, dead-boss-skip

### Spielfühl-Konsequenz
- Tyrannosaurus Prime ist in Rage-Phase aktiv aggressiv: alle ~4s
  schlägt er zu, alle Players in 140px Radius bekommen 25 Damage.
- Rage-Phase fühlt sich finales Threat-Gefühl an — Spieler muss aktiv
  kiten, kann nicht mehr stehen bleiben.

### Public-API additiv
- `BossAbility.trigger(boss)` (virtual)
- `BossStomp.find_player_health_in_radius(...)` (static)
- `BossPhase.abilities: Array[BossAbility]`
- `EventBus.boss_ability_used(boss_id, ability_id, position)`
- `BossMob._tick_abilities(delta)` + `_ability_cooldowns` Dict

---

### Added
- **ADR 0037:** Camera-Bounds-Padding — Camera klemmt nicht mehr
  strikt am Plattform-Rand. `bounds_padding: Vector2` erweitert das
  attach_to_world-Rect nach außen, sodass der Charcoal-Background
  außerhalb der Plattform sichtbar wird.
- `core/world/run_camera.gd` erweitert um:
  - `@export var bounds_padding: Vector2 = Vector2.ZERO`
  - `set_bounds_padding(p)` re-applied auf bereits gesetzte World-Bounds
  - `attach_to_world(world, padding = Vector2(-1,-1))` mit Padding-Argument
  - `compute_padded_bounds(world_rect, padding) -> Rect2` als pure static
- `core/content/map_def.gd` erweitert um:
  - `@export var camera_padding: Vector2 = Vector2.ZERO`
- `core/run_scene/run.gd` — liest `MapDef.camera_padding` und reicht
  es beim `attach_to_world` durch.
- `tests/unit/test_run_camera.gd` — `+ 5 Padding-Tests`
- `tests/unit/test_map_def.gd` — `+ 3 camera_padding-Tests`

### Public-API additiv
- `RunCamera.set_bounds_padding(p: Vector2)`
- `RunCamera.compute_padded_bounds(world_rect, padding) -> Rect2` (static)
- `RunCamera.attach_to_world(world, padding)` mit Padding-Argument
- `MapDef.camera_padding: Vector2`

### Backward-Kompatibilität
- Default-Padding `Vector2.ZERO` → ADR 0033-Verhalten unverändert
- `attach_to_world(world)` ohne Padding-Argument → nutzt bisheriges
  `bounds_padding` (Default Zero)

---

### Added
- **ADR 0036:** MapDef als Content-Resource — Map-Layouts sind jetzt
  data-driven. Designer und Modder können Map-Größe/Pfad-Pattern ändern
  ohne Code-Touch.
- `core/content/map_def.gd` — neue Resource (grid_size, path_row,
  path_col, deterministic_colors, biome_label_key) mit validate().
- `core/content_loader.gd` — neuer Type `map`
  (`res://content/maps/`, mod-subpath `maps/`).
- `content/maps/default.tres` — Standard-Map 1:1 zu den bisher hardcoded
  IsoWorld-Werten (8×8, Cross-Pfad bei (4,4)).
- `core/world/iso_world.gd` — `+ set_map_def(def)` und `+ get_map_def()`.
  set_map_def übernimmt Konfig und ruft `_build_tiles()` auf.
- `core/run_scene/run.gd` — `+ @export var map_id`, lädt MapDef beim
  Run-Start und appliziert sie auf IsoWorld bevor Camera attached.
- `tests/unit/test_map_def.gd` — 7 Tests (Discovery, Validate-Regeln,
  Field-Loading, Type-Registration).
- `tests/unit/test_iso_world.gd` — `+ 4 set_map_def-Tests`.
- `tests/unit/test_content_loader.gd` — map-Type-Check ergänzt.
- locale/{de,en}.po um 2 map.default-Keys.
- BALANCE.csv um 1 map-Eintrag erweitert (jetzt 23 total).

### Public-API additiv
- `MapDef`-Schema mit grid_size, path_row, path_col, deterministic_colors,
  biome_label_key
- `IsoWorld.set_map_def(def: MapDef)`, `get_map_def() -> MapDef`
- `RunScene.map_id: StringName` (@export, default `&"default"`)
- ContentLoader hat jetzt 7 Types (mutation/enemy/boss/dino/wave/sound/map)

### Designer/Modder-Konsequenz
- **Map-Tuning ohne Code-Touch**: grid_size in `default.tres` editieren →
  Re-Import → neue Welt
- **Mod kann eigene Map ergänzen**: `mod/content/maps/desert.tres`
  mit eigener grid_size/path-Pattern + override_existing=false → neue
  Map-ID

### Test-Suite
- 33 Scripts, 484 Tests (von 471 → +13).

---

### Added
- **ADR 0035:** Camera-Shake (Trauma-System) — Squirrel-Eiserloh-Pattern.
  Trauma-Wert decayed exponentiell, Shake-Offset = trauma² × max_offset
  × noise. EventBus-driven: player_damaged → +0.3, boss_defeated → +0.7.
- `core/world/run_camera.gd` erweitert um:
  - `@export var max_shake_offset, trauma_decay_per_second,
    trauma_on_player_damaged, trauma_on_boss_defeated, shake_muted`
  - Public-API: `add_trauma(amount)`, `set_trauma(value)`
  - Pure-Function-Statics: `compute_shake_offset(trauma, max_offset, rng)`,
    `compute_trauma_after_decay(trauma, decay_per_s, delta)`
  - EventBus-Subscriptions: `player_damaged` und `boss_defeated`
- `tests/unit/test_run_camera.gd` — `+ 13 Trauma-Tests`
  (Default-State, add_trauma-Clamp, mute-Hook, decay-Math,
  shake-offset-Math, EventBus-Hooks).

### Spielfühl-Konsequenz
- Treffer fühlen sich wuchtig an — Camera ruckt sichtbar bei jedem
  Player-Damage (0.3 Trauma → ~0.5s Shake)
- Boss-Defeat bekommt Tremor-Finale (0.7 Trauma → ~0.8s starker Shake)
- Pixel-Snap bleibt für die Position-Komponente erhalten — Shake-
  Offset ist absichtlich sub-pixel (sonst wirkt es zu hart)

### Public-API additiv
- `RunCamera.add_trauma(amount)`, `set_trauma(value)`
- `RunCamera.compute_shake_offset(...)` (static)
- `RunCamera.compute_trauma_after_decay(...)` (static)

---

### Added
- **ADR 0034:** Y-Sort-Layering — PlayerSlot und EnemyContainer sind
  jetzt Node2D mit `y_sort_enabled = true`. Mobs rendern automatisch
  nach Y-Position vor/hinter einander — Voraussetzung für Iso-Tiefe.
- `core/run_scene/run.tscn` — PlayerSlot/EnemyContainer von `Node` auf
  `Node2D` mit `y_sort_enabled = true` umgestellt.
- `tests/unit/test_run_scene.gd` — `+ 2 Y-Sort-Tests`
  (PlayerSlot/EnemyContainer Node2D + y_sort_enabled).

### Spielfühl-Konsequenz
- Player rennt visuell vor Enemies durch, die hinter ihm sind, und
  hinter Enemies, die weiter vorne stehen. Iso-Tiefe ist da.

### Backward-Kompatibilität
- `Node` → `Node2D`-Wechsel ist Subclass-Beziehung, alle existierenden
  `add_child`-Calls etc. laufen weiter durch.

---

### Added
- **ADR 0033:** Camera-Auto-Bounds aus IsoWorld — Camera klemmt
  automatisch am Plattform-Rand, ohne dass RunScene Bounds-Werte
  kennen muss.
- `core/world/iso_world.gd` — `+ world_bounds() -> Rect2` (Pure Function,
  Diamond-Form berücksichtigt: jeder Tile ragt TILE_SIZE/2 in jede
  Richtung von seinem Pivot).
- `core/world/run_camera.gd` — `+ attach_to_world(world: IsoWorld)`
  Convenience-Helper, ruft `set_bounds()` aus dem World-Rect auf.
- `core/run_scene/run.gd` — `_spawn_player_and_start` wired die
  Camera ans IsoWorld via `attach_to_world(iso_world)` direkt vor
  `snap_to_target()`.
- `tests/unit/test_iso_world.gd` — `+ 4 world_bounds-Tests` (empty,
  1×1, 8×8, contains-all-pivots).
- `tests/unit/test_run_camera.gd` — `+ 3 attach_to_world-Tests`.

### Spielfühl-Konsequenz
- Player kann nicht mehr aus der Camera-Sicht „über den Rand fallen" —
  Camera klemmt am 8×8-Plattform-Rand. Der Spieler sieht visuell, wo
  das Spielfeld endet.

### Public-API additiv
- `IsoWorld.world_bounds() -> Rect2`
- `RunCamera.attach_to_world(world: IsoWorld) -> void`

### Test-Suite
- 32 Scripts, 458 Tests (von 451 → +7).

---

### Added
- **ADR 0032:** Camera-System (Player-Follow + Bounds) — Camera2D folgt
  dem Player mit Smooth-Lerp, Pixel-Snap für Pixel-Art-Crispness,
  optionale World-Bounds. Pure-Function-Update macht das System
  headless-testbar.
- `core/world/run_camera.gd` + `.tscn` — `RunCamera extends Camera2D`:
  - `set_target(node)` / `snap_to_target()` / `set_follow_smoothing(v)` /
    `set_bounds(min, max)`
  - `compute_next_position()` als static pure function für Tests
  - Default `zoom = (2, 2)` (Pixel-Art-Standard)
  - Default `follow_smoothing = 5.0` (Survivor-likes-Feel)
  - Frame-Rate-Independent Lerp: `alpha = 1 - exp(-smoothing * delta)`
  - Crash-Protection bei freed target via `is_instance_valid`
- `core/run_scene/run.tscn` — `RunCamera`-Child neben PlayerSlot
- `core/run_scene/run.gd` — sowohl `_ready` als auch `_spawn_player_and_start`
  hängen Camera per `set_target(_player) + snap_to_target()` an.
  Camera überlebt Restart (kein Re-Instanziieren nötig).
- `tests/unit/test_run_camera.gd` — 19 Tests:
  - 6 Pure-Function-Tests (compute_next_position)
  - Target-Tracking, Snap, Pixel-Snap-Roundtrip
  - set_follow_smoothing-Clamp, set_bounds-Auto-Sort
  - Default-Zoom, Default-Smoothing, Pixel-Snap-Default
  - Crash-Protection bei freed target

### Spielfühl-Konsequenz
- F5 zeigt jetzt: Player läuft, Camera folgt smooth — der Spieler
  bleibt zentriert auf dem Bildschirm
- Mit Iso-World (ADR 0031) im Hintergrund fühlt sich das Spielfeld
  erstmals wirklich navigiert an
- Restart-Run hat keinen Camera-Jump (Snap auf Player-Position)

### Public-API additiv
- `RunCamera.set_target()`, `snap_to_target()`, `set_follow_smoothing()`,
  `set_bounds()`
- `RunCamera.compute_next_position()` (static)
- @export-Properties: `target`, `follow_smoothing`, `pixel_snap`,
  `enable_limits`, `bound_min`, `bound_max`

### Test-Suite
- 32 Scripts, 450 Tests (von 431 → +19 Camera-Tests).

---

### Added
- **ADR 0031:** Art-Pipeline + Iso-Map-Konventionen — Asset-Drop-
  Infrastruktur. Folder-Struktur, Palette als Single-Source-of-Truth,
  Iso-World-Skelett als Background.
- `core/art/palette.gd` — `Palette`-Klasse mit 16 Color-Konstanten aus
  `docs/art/VISUAL-TARGET.md`:
  - BG_CHARCOAL, GRASS_LIGHT/MID/DARK/EDGE, DIRT_PATH/SIDE_TOP/BOTTOM
  - PLAYER_BODY/ACCENT, COIN_GOLD/HIGHLIGHT, CRYSTAL_GREEN
  - FLOWER_RED/YELLOW/LILA
  - `random_grass(rng)` Helper (deterministisch mit RNG, sonst global randf)
- `core/world/iso_world.gd` + `.tscn` — Iso-Tile-Map-Skelett:
  - 8×8 Grid (konfigurierbar via @export)
  - Polygon2D-Diamonds als Placeholder-Tiles (64×32 Iso-Standard)
  - Cross-Pfad in DIRT_PATH-Color durch Mitte
  - Deterministische Color-Variation (hash-basiert) für stable Tests
  - Pure-Function-Public-API: `tile_to_iso`, `iso_to_tile`, `world_size`,
    `is_path_tile`
- `core/run_scene/run.tscn` — neuer `WorldLayer` als Child mit
  z_index=-10, instantiiert `IsoWorld`. Mobs rendern darüber.
- `art/` Folder-Struktur mit 9 READMEs (high-level + 8 subfolder):
  - `tiles/`, `decor/`, `player/`, `enemies/`, `bosses/`, `pickups/`,
    `ui/`, `audio/` — jedes README spezifiziert Sprite-Größe, Pivot,
    erwartete Files
- `docs/art/VISUAL-TARGET.md` — bereits in v0.1.0 angelegt (User-Mood-
  Reference + verbal-Spec)
- `tests/unit/test_palette.gd` — 9 Tests für Color-Konstanten,
  random_grass-Determinismus
- `tests/unit/test_iso_world.gd` — 14 Tests für Iso-Math, Tile-Generation,
  Path-Logik, world_size

### Spielfühl-Konsequenz
- F5 zeigt jetzt eine sichtbare Tile-Plattform unter den Mobs (8×8
  Grid mit Cross-Pfad). Spiel fühlt sich verortet an, auch ohne echte
  Sprites.
- Sobald Asset-Artist Tile-PNGs liefert, wird `IsoWorld` von Polygon2D
  auf TileMapLayer umgestellt — gleiches Layout, andere Render-Quelle.
- `EnemyDef.body_color` / `BossDef.body_color` können jetzt aus der
  Palette lesen (z.B. `body_color = Palette.GRASS_DARK`) statt
  hardcoded Color-Tupel — kommt mit kleinen Refactor-Pässen.

### Backward-Kompatibilität
- ColorRect-Mobs (ADR 0024) bleiben unverändert — IsoWorld liegt unter
  ihnen via z_index=-10.
- Alle existierenden Tests laufen weiter durch (keine API-Brüche).

### Public-API additiv
- `Palette.<COLOR_CONST>` (16 Color-Konstanten als Klassen-Attribute)
- `Palette.random_grass(rng = null) -> Color`
- `IsoWorld.tile_to_iso(tile, tile_size = TILE_SIZE) -> Vector2` (static)
- `IsoWorld.iso_to_tile(screen, tile_size = TILE_SIZE) -> Vector2i` (static)
- `IsoWorld.world_size() -> Vector2`
- `IsoWorld.is_path_tile(tile) -> bool`

### Test-Suite
- 31 Scripts, 429 Tests (von 406 → +23 Iso-World/Palette-Tests).

---

## [0.1.0] - 2026-05-06

> **Phase 4 — Vertical-Slice.** Boss-Fights bekommen Spannungsbogen
> (Phasen-Schema), Visual-Provider erlaubt Sprite-Drop ohne Code-Touch,
> SFX-Bus ist scharf gestellt für Audio-Drop, Bernstein-Currency
> überlebt jetzt Runs. Die ganze Asset-frei lauffähige Mechanik steht.
>
> 5 neue ADRs (0026 WaveDef, 0027 Visual-Provider, 0028 SFX-Bus,
> 0029 Boss-Phasen, 0030 Meta-Progression), 1 neuer Autoload,
> 1 neuer EventBus-Signal, ~75 neue Tests, ~3300 neue Zeilen.
>
> Public-API bleibt rückwärtskompatibel — alle 0.0.x-Saves laden
> sauber, ColorRect-Mode bleibt Default-Visual.

### Added
- **ADR 0030:** Persistente Meta-Progression — Bernstein-Currency
  überlebt jetzt Runs. Boss-Defeat zahlt automatisch
  `BossDef.reward_currency_amount` aus, Save persistiert atomar via
  EventBus.save_requested-Trigger im RunScene.
- `core/meta_progression.gd` — neuer Autoload mit:
  - `DEFAULT_CURRENCY = &"amber"` Konstante
  - Public-API `get_currency`, `add_currency`, `set_currency`,
    `list_currencies`, `reset`
  - EventBus-Hooks: `boss_defeated` → Auto-Reward;
    `save_requested` → schreibt Snapshot;
    `save_loaded` → liest Snapshot
  - Lower-Cap bei 0 (keine negativen Currency-Werte)
  - Beliebige Currency-IDs erlaubt (Mods können eigene anlegen)
- `project.godot` — `MetaProgression` als 9. Autoload (Reihenfolge:
  EventBus → ContentLoader → SaveSystem → ModLoader → RunState →
  WaveSpawner → PlayerMutations → SfxBus → MetaProgression).
- `core/run_scene/run.gd` — `_on_run_ended` feuert
  `EventBus.save_requested(&"run_end")`, sodass Currency nach jedem
  Run automatisch persistiert wird.
- `tests/unit/test_meta_progression.gd` — 19 Tests (Default-State,
  add/set/get-API, Lower-Cap, Boss-Reward, Save-Roundtrip,
  Legacy-Save-Backward-Kompat).

### Changed
- **SaveSystem-Reihenfolge-Fix**: `save_loaded`-Signal feuert jetzt
  NACH dem `_data = loaded`-Assign, sodass Listener (MetaProgression)
  über `SaveSystem.get_data()` direkt auf den geladenen State
  zugreifen können. Bisheriges Verhalten hatte einen Race —
  bestehender Code war davon nicht betroffen, da niemand
  `save_loaded` für Daten-Lookups nutzte.

### Save-Schema (v1.1, additive)
- Save bekommt optionalen `data.meta_progression`-Slot mit
  Currency-Dict. Saves vor v0.1.0 ohne diesen Slot werden korrekt
  geladen (Default-State amber=0). **Keine Migration-File nötig.**

### Public-API additiv
- `MetaProgression.get_currency() / add_currency() / set_currency() /
  list_currencies() / reset()`
- `MetaProgression.DEFAULT_CURRENCY = &"amber"`
- `MetaProgression.SAVE_KEY = "meta_progression"`

### Spielfühl-Konsequenz
- Run 1: Spieler tötet Tyrannosaurus auf Welle 5 → +50 Bernstein
- Run-Ende → Save automatisch → Bernstein bleibt
- Run 2: Spieler startet wieder bei 0 HP, aber 50 Bernstein bereits
  im Konto → Foundation für Meta-Shop

### Test-Suite
- 29 Scripts, 399 Tests (von 380 → +19 MetaProgression-Tests).

---

### Added
- **ADR 0029:** Boss-Phasen-Schema — Boss-Fights bekommen Spannungsbogen.
  HP-Threshold-basierte Phasen mit Speed-/Damage-Multiplikatoren und
  Color-Tint. Tyrannosaurus Prime hat jetzt 3 Phasen: Spawn (100%) →
  Mid (66%) → Rage (33%, 50% schneller, 40% mehr Damage, rötlicher Body).
- `core/content/boss_phase.gd` — Resource (hp_threshold, speed_multiplier,
  damage_multiplier, color_tint, label_key) mit validate().
- `core/content/boss_def.gd` — `phases: Array[Dictionary]` →
  `Array[BossPhase]`, validate() prüft absteigende Sortierung.
- `core/boss/boss_mob.gd` — Phase-Dispatch:
  - `_on_health_changed` → `_evaluate_phase` bei jedem damage_taken/healed
  - `_resolve_phase_index(hp_pct)` als pure function (testbar)
  - Monoton fallend (kein Rückfall bei Heal)
  - `_apply_phase` setzt Color-Tint auf Body / Visual.modulate
  - `get_speed()` / `get_damage()` Phase-aware
  - `get_current_phase_index()` als Public-API
- `core/event_bus.gd` — neues Signal
  `boss_phase_changed(boss_id, phase_index, label_key)`.
  EventBus-Total: 21 → **22 Signals**.
- `content/bosses/tyrannosaurus_prime.tres` — 3 BossPhase-SubResources:
  - Spawn: 1.0 / 1.0× / 1.0× / weiß
  - Mid:   0.66 / 1.2× / 1.15× / leicht rosa
  - Rage:  0.33 / 1.5× / 1.4× / rot
- `tests/unit/test_boss_phases.gd` — 16 Tests:
  - Schema-Defaults und Validate-Regeln
  - BossDef-Sort-Validation
  - Phase-Resolver bei verschiedenen HP-Werten
  - Speed/Damage-Multiplier-Application
  - boss_phase_changed-Signal-Emission
  - Monoton-Garantie (kein Rückfall bei Heal)
  - Backward-Kompat (Boss ohne Phasen)
- `tests/unit/test_event_bus.gd` — KNOWN_SIGNALS um boss_phase_changed
  erweitert.
- locale/{de,en}.po um 4 phase-Banner-Keys
  (boss.tyrannosaurus_prime.phase_mid + .phase_rage in DE+EN).

### Backward-Kompatibilität
- `def.phases = []` → Boss verhält sich wie vor ADR 0029
  (`get_current_phase_index() == -1`, Speed/Damage = base).
- Alle bestehenden Boss-Tests (test_boss_mob.gd) laufen unverändert
  durch — Phasen sind additiv.

### Public-API additiv
- `EventBus.boss_phase_changed(boss_id, phase_index, label_key)`
- `BossPhase`-Resource-Schema
- `BossMob.get_current_phase_index() -> int`
- `BossMob.get_damage() -> float` (vorher direkt def.damage gelesen)
- `BossDef.phases: Array[BossPhase]` (war Array[Dictionary])

### Spielfühl-Konsequenz
- Boss-Fight ab Welle 5 hat echten Spannungsbogen
- Bei 33% HP wird Spieler zum Push gezwungen — letzte 250 HP sind die
  härteste Phase

### Test-Suite
- 28 Scripts, 380 Tests (von 364 → +16 Boss-Phasen-Tests).

---

### Added
- **ADR 0028:** SFX-Bus + SoundDef — Audio-Hooks bereit für Asset-Drop.
  Neuer Autoload `SfxBus` lauscht auf bedeutsame EventBus-Signale und
  triggert SoundDef-Playback über AudioStreamPlayer-Pool. v1: alle
  SoundDefs sind Stubs (stream=null) → no-op bis Audio-Assets landen.
- `core/audio/sfx_bus.gd` — Autoload mit:
  - 8-er AudioStreamPlayer-Pool (Round-Robin)
  - 6 Default-Mappings (enemy_died, boss_defeated, player_damaged,
    player_died, mutation_picked, wave_started)
  - Public-API `play()`, `set_muted()`, `pool_size()`,
    `get_signal_mapping()`, `add_signal_mapping()` (Mod-API-Erweiterung)
- `core/content/sound_def.gd` — Resource (`stream`, `volume_db`,
  `pitch_random_range`).
- `core/content_loader.gd` — neuer Type `sound`
  (`res://content/sounds/`, mod-subpath `sounds/`).
- `content/sounds/` — 6 SoundDef-Stubs:
  - sfx_enemy_died (vol=-3dB, pitch ±0.1)
  - sfx_boss_defeated (vol=+2dB)
  - sfx_player_damaged (vol=0dB, pitch ±0.05)
  - sfx_player_died (vol=0dB)
  - sfx_mutation_picked (vol=+1dB)
  - sfx_wave_started (vol=-2dB)
- `project.godot` — `SfxBus` als 8. Autoload (Reihenfolge: EventBus →
  ContentLoader → SaveSystem → ModLoader → RunState → WaveSpawner →
  PlayerMutations → SfxBus).
- `tests/unit/test_sound_def.gd` — 11 Tests (Discovery, Validate-Regeln,
  Field-Loading, Type-Registration).
- `tests/unit/test_sfx_bus.gd` — 13 Tests (Pool-Setup, Default-Mappings,
  no-op-Verhalten, Mute-Hook, EventBus-Subscription-Smoke).
- `tests/unit/test_content_loader.gd` um sound-Type-Check ergänzt.
- locale/{de,en}.po um 12 sfx.*-Keys erweitert.
- BALANCE.csv um 6 Sound-Einträge erweitert (jetzt 22 total).
- agents/memory/content-author/content-id-registry.md — sound-Section.
- docs/ARCHITECTURE.md — neuer Pattern-Block „SFX-Bus".
- agents/memory/mod-api-curator/public-api-surface.md — neue Section 3.5
  „SfxBus-API" + SoundDef-Schema unter §3.

### Audio-Roadmap
- v1: alle Streams null → SfxBus läuft no-op, alle Hooks sind aber
  scharf gestellt
- v0.0.10+: echte .ogg-Assets in `content/sounds/*.tres` referenzieren →
  Audio läuft ohne Code-Touch
- Backlog: Music-System, 3D-Audio, Bus-Mixer, SFX-Cooldown

### Public-API additiv
- `SfxBus.play(sound_id)` / `set_muted()` / `add_signal_mapping()`
- `SoundDef`-Schema mit `stream`, `volume_db`, `pitch_random_range`
- ContentLoader hat jetzt 6 Types (mutation/enemy/boss/dino/wave/sound)

### Test-Suite
- 27 Scripts, 363 Tests (von 339 → +24 Audio-Tests).

---

### Added
- **ADR 0027:** Visual-Provider-Pattern — EnemyDef/DinoDef/BossDef
  bekommen optionalen `visual_scene: PackedScene` Slot. Wenn gesetzt,
  ersetzt die Scene den ColorRect-Body. Migrations-Pfad für künftige
  Sprites/Animationen ist data-driven, kein Code-Touch nötig.
- `core/content/enemy_def.gd` — `+visual_scene`, `+visual_pivot_offset`.
- `core/content/dino_def.gd` — `+visual_scene`, `+visual_pivot_offset`.
- `core/content/boss_def.gd` — `+visual_scene`, `+visual_pivot_offset`.
- `core/enemy/enemy_mob.gd` — `_apply_visuals` jetzt mit Visual-
  Provider-Pfad, hidden ColorRect bei Sprite-Mode.
- `core/player/player_character.gd` — neue `_apply_visuals(dino)`,
  wird beim `set_dino` aufgerufen.
- `core/boss/boss_mob.gd` — analoges Pattern wie EnemyMob.
- `tests/fixtures/visual_stub.tscn` — Test-Helper-Scene (Node2D mit
  grünem Indicator-Quadrat).
- `tests/unit/test_visual_provider.gd` — 13 Tests:
  - Default null → ColorRect-Mode (Backward-Kompat)
  - visual_scene gesetzt → Visual-Child instanziert + Body hidden
  - Resetup-Idempotenz
  - Existing .tres-Files haben visual_scene=null (Backward-Kompat)

### Backward-Kompatibilität
- Alle bestehenden EnemyDef/DinoDef/BossDef .tres-Files behalten ihren
  ColorRect-Look (visual_scene defaults to null).
- ColorRect-Tests aus ADR 0024 laufen unverändert durch.

### Modder-Surface additiv
- `EnemyDef.visual_scene: PackedScene` (optional)
- `DinoDef.visual_scene: PackedScene` (optional)
- `BossDef.visual_scene: PackedScene` (optional)
- `*.visual_pivot_offset: Vector2` (HealthBar-Anchor-Korrektur)

### Test-Suite
- 25 Scripts, 339 Tests (von 326 → +13 Visual-Provider-Tests).

---

### Added
- **ADR 0026:** WaveDef als Content-Resource — Wellen sind jetzt
  data-driven. Designer und Modder können Wellen ändern ohne
  Code-Touch.
- `core/content/wave_def.gd` — neue Resource-Klasse mit zwei Modi:
  - `is_default = true` (genau eine WaveDef): Curve-Default
    (`base_spawn_rate`, `spawn_rate_per_wave`, `max_spawn_rate`)
  - `target_wave_index > 0`: Override für genau diese Welle
    (eigener `enemy_pool`, optional `boss_id`, `duration_sec`)
- `core/content_loader.gd` — neuer Type `wave`
  (`res://content/waves/`, mod-subpath `waves/`).
- `content/waves/wave_default.tres` — Curve-Default 1:1 zu den bisher
  hardcoded Konstanten (0.5/0.3/5.0).
- `content/waves/wave_5_tyrannosaurus.tres` — Override Welle 5,
  Pool {grunt; alpha; ptera} + Boss tyrannosaurus_prime.
- `content/waves/wave_10_tyrannosaurus.tres` — Override Welle 10,
  Pool {grunt; alpha; ptera; carno} + Boss.
- `core/wave_spawner.gd` erweitert um:
  - Public-API `get_wave_def_for(idx)` und `get_active_wave_def()`
  - Resolver-Helper `_get_override_wave_def`, `_get_default_wave_def`
  - Boss-Resolver `_resolve_boss_id_for_wave` (Override > Konstanten)
  - `_spawn_rate_for_wave` und `_pool_for_wave` def-aware mit
    Konstanten-Fallback (Backward-Kompatibilität)
- `tests/unit/test_wave_def.gd` — 19 Tests (Discovery, Validate-Regeln,
  Field-Loading).
- `tests/unit/test_wave_spawner.gd` um 11 Resolver-Tests erweitert.
- `tests/unit/test_content_loader.gd` um wave-Type-Check ergänzt.
- locale/{de,en}.po um 6 wave.*-Keys erweitert.
- BALANCE.csv um 3 Wave-Einträge erweitert (jetzt 16 total).
- agents/memory/content-author/content-id-registry.md — wave-Section.
- docs/ARCHITECTURE.md — neuer Pattern-Block „WaveDef-Resolver".
- docs/CONTENT.md — neue Section „Wave-Spezifika" für content-author
  und Modder.
- agents/memory/mod-api-curator/public-api-surface.md — WaveDef-Schema
  unter §3 Resource-Schemas.

### Backward-Kompatibilität
- Alle Konstanten (`BASE_SPAWN_RATE`, `BOSS_WAVE_INTERVAL`, …) bleiben
  als Fallback im Code erhalten. Ohne `wave_default.tres` verhält sich
  der Spawner exakt wie vor ADR 0026.
- `_pool_for_wave`, `_spawn_rate_for_wave`, `_boss_for_wave` bleiben
  als private Helper bestehen (Tests, die sie direkt aufrufen, laufen
  weiter durch).

### Public-API additiv
- `WaveSpawner.get_wave_def_for(idx: int) -> WaveDef`
- `WaveSpawner.get_active_wave_def() -> WaveDef`

### Designer/Modder-Konsequenz
- **Welle-Tuning ohne Code-Touch**: Spawn-Rate-Curve in
  `wave_default.tres` editieren, Re-Import → neue Werte aktiv.
- **Mod kann Welle X überschreiben**: `mod/content/waves/wave_<idx>.tres`
  mit `target_wave_index = X` und `override_existing = true`.

### Test-Suite
- 24 Scripts, 326 Tests (alle grün — verifiziert lokal mit Godot 4.6).

---

### Added
- **ADR 0025:** Boss-Spawn-Mechanik — Boss-Wellen alle 5 Wellen
  spawnen `tyrannosaurus_prime` automatisch. Erstes In-Game-
  Setpiece, Loop bekommt Pacing.
- `core/boss/boss_mob.gd` + `.tscn` — generische BossMob-Scene,
  analog Enemy-Mob aber mit eigenem Death-Pfad
  (`EventBus.boss_defeated` statt `enemy_died`).
  Groups: `&"enemy"` (Auto-Attack-Target) + `&"boss"` (Marker).
- `core/components/health_component.gd` erweitert um
  `@export var is_boss: bool` — unterdrückt `enemy_died`-Emission
  bei Boss-Tod, damit BossMob `boss_defeated` selbst feuert.
- `core/content/boss_def.gd` erweitert um Felder `speed`, `damage`,
  `body_color`, `body_size`, `scene` (analog EnemyDef).
- `content/bosses/tyrannosaurus_prime.tres` aktualisiert:
  scene-Reference auf boss_mob.tscn + Visual/Movement-Werte.
- `core/wave_spawner.gd` erweitert um:
  - `BOSS_WAVE_INTERVAL = 5` (jede 5. Welle)
  - `_is_boss_wave(idx)` + `_boss_for_wave(idx)` (Lookup-Hooks)
  - `spawn_boss_at(boss_id, pos)` — Public-API, analog
    `spawn_enemy_at`
  - Hook in `_start_next_wave` → automatischer Boss-Spawn
- `tests/unit/test_boss_mob.gd` — 11 Tests (Setup, Visuals,
  Death-Pfad, boss_defeated-Signal mit run_time).
- `tests/unit/test_wave_spawner.gd` um 5 Boss-Wave-Tests
  erweitert (Interval, ID-Lookup, spawn_boss_at, Hook im
  Wave-Start).

### Pacing-Konsequenz
- Welle 1–4: normale Enemy-Wellen (Pool-Curve aus ADR 0023).
- Welle 5: Boss-Welle — `tyrannosaurus_prime` spawnt, normale
  Enemies laufen weiter.
- Welle 10/15/20: weitere Boss-Wellen (gleicher Boss in v0.0.7,
  Boss-Variation = Backlog).

### Test-Suite
- 23 Scripts, 307 Tests, 605 Asserts — alle grün.

### Added
- **ADR 0024:** Visuelle Enemy-Differenzierung — Spieler erkennt
  Enemy-Typen sofort am Look (statt nur am Verhalten).
- `core/content/enemy_def.gd` — neue @export-Felder `body_color` (Color)
  und `body_size` (Vector2) mit Defaults (rot, 16×16) für Backward-Kompat.
- `core/enemy/enemy_mob.gd` — `_apply_visuals(def)` im setup-Pfad,
  appliziert Color + Size + HealthBar-Offset.
- `content/enemies/{pteranodon, raptor_alpha, armored_carnotaurus}.tres`
  — alle drei mit unique Color + Size konfiguriert.
- `tests/unit/test_enemy_mob.gd` um 5 Visual-Tests.

### Color-Konvention
- raptor_grunt: rot 16×16 (Default)
- pteranodon: himmelblau 14×14 (klein, fragil)
- raptor_alpha: dunkelrot 22×22 (mid-tier)
- armored_carnotaurus: braungrau 28×28 (Tank)

### Test-Suite
- 22 Scripts, 291 Tests, 574 Asserts — alle grün.

### Added
- **ADR 0023:** Enemy-Variants + Boss-Resource (Stub) — Welt fühlt
  sich nach Welle 3+ abwechslungsreicher an. Boss-Asset bereit für
  Spawn-Mechanik-ADR.
- `content/enemies/pteranodon.tres` — Flieger (18 HP / 6 DMG / 180 Speed)
- `content/enemies/raptor_alpha.tres` — Mid-Tier (60 HP / 18 DMG / 140 Speed)
- `content/enemies/armored_carnotaurus.tres` — Tank (150 HP / 25 DMG / 80 Speed)
- `content/bosses/tyrannosaurus_prime.tres` — BossDef-Stub (800 HP /
  50 currency reward). Spawn-Mechanik = Backlog.
- `core/wave_spawner.gd` — Pool-Curve: Welle-skalierender Enemy-Pool.
- BALANCE.csv um 4 Einträge erweitert (jetzt 13 total).
- locale/{de,en}.po um 11 neue Translation-Keys.
- agents/memory/lore-writer/tone-of-voice.md mit Enemy-Tooltip-Beispielen
  und Boss-Texten.
- `tests/unit/test_wave_spawner.gd` + `test_content_loader.gd` um
  9 Pool-Curve- und Content-Tests.

### Lore-Voice (neue Beispiele)
- raptor_grunt: „Schnell, dünn gepanzert, kommt nie alleine."
- pteranodon: „Stürzt von oben, schlägt von schräg, weg ist er."
- raptor_alpha: „Erst der Anführer kommt. Der Schwarm hört zu."
- armored_carnotaurus: „Schwer wie ein Bus. Treibt Bus-Fahrgäste zur Verzweiflung."
- tyrannosaurus_prime: „Der Original-Schrecken. 12 Meter Wirbelsäule, schlechte Laune inklusive."

### Test-Suite
- 22 Scripts, 286 Tests, 565 Asserts — alle grün.

---

## [0.0.6] - 2026-05-06

> **Phase 2.6 — Pick-Polish + Hit-Feedback.** Mutation-Pick-Phase ist
> jetzt strategisch (rarity-gewichtet), Treffer haben sichtbares Feedback
> (Floating-Damage-Numbers mit Crit-Visualisierung).
>
> 2 neue ADRs (0012 Damage-Numbers, 0022 Rarity-Picks), 17 neue Tests,
> +943 Zeilen.

### Added
- **ADR 0012:** Damage-Number-VFX — befriedigendes Hit-Feedback. Bei
  jedem Treffer fliegt ein Label vom Mob nach oben + fadet aus.
- `core/ui/damage_number.gd` + `.tscn` — Floating-Label mit Tween-
  Lifecycle, Self-Free, static `_format_amount` (1500 → "1.5K").
  Crit-Visualisierung: gelb + größer + längere Animation.
- `core/ui/health_bar.gd` erweitert um `spawn_damage_numbers`-Flag
  (Default true) und `_spawn_damage_number()`-Hook.
- `tests/unit/test_damage_number.gd` — 11 Tests (Format, Lifecycle,
  HealthBar-Integration, Crit-Visualisierung).

### Visuelle Konsequenz
- Player schlägt Raptor → "15" fliegt vom Raptor nach oben
- Mit triceratops_horns: "17" (15 × 1.15)
- Crit-Treffer: "30" in gelb, größer, länger
- Damage > 1000: "1.5K" kompakt

### Test-Suite
- 22 Scripts, 277 Tests, 518 Asserts — alle grün.

### Added
- **ADR 0022:** Rarity-gewichtete Mutation-Picks — Pick-Phase wählt
  jetzt nach Rarity (Common 70 / Rare 25 / Epic 4.5 / Legendary 0.5).
- `core/ui/mutation_pick_overlay.gd` erweitert um:
  - `const RARITY_WEIGHTS` als Public-API
  - `set_rng()`-Hook für deterministische Tests (analog CritModifier)
  - `_weighted_pick_one()` mit Floating-Point-Rounding-Schutz
  - Without-Replacement via Pool-Erase
- `tests/unit/test_mutation_pick_overlay.gd` um 6 Weighting-Tests:
  Konstanten, Determinismus, Pool-only-Common, Pool-only-Rare,
  Without-Replacement, statistische Verteilung (100 Trials).

### Strategische Konsequenz
- Rare-Mutationen (spinosaur_sail, t_rex_jaw, pterodactyl_glide)
  werden ~21% pro Pick angeboten — fühlen sich als „Big-Moment" an.
- Common-Mutationen häufiger, aber synergistisch sinnvoll.

### Test-Suite
- 21 Scripts, 266 Tests, 505 Asserts — alle grün.

---

## [0.0.5] - 2026-05-06

> **Phase 2.5 — Game-Feel-Layer und Build-Variation.** Spieler hat
> während des Spielens HUD-Information (Wave/Timer/Mutationen),
> entscheidet zwischen Wellen aktiv über Mutationen, und kann erstmals
> echte Builds aufbauen — Damage, Speed oder Tank. Plus: Engine-Update
> auf Godot 4.6.
>
> 2 neue ADRs (0020 HUD, 0021 Mutation-Pick), Engine-Update,
> Mutation-Pool 3 → 7, 33 neue Tests, +1427 Zeilen.

### Changed
- **Godot-Engine-Version: 4.3 → 4.6**. project.godot, CI-Workflow,
  README, ARCHITECTURE.md aktualisiert. Lokale Sandbox-Tests laufen
  weiter mit 4.3 (kompatibel), das Repo verlangt aber 4.6.

### Added
- **Mutation-Pool ausgebaut: 3 → 7.** Pick-Phase hat jetzt echte
  Build-Variation. Lore-writer hat Tooltips im Comic-paläontologischen
  Stil geschrieben.
- `content/mutations/velociraptor_dash.tres` (common, speed-build):
  +20% Tempo, +10% Pickup-Radius
- `content/mutations/t_rex_jaw.tres` (rare, big-bite-damage):
  +25% Damage, +10% Crit-Damage
- `content/mutations/stegosaurus_thagomizer.tres` (common, hybrid):
  +15% Damage, +5% Crit-Chance
- `content/mutations/pterodactyl_glide.tres` (rare, speed+pickup):
  +25% Tempo, +15% Pickup-Radius
- BALANCE.csv um 4 Einträge erweitert.
- locale/{de,en}.po um 4 × 2 = 8 neue Translation-Keys.
- agents/memory/lore-writer/tone-of-voice.md mit 7 Mutations-Beispielen
  und Pattern-Doku.
- `tests/unit/test_content_loader.gd` um Pool-Größe-Test (`>= 7`) und
  Pool-Inklusion-Test (alle 4 neuen IDs vorhanden).
- `tests/unit/test_mutation_pick_overlay.gd`: 2 Tests robust gegen
  Pool-Wachstum gemacht.

### Erste Build-Pfade
- **Damage-Build**: triceratops_horns + spinosaur_sail + t_rex_jaw +
  stegosaurus_thagomizer
- **Speed-Build**: velociraptor_dash + pterodactyl_glide
- **Tank-Build**: ankylosaur_plates

### Test-Suite
- 21 Scripts, 260 Tests, 487 Asserts — alle grün.

### Added
- **ADR 0021:** Mutation-Pick-Phase nach jeder Welle — Mutationen sind
  endlich diegetisch! Wave-Ende → Pause → 3 zufällige nicht-gepickte
  Mutationen → Spieler wählt → weiter mit aktiver Mutation.
- `core/ui/mutation_pick_overlay.gd` + `.tscn` — CanvasLayer Layer 80,
  PROCESS_MODE_WHEN_PAUSED. Public-API: `show_pick_phase`,
  `hide_overlay`, `get_offered_ids`, `_on_pick` (Test-Hook).
- `core/wave_spawner.gd` erweitert um:
  - `@export var auto_advance: bool = true` (Default: Backward-Kompat)
  - `request_next_wave()` — Public-API für externe Wave-Trigger
- `core/run_scene/run.tscn` — MutationPickLayer als Child.
- `tests/unit/test_mutation_pick_overlay.gd` — 12 Tests inkl.
  Pick-Logic, Edge-Cases, Pause-Toggle, Cross-Mutation mit WaveSpawner.

### Test-Suite
- 21 Scripts, 258 Tests, 481 Asserts — alle grün.

### Gotcha aufgedeckt
- **Global-State-Leak via auto_advance**: MutationPickOverlay._ready
  setzt das Flag global. Andere Suites müssen es in before_each
  zurücksetzen.

### Added
- **ADR 0020:** HUD (Run-Timer, Wave-Counter, Mutation-Liste) — Spieler
  hat jetzt Game-Information während des Spielens.
- `core/ui/hud.gd` + `.tscn` — CanvasLayer-Overlay (Layer 50), drei
  Labels: Wave (oben links), Timer (oben mitte), Mutations (oben rechts).
  Listet auf run_started/ended, wave_started, mutations_changed; pollt
  RunState.get_run_time im _process.
- `core/run_scene/run.tscn` — HUDLayer als Child instantiiert,
  GameOverLayer (Layer 100) liegt darüber.
- `tests/unit/test_hud.gd` — 15 Tests (Format-Helper, Update-Methoden,
  Visibility, EventBus-Hooks).

### Was sichtbar wird
- F5 zeigt jetzt zusätzlich:
  - Wave 1 / Wave 2 / Wave 3 ×1.2 (oben links)
  - 0:00 → 0:23 → 1:47 (oben mitte, läuft mit Run)
  - (no mutations) oder Liste gepickter Mutationen (oben rechts)
- HUD verschwindet beim Tod (GameOver-Overlay liegt darüber).

### Test-Suite
- 20 Scripts, 242 Tests, 455 Asserts — alle grün.

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
