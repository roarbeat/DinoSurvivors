# art/enemies/

> Enemy-Sprites + Scenes (ADR 0031). Eine `.tscn` pro Enemy-Variante.

## Spec wie Player

Frame-Größe abhängig von Enemy-Variante:

| Enemy | Frame-Größe | Notes |
|-------|-------------|-------|
| `raptor_grunt` | 16×16 | Klein, schnell |
| `pteranodon` | 14×14 | Flieger, fragiler Look |
| `raptor_alpha` | 22×22 | Mid-Tier, dunkler |
| `armored_carnotaurus` | 28×28 | Tank-Silhouette, stämmig |

## Integration

Pro Enemy wird die `.tscn` in `content/enemies/<id>.tres` auf
`visual_scene` referenziert. ColorRect-Mode bleibt Fallback wenn
`visual_scene = null`.
