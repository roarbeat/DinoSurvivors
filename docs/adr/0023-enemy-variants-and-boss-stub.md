# ADR 0023 – Enemy-Variants + Boss-Resource (Stub)

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), game-designer + lore-writer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #7 testbar
- Voraussetzungen: ADR 0009 (EnemyMob), ADR 0013 (Auto-Spawn-Curves), ADR 0003 (ContentLoader)
- Wird vorausgesetzt von: Boss-Spawn-Mechanik (eigenes ADR), WaveDef-Resource (eigenes ADR)

---

## 1. Kontext

Aktueller Stand: 1 EnemyDef (raptor_grunt), Auto-Spawn-Curve spawnt
ausschließlich diesen einen. Das Spiel sieht nach 30 Sekunden monoton aus.
BossDef-Resource ist seit ADR 0003 ein Stub, kein Boss-Content existiert.

Anforderungen v1:

- **3 neue EnemyDefs** mit unterschiedlichen Stat-Profilen (Wave-Curve
  fühlt sich eskalierend an):
  - `pteranodon` — Flieger, niedrige HP, hoher Speed
  - `raptor_alpha` — Schwerer Raptor, höhere HP/Damage
  - `armored_carnotaurus` — Tank, sehr hohe HP, niedriger Speed
- **1 BossDef-Resource** (`tyrannosaurus_prime`) als Content-Stub —
  spawn-bereit aber **nicht spawn-implementiert** in v1
- **WaveSpawner** wählt aus einem Pool je nach Welle-Index:
  Welle 1-2: nur raptor_grunt; Welle 3-5: + raptor_alpha; Welle 6+: alle
- **Lore-writer** schreibt Tooltips im etablierten Comic-Stil
- **Boss-Spawn-Mechanik** ist Backlog (eigenes ADR mit BossMob-Scene,
  Telegraphie, Phasen)

Bewusst NICHT in v1:

- Boss-Spawn-Code (eigenes ADR — braucht BossMob-Scene, Telegraphie,
  unterscheidbares Death-Signal)
- Mix-Wellen-Spawn (mehrere Enemy-Typen gleichzeitig in einer Welle —
  WaveDef-ADR später)
- Enemy-spezifische AI-Modes (jetzt nur Direkt-Walk, ADR 0017)
- Fliegen-Mechanik für Pteranodon (nur Stat-Profil, kein Layer-Bypass)
- Boss-Wellen-Erkennung (`_is_boss_wave(idx)`)

## 2. Optionen

### Option A — Pool-Rotation im Code, BossDef als Stub-Asset (empfohlen)

```gdscript
func _enemy_id_for_wave(idx: int) -> StringName:
    var pool := _pool_for_wave(idx)
    return pool[_rng.randi() % pool.size()]

func _pool_for_wave(idx: int) -> Array[StringName]:
    if idx <= 2:
        return [&"raptor_grunt"]
    if idx <= 5:
        return [&"raptor_grunt", &"raptor_alpha"]
    if idx <= 10:
        return [&"raptor_grunt", &"raptor_alpha", &"pteranodon"]
    return [&"raptor_grunt", &"raptor_alpha", &"pteranodon", &"armored_carnotaurus"]
```

BossDef-Resource liegt unter `content/bosses/tyrannosaurus_prime.tres`,
wird vom ContentLoader registriert, ist aber **nicht in der Spawn-Pipeline**
in v1.

**Pro**
- Klein, bestehende WaveSpawner-API minimal erweitert
- Boss-Asset ist da für späteren Boss-Spawn-ADR
- Pool-Rotation ist headless-testbar

**Contra**
- Pool-Code statt Pool-Daten — Modder können's nicht ohne Code-Change
  ändern (WaveDef-Resource adressiert das später)

### Option B — WaveDef als Content-Resource, dann Variants

Erst die WaveDef-Resource, dann die Enemies füllen.

**Pro**
- Daten-getrieben von Anfang an

**Contra**
- WaveDef-Schema ist eigene Design-Entscheidung (eigenes ADR)
- Wir wollen schnell sichtbare Variation, nicht Schema-Diskussion

### Option C — Alle Enemies sofort, Boss komplett implementieren

Inkl. BossMob-Scene + Boss-Spawn-Mechanik.

**Pro**
- Komplett

**Contra**
- Boss ist seine eigene Diskussion (Telegraphie, Phasen, eigene Scene)
- ADR wird zu groß
- Risiko: Boss-Implementation schiebt Enemy-Variants raus

## 3. Empfehlung

**Option A** — Pool-Rotation + BossDef-Stub.

**Begründung**
- Sichtbare Welt-Variation in v1 (drei neue Enemy-Typen)
- Boss-Resource ist da, Spawn-Mechanik kommt mit dediziertem ADR
- WaveDef-Resource (Option B) baut darauf auf, ohne API-Bruch

**Enemy-Stat-Profile**

| ID | Rarity (Tag) | HP | Speed | Damage | XP | Tags |
|----|--------------|-----|-------|--------|-----|------|
| raptor_grunt (existing) | swarm | 25 | 120 | 8 | 2 | melee, swarm |
| pteranodon | flying | 18 | 180 | 6 | 3 | flying, fast, fragile |
| raptor_alpha | mid | 60 | 140 | 18 | 6 | melee, mid_tier |
| armored_carnotaurus | tank | 150 | 80 | 25 | 12 | tank, slow, armored |

**Boss-Stat-Profil (Stub)**

| ID | HP | reward_currency | intro_text_key |
|----|-----|----------------|----------------|
| tyrannosaurus_prime | 800 | 50 | boss.tyrannosaurus_prime.intro |

`phases` bleibt leer in v1 — Phase-Schema kommt mit Boss-Spawn-ADR.

**Pool-Curve**

```
Welle  1-2:  [raptor_grunt]
Welle  3-5:  [raptor_grunt, raptor_alpha]
Welle  6-10: [raptor_grunt, raptor_alpha, pteranodon]
Welle 11+:   [raptor_grunt, raptor_alpha, pteranodon, armored_carnotaurus]
```

Spawn-Wahrscheinlichkeit pro Pool-Eintrag uniform — Rarity-Weighting
für Enemies ist eigenes ADR.

## 4. Konsequenzen

**Positiv**
- Welt fühlt sich nach Welle 3+ abwechslungsreicher an
- Boss-Asset existiert — Spawn-ADR kann sofort darauf aufbauen
- Pool-Curve ist transparent und testbar

**Negativ**
- BossDef ohne Spawn-Mechanik ist „unsichtbarer" Content. Bewusst
  gewählt — eingelistet als „bereit für Boss-Spawn-ADR".

**Risiken**
- **Risiko:** Spieler wundert sich, dass tyrannosaurus_prime nie
  erscheint.
  → **Mitigation:** Im CHANGELOG klar markiert als „Asset, nicht
  Spawn-bereit".

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `content/enemies/pteranodon.tres`
- `content/enemies/raptor_alpha.tres`
- `content/enemies/armored_carnotaurus.tres`
- `content/bosses/tyrannosaurus_prime.tres`
- locale/{de,en}.po — 4 × 2 = 8 neue Translation-Keys
- BALANCE.csv — 4 neue Zeilen
- agents/memory/content-author/content-id-registry.md — IDs registrieren
- agents/memory/lore-writer/tone-of-voice.md — neue Tooltip-Beispiele

Berührt:
- `core/wave_spawner.gd` — `_enemy_id_for_wave` + neue `_pool_for_wave`
- `tests/unit/test_wave_spawner.gd` — Pool-Curve-Tests

## 6. Folge-Entscheidungen (Backlog)

- ADR — Boss-Spawn-Mechanik: BossMob-Scene, Telegraphie,
  `boss_defeated`-Death-Pfad, Phasen-Schema
- ADR — WaveDef als Content-Resource: Spawn-Pools deklarativ
- ADR — Pteranodon-Flying-Layer (Bypass von Ground-Collision)
- ADR — Enemy-Spawn-Rarity (uniform vs. weighted)
