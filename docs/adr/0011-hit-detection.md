# ADR 0011 – Hit-Detection v1 (distanz-basiert)

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer (konsultiert)
- Betrifft Prinzipien: #2 EventBus, #7 testbar
- Voraussetzungen: ADR 0007 (Combat), ADR 0008 (Player), ADR 0009 (Enemy)
- Wird vorausgesetzt von: Damage-Number-VFX (ADR 0012), HUD

---

## 1. Kontext

Run-Scene ist bootbar (ADR 0016). Player schaut Enemies an, Enemies stehen
da. Was fehlt: tatsächliche Combat-Interaktion. Erstmals soll Damage
zwischen Player und Enemies fließen.

Anforderungen v1:

- **Player-Auto-Attack**: tickt periodisch (1 / base_attack_rate Sekunden),
  trifft alle Enemies in `attack_range` für `base_damage`
- **Touch-Damage**: Enemies, die nah genug am Player sind, fügen ihren
  `EnemyDef.damage` zu — mit **i-frames** (Invulnerability-Frames) nach
  jedem Hit, damit Player nicht in 1 Frame stirbt
- **Headless-testbar**: keine Area2D, keine Physics-Engine — pure
  Distanz-Math
- **Group-basiert**: Player + Enemy nutzen Godot-Groups („player",
  „enemy") für gegenseitiges Finden
- **Konsistent mit Combat-Pipeline (ADR 0007)**: alle Damage geht über
  DamageDealerComponent.deal_damage — Modifier-Pipeline wirkt

Bewusst NICHT in v1:

- Area2D-basierte Hit-Detection (Performance-Refactor falls nötig)
- Knockback / Stagger / Hitstop
- Player-Animation während Attack (eigenes Animations-ADR)
- Projectile-Attacks (separates ADR)
- Per-Enemy Touch-Cooldowns (vereinfacht zu globalen iframes auf Player)

## 2. Optionen

### Option A — Distanz-basiert + Groups (empfohlen)

```
PlayerCharacter._physics_process(delta):
    # Auto-Attack-Tick
    _attack_timer -= delta
    if _attack_timer <= 0:
        _do_auto_attack()
        _attack_timer = 1.0 / get_effective_attack_rate()

    # Touch-Damage (mit iframes)
    if Time.now > _invulnerable_until:
        var enemy := _find_nearest_enemy_in_radius(TOUCH_HIT_RADIUS)
        if enemy != null:
            enemy.dealer.deal_damage(health, DamageInfo.make(enemy_def.damage))
            _invulnerable_until = Time.now + IFRAMES_DURATION
```

**Pro**
- Komplett headless-testbar (kein Physics-Step nötig)
- Performance trivial (200 Enemies × 1 Distanz-Check = 200 Flops/Frame)
- Mod-API kompatibel (alle Damage geht durch DamageDealer/HealthComponent)
- Tests sind deterministisch — keine Frame-Race-Conditions

**Contra**
- Keine Sub-Pixel-genaue Detection (für Survivor-likes irrelevant)
- Spätere Refactor-Option falls Performance-Probleme: Area2D mit
  Collision-Layer, Konvention bleibt stabil

### Option B — Area2D + CollisionShape2D

Idiomatisches Godot — Player hat HitArea / HurtArea, Enemy auch.

**Pro**
- Engine-Unterstützung (Spatial-Indexing, Body-Enter-Signale)
- Sub-Pixel-genau

**Contra**
- Tests brauchen Physics-Frame-Stepping (komplex, nicht-deterministisch)
- Mehr Scene-Setup pro Mob
- Layer-Konvention muss strict gepflegt werden
- Kein klarer Vorteil für 200-Mob-Survivor-likes-Skala

### Option C — Custom Spatial-Hash

Eigener Spatial-Index für O(1)-Nachbarschafts-Suche.

**Pro**
- Maximale Performance bei 1000+ Enemies

**Contra**
- Premature Optimization für aktuelle Skala
- Mehr Code, mehr Bugs

## 3. Empfehlung

**Option A** — Distanz-basiert + Groups.

**Begründung**
- Performance ist kein Engpass auf realistischer Skala
- Headless-Tests sind Gold (siehe alle vorigen ADRs)
- Refactor-Pfad zu Area2D ist klar, falls nötig
- Konsistent mit der „möglichst viel pure Math"-Philosophie

**Konstanten (v1)**

```gdscript
const ATTACK_TICK_INTERVAL := 1.0  # Sek bis erstes Tick — danach 1/attack_rate
const TOUCH_HIT_RADIUS := 25.0     # Pixel — Enemy-zu-Player-Berührung
const IFRAMES_DURATION := 0.5      # Sek — Player-Invulnerability nach Hit
const ATTACK_RANGE_FALLBACK := 80.0 # Pixel — wenn DinoDef nichts hat
```

**Group-Konvention**

- `PlayerCharacter._ready` → `add_to_group(&"player")`
- `EnemyMob._ready` → `add_to_group(&"enemy")`

**Player-API-Erweiterung**

```gdscript
PlayerCharacter._do_auto_attack() -> int   # Anzahl getroffener Enemies
PlayerCharacter._check_touch_damage() -> bool  # true wenn Touch passiert
PlayerCharacter.is_invulnerable() -> bool
PlayerCharacter.get_attack_range() -> float
```

**Damage-Path**

Player-Attack: `player.dealer.deal_damage(enemy.health, DamageInfo.make(player_dino.base_damage, &"player_attack"))`

Enemy-Touch: `enemy.dealer.deal_damage(player.health, DamageInfo.make(enemy_def.damage, enemy_id))`

→ Modifier-Pipeline (Crit, Armor) wirkt automatisch.

**Test-Strategie**

Statt Physics-Frame-Stepping: direkt `_do_auto_attack()` und
`_check_touch_damage()` aus Test rufen. Edge-Cases:
- Enemy in/außerhalb Range → korrekter Damage-Anteil
- iframes blockieren zweiten Touch
- Mehrfaches Tick → Damage akkumuliert korrekt
- Mit Mutation: Damage skaliert (Pipeline-Konsistenz)

## 4. Konsequenzen

**Positiv**
- **Erstmals tatsächliches Mini-Spiel**: Player läuft auf Enemy zu,
  Enemy beißt Player, Player schlägt Enemy
- Hit-Detection-Pfad geht durch DamageDealer → alle Mutations-Modifier
  wirken
- Tests bleiben deterministisch und schnell

**Negativ**
- Touch-Damage nimmt nur EINEN Enemy pro Hit (den nähesten). Schwarm-
  Damage wird unterschätzt — bewusst, sonst wird Player in einem Frame
  ausradiert.
  → **Akzeptiert**: iframes machen das spielfair. Mehr-Damage-pro-Tick
  ist Boss-Mechanik (späteres ADR).

**Risiken**
- **Risiko:** Auto-Attack-Tick geht über `_physics_process` 60×/s — bei
  200 Enemies × 60 Hz = 12000 Distanz-Checks/Sek. Akzeptabel, aber falls
  doch Performance-Probleme: Tick-Intervall verlängern oder Spatial-Hash.
- **Risiko:** iframes als globaler Player-Timer funktioniert nicht für
  Multi-Player. Wir haben aktuell keinen Multi-Player — ggf. eigenes ADR.
- **Risiko:** `Time.get_ticks_msec()` ist game-pause-blind — pause-aware
  Timer kommt mit Pause-System.
  → **Mitigation:** v1 nutzt `_physics_process(delta)`-Akkumulation, das
  ist pause-aware out-of-the-box.

## 5. Betroffene Dateien & Systeme

Anzulegen / erweitern:
- `core/player/player_character.gd`     +Auto-Attack +Touch-Damage +iframes
- `core/enemy/enemy_mob.gd`              add_to_group(&"enemy")
- `tests/unit/test_player_character.gd`  +Hit-Detection-Tests
- `tests/unit/test_hit_detection.gd`     dedizierte Test-Suite

Berührt später:
- ADR 0012 Damage-Number-VFX (HUD lauscht auf damage_taken)
- ADR — Player-Animation (Attack-Frame, Hit-Reaktion)
- ADR — Boss-Mechaniken (Special-Attacks außerhalb Touch-Damage)

## 6. Folge-Entscheidungen (Backlog)

- ADR — Knockback / Stagger
- ADR — Projectile-Attacks
- ADR — Hit-Detection-Refactor zu Area2D (falls Performance es verlangt)
- ADR — Enemy-AI / Movement (jetzt sinnvoll wo Combat existiert)
