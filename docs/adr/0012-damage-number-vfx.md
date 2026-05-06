# ADR 0012 – Damage-Number-VFX

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), shader-fx-specialist (konsultiert)
- Betrifft Prinzipien: #2 EventBus (Hot-Path-Trennung!), #7 testbar
- Voraussetzungen: ADR 0007 (HealthComponent), ADR 0010 (DamageInfo), ADR 0018 (HealthBar)
- Wird vorausgesetzt von: VFX-Polish-ADRs (Hit-Flash, Crit-Bubble)

---

## 1. Kontext

Bei jedem Treffer wird HP reduziert, HealthBar schrumpft. Was fehlt: das
**befriedigende Feedback** der Floating-Damage-Numbers — klassisches
Survivor-likes-Element.

Anforderungen v1:

- **Floating Label** über getroffenem Mob, zeigt Damage-Wert
- **Crit-Visualisierung**: Crit-Treffer in anderer Farbe / größer
- **Tween-Animation**: nach oben fliegen + fade out, dann self-free
- **Lokal an HealthComponent gebunden** — kein EventBus-Aufruf
  (Hot-Path-Verstoß, siehe ADR 0007 §4)
- **Headless-testbar**: Format-Logik + Lifecycle trennbar von Tween

Bewusst NICHT in v1:

- Damage-Type-spezifische Farben (fire = orange, poison = grün …)
- Stacking gleicher Damage in einer Number (z.B. „×3")
- Kombinierte Hit-Flash + Camera-Shake (eigene VFX-ADRs)
- Number-Pool für Performance bei 100+ Hits/Sekunde
  (akzeptiert: queue_free + GC reicht für aktuelle Skala)

## 2. Optionen

### Option A — Damage-Number als Sub-Spawn der HealthBar (empfohlen)

HealthBar lauscht eh schon auf `damage_taken`. Spawnt zusätzlich
ein DamageNumber. Plus-Punkt: HealthBar kennt die Position des Mobs
(über parent), DamageNumber wird relativ zur HealthBar platziert.

```
HealthBar.set_health(hp)
HealthBar._on_damage_taken(info, hp_after):
    _update_visual()
    if spawn_damage_numbers:
        var dn := DAMAGE_NUMBER_SCENE.instantiate()
        get_tree().current_scene.add_child(dn)
        dn.show_damage(info.amount, info.is_crit, global_position)
```

**Pro**
- Eine Komponente, eine Verantwortung (visuelle Damage-Reaktion)
- Position-Lookup trivial via global_position
- DamageNumber lebt im Scene-Tree, nicht unter dem Mob (überlebt
  `mob.queue_free` bei tödlichem Treffer)

**Contra**
- HealthBar bekommt eine zweite Verantwortung (war: nur Bar). Toleriert
  weil beide Reaktionen auf das gleiche Signal sind.

### Option B — Eigene DamageFeedback-Komponente

Ein dritter Node neben HealthBar (`DamageFeedback`), der eigenständig
auf `damage_taken` lauscht.

**Pro**
- Strikteres SRP

**Contra**
- Doppelter Setup-Code in PlayerCharacter / EnemyMob
- Doppelter `set_health(hp)`-Call
- Mehr Komplexität für sehr ähnliche Funktion

### Option C — Globaler DamageNumberSpawner-Autoload

Ein 8. Autoload, der auf einem **globalen Bus-Signal** `damage_visualized`
hört.

**Pro**
- Keine Komponenten-Setup-Disziplin nötig

**Contra**
- **Bricht ADR 0007 §4** (Hot-Path-Verstoß): bei 200 Mobs × 10 Hits/s
  = 2000 Bus-Signals/s
- Ein weiterer Autoload (jetzt 8)

## 3. Empfehlung

**Option A** — Sub-Spawn der HealthBar.

**Begründung**
- Konsistent mit ADR 0018 (HealthBar als visuelle Damage-Reaktion)
- Hot-Path-Trennung gewahrt — alles bleibt lokal
- Keine zusätzliche Setup-Disziplin pro Mob

**DamageNumber-API**

```gdscript
class_name DamageNumber extends Node2D

func show_damage(amount: float, is_crit: bool, world_pos: Vector2) -> void

# Format-Helper (testbar)
static func _format_amount(amount: float) -> String   # "15", "+15", "1.5K"
```

**Visual-Spec v1**

| Element | Standard | Crit |
|---------|----------|------|
| Farbe | weiß `#FFFFFF` | gelb `#FFD000` |
| Schrift-Größe | 14 | 20 |
| Tween: move up | -30px | -50px |
| Tween: fade out | 0.7s | 0.9s |
| Spawn-Offset | -15px | -15px |

**Lifecycle**

```gdscript
func show_damage(amount, is_crit, world_pos):
    global_position = world_pos + Vector2(0, -15)
    label.text = _format_amount(amount)
    if is_crit:
        label.add_theme_color_override("font_color", Color.GOLD)
        label.add_theme_font_size_override("font_size", 20)
    var tween := create_tween().set_parallel()
    tween.tween_property(self, "position:y",
        global_position.y - (50 if is_crit else 30), 0.9)
    tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
    tween.chain().tween_callback(queue_free)
```

**HealthBar-Erweiterung**

```gdscript
@export var spawn_damage_numbers: bool = true
const DAMAGE_NUMBER_SCENE := preload("res://core/ui/damage_number.tscn")

func _on_damage_taken(info: DamageInfo, hp_after: float) -> void:
    _update_visual()
    if not spawn_damage_numbers or info == null:
        return
    var dn: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
    get_tree().current_scene.add_child(dn)
    dn.show_damage(info.amount, info.is_crit, global_position)
```

## 4. Konsequenzen

**Positiv**
- **Befriedigendes Hit-Feedback**: jeder Treffer hat sichtbare Wirkung
- **Crits sind Big-Moments**: gelb + größer + längere Animation
- Hot-Path-Trennung gewahrt — keine Bus-Pollution

**Negativ**
- 100+ Numbers/s in late-Wellen erzeugen kurzfristig Allokations-Last.
  In v1 akzeptabel — Object-Pool ist eigenes Performance-ADR.

**Risiken**
- **Risiko:** DamageNumber unter `current_scene` gehängt — wenn Run-Restart
  alle Children freed, könnten noch laufende Numbers Crash erzeugen.
  → **Mitigation:** queue_free ist robust gegen freed parents;
  Tween checkt Validität.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/ui/damage_number.gd` + `.tscn`
- `tests/unit/test_damage_number.gd`

Berührt:
- `core/ui/health_bar.gd` (+spawn_damage_numbers, +_on_damage_taken-Erweiterung)
- `tests/unit/test_health_bar.gd` (+Spawn-Hook-Test)

## 6. Folge-Entscheidungen (Backlog)

- ADR — Damage-Type-spezifische Farben
- ADR — Object-Pool für DamageNumbers (Performance)
- ADR — Hit-Flash auf Mob-Body (kurzes weißes Aufblitzen)
- ADR — Crit-Bubble (großer „CRIT!"-Text bei extrem hohen Crits)
