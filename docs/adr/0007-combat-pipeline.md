# ADR 0007 – Combat-Pipeline (Component-Pattern, Damage-Flow)

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), game-designer + shader-fx-specialist (konsultiert)
- Betrifft Prinzipien: #2 EventBus, #5 Mod-freundlich, #7 alleine testbar
- Voraussetzungen: ADR 0001 (EventBus), ADR 0006 (Run-Lifecycle), ADR 0003 (ContentLoader)
- Wird vorausgesetzt von: Player-Char-Scene, Enemy-Spawn-System, UI/HUD

---

## 1. Kontext

ADR 0006 hat das Run-Lifecycle-Skelett geliefert. WaveSpawner feuert Wave-
Signals, aber es gibt **noch nichts, das stirbt**. Zeit für Combat — aber
**eng gefasst**: nur die Damage-Pipeline. Tatsächliche Hit-Detection
(Area2D-Layer), Movement, Visuelle Effekte und Spawn-Mechanik bleiben für
spätere ADRs (Combat ist ein großes Feld, das modulares Wachsen braucht).

Anforderungen v1:

- **Component-Pattern**: HealthComponent und DamageDealerComponent als Node-
  Childs, die an Player- und Enemy-Scenes gehängt werden. Komponenten sind
  alleine instanziierbar und unit-testbar.
- **Strukturierter Damage-Payload**: `DamageInfo`-Resource mit amount,
  damage_type, source_id, is_crit. Plain-Float-Damage wäre zu fragil für
  Mutation-Synergien (`crit_synergy`, `armor_pierce`, …).
- **Hot-Path-Trennung**: `take_damage()` ist ein direkter Methoden-Aufruf,
  KEIN EventBus-Signal — das wäre ein Hot-Path-Verstoß (siehe ADR 0001).
  Bus-Signals nur für **bedeutsame** State-Changes: `enemy_died`,
  `player_damaged`, `player_died`.
- **Mod-Hook-Punkte**: HealthComponent emittet lokale Signals (`damage_taken`,
  `healed`, `died`) — Mods können sich an spezifische Komponenten hängen.
- **Stub-statt-Scene**: v1 hat noch keine Player- oder Enemy-Scene. Das
  Component-Pattern wird mit reinen Node-Trees getestet — Scenes kommen mit
  ADR 0008 (Player-Scene) und ADR 0009 (Enemy-Spawn).

## 2. Optionen

### Option A — Komponenten als Node-Children + DamageInfo-Resource (empfohlen)

```
PlayerCharacter (CharacterBody2D)
├── HealthComponent (Node)
│     state: max_hp, current_hp
│     signals (lokal): damage_taken(info), healed(amount), died(info)
└── DamageDealerComponent (Node)
      methods: deal_damage(target_health, info)

EnemyMob (CharacterBody2D)
├── HealthComponent (Node)
└── DamageDealerComponent (Node)
```

`DamageInfo` ist eine `Resource`-Klasse mit getypten Feldern. Sie wird
beim Damage-Event als ein Argument übergeben.

**Pro**
- Komponenten sind *alleine* instanziierbar — perfekt für Unit-Tests
- Wiederverwendbar zwischen Player und Enemies (DRY)
- Mod-Hooks pro Komponente, nicht über globale Bus-Signal-Hose
- Resource-Format für DamageInfo erlaubt Mod-Authoren, eigene damage_types
  zu definieren ohne API-Bruch

**Contra**
- Mehr Boilerplate als „HP als float in Player.gd"
- Component-Tree-Lookups (`$HealthComponent`) sind Convention, nicht
  Compiler-erzwungen → bei Refactoring leicht zu vergessen

### Option B — Damage als EventBus-Signal

`EventBus.damage_dealt(source_id, target_id, amount)` mit globaler Routing-
Tabelle.

**Pro**
- Mods sehen jeden Damage-Event ohne Component-Lookup
- Telemetrie quasi geschenkt

**Contra**
- **Hot-Path-Verstoß**: Damage-Ticks können bei vielen Gegnern + Crit-
  Cascades > 100×/s erreichen. ADR 0001 hat das explizit verboten.
- Routing-Tabelle braucht globale ID-Auflösung (Performance-Killer)
- Schwer zu testen ohne Bus-Setup
- Reihenfolge der Damage-Effekte (Armor → Damage → Lifesteal) wird über
  Connection-Order gesteuert — fragil

### Option C — Damage als direkter Methoden-Aufruf (`target.hp -= 5`)

**Pro**
- Maximale Performance
- Trivial verstanden

**Contra**
- Kein strukturiertes Damage-Payload → Crit, Lifesteal, damage_type sind
  über separate Wege geleitet → Verzettelung
- Kein einheitlicher Mod-Hook
- Kein einheitlicher Death-Pfad (jeder Caller muss HP-Check selbst machen)

## 3. Empfehlung

**Option A** — Komponenten + DamageInfo-Resource.

**Begründung**
- Hält Hot-Path-Code performant (direkte Calls)
- Erlaubt strukturierte Erweiterung (neuer damage_type ist additiv)
- Lokale Component-Signals sind Mod-Hook und Test-Hook in einem
- Globale Bus-Signals nur für bedeutsame Events: `enemy_died`,
  `player_damaged` (genug für Telemetrie und HUD-Updates)

**DamageInfo — Schema**

```gdscript
class_name DamageInfo extends Resource

@export var amount: float = 0.0
@export var damage_type: StringName = &"physical"  # physical|fire|poison|true|...
@export var source_id: StringName = &""             # wer hat zugefügt? (mutation_id, enemy_id, …)
@export var is_crit: bool = false
@export var pierce_armor: bool = false              # ignoriert Armor
```

`damage_type` ist eine offene StringName — Mods dürfen neue Typen einführen.
Damage-Resistance-Tables auf der Empfänger-Seite respektieren das.

**HealthComponent — Public-API**

```gdscript
class_name HealthComponent extends Node

@export var max_hp: float = 100.0
@export var is_player: bool = false  # entscheidet, welches Bus-Signal beim Tod feuert

signal damage_taken(info: DamageInfo, hp_after: float)
signal healed(amount: float, hp_after: float)
signal died(info: DamageInfo)

func take_damage(info: DamageInfo) -> void
func heal(amount: float) -> void
func get_hp() -> float
func get_hp_pct() -> float                   # 0.0..1.0
func is_dead() -> bool
```

Beim Tod feuert HealthComponent das lokale `died`-Signal. Wenn `is_player`
true ist, feuert es zusätzlich `EventBus.player_died`. Wenn ein Owner einen
`enemy_id` als Property hat, feuert es `EventBus.enemy_died(enemy_id, pos)`.
Wer setzt diesen `enemy_id`? Der Spawner — über eine Convention auf dem
Owner-Node (`@export var enemy_id: StringName`).

**DamageDealerComponent — Public-API**

```gdscript
class_name DamageDealerComponent extends Node

func deal_damage(target_health: HealthComponent, info: DamageInfo) -> void
```

Der Dealer übergibt einfach an `target_health.take_damage(info)`. Warum
braucht es ihn dann? Damit Mutation-Effekte (z.B. „+15% Damage")
zentralisiert auf einem Node hängen können — der Dealer könnte später
das DamageInfo modifizieren bevor es zugefügt wird.

**EventBus-Integration (welche Signals feuert HealthComponent direkt)**

| Event | Signal | Begründung |
|-------|--------|------------|
| player_damaged | EventBus.player_damaged(amount, source_id) | HUD-HP-Bar, Damage-Indicator |
| player_died | EventBus.player_died() | Run-Ende, Music-Switch, Game-Over-Screen |
| enemy_died | EventBus.enemy_died(enemy_id, pos) | XP-Drop, Kill-Counter, Telemetrie |

**Performance-Regel (Wiederholung aus ADR 0001)**

`take_damage()` ist Hot-Path. Auch das `damage_taken`-Signal ist Hot-Path,
aber LOKAL — Mods, die sich pro Tick verbinden, akzeptieren die Kosten.
GLOBALE Bus-Signals (player_damaged, enemy_died) sind nur für **bedeutsame**
Events — nicht jeden Tick, nur einmal pro Treffer-Burst (Implementation
darf hier batchen, wenn nötig).

## 4. Konsequenzen

**Positiv**
- Combat-Logik ist End-to-End headless testbar (siehe ADR 0006)
- Mutation-Effekte können auf zwei Stellen einhängen: DamageDealer
  (modifiziert outgoing) oder HealthComponent (modifiziert incoming)
- DamageInfo ist Resource → Mods können eigene damage_types ohne API-Bruch

**Negativ**
- Component-Convention ist nicht Compiler-erzwungen. Wer eine
  HealthComponent vergisst, sieht das erst zur Laufzeit.
  Mitigation: gut-Test prüft pro Player- und Enemy-Scene, dass eine
  HealthComponent existiert (sobald die Scenes da sind).

**Risiken**
- **Risiko:** Damage-Reihenfolge bei mehreren Mutationen unbestimmt
  (z.B. Crit zuerst oder Lifesteal zuerst?)
  → **Mitigation:** Modifier-Pipeline auf DamageDealer wird in einem späteren
  ADR formalisiert (Backlog: Modifier-Order-System).
- **Risiko:** Damage-Numbers (Floating-Text) werden über Bus-Signal getrieben
  → Hot-Path-Verstoß
  → **Mitigation:** Damage-Numbers HÖREN auf das LOKALE `damage_taken`-Signal
  des HealthComponent, der jeweils im Sichtbereich ist — nicht global.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/combat/damage_info.gd`            DamageInfo-Resource
- `core/components/health_component.gd`   HealthComponent
- `core/components/damage_dealer_component.gd`  DamageDealer
- `tests/unit/test_damage_info.gd`        gut-Tests
- `tests/unit/test_health_component.gd`   gut-Tests
- `tests/unit/test_damage_dealer.gd`      gut-Tests
- `content/enemies/raptor_grunt.tres`     Erste Enemy-Resource
- `BALANCE.csv`                           raptor_grunt-Eintrag
- `locale/{de,en}.po`                     enemy.raptor_grunt.* keys
- `docs/ARCHITECTURE.md`                  Combat-Pattern dokumentieren

Berührt später:
- ADR 0008 — Player-Scene (HealthComponent + DamageDealer wird angeflanscht)
- ADR 0009 — Enemy-Spawn-System (WaveSpawner ergänzt)
- ADR 0010 — Modifier-Pipeline (DamageDealer wird erweitert)
- ADR 0011 — Hit-Detection (Area2D-Layer, Player-Mob-Kollision)

## 6. Folge-Entscheidungen (Backlog)

- ADR 0008 — Player-Scene mit Movement
- ADR 0009 — Enemy-Spawn-System (WaveSpawner ergänzt um spawn_enemy())
- ADR 0010 — Modifier-Pipeline (Crit, Lifesteal, Armor-Pen)
- ADR 0011 — Hit-Detection und Collision-Layer
- ADR 0012 — Damage-Number-VFX
