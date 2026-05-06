# art/bosses/

> Boss-Sprites + Scenes (ADR 0031).

## Spec

- **Frame-Größe**: 64×64 (deutlich größer als Enemies)
- **Pivot**: unten zentriert
- **Animation-State-Bedarf**: Idle (4), Walk (6), Hit (2), Death (6)
  + Phase-Specific-States (kommt mit Boss-Abilities-ADR)

## Erste Lieferung

`tyrannosaurus_prime.tscn` für `content/bosses/tyrannosaurus_prime.tres`.

## Phase-Tinting

ADR 0029 setzt `Visual.modulate` automatisch aus
`BossPhase.color_tint`. Sprite muss in der Idle-Texture neutral-grau
gehalten werden, damit das Tinting nicht doppelt wirkt.
