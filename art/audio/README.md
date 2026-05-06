# art/audio/

> Audio-Streams (.ogg) für SFX und Music.

## Spec

- **Format**: Ogg Vorbis (kleinere Files als WAV, in Godot nativ)
- **Sample-Rate**: 44.1 kHz oder 22.05 kHz (8-bit-Style sounds reichen
  niedrige Sample-Rates)
- **Mono** für SFX, Stereo für Music

## Erwartete Files

| File | SoundDef-Slot | Notes |
|------|---------------|-------|
| `enemy_death.ogg` | `sfx_enemy_died.tres` | Kurzer Knack, ~0.5s |
| `boss_defeated.ogg` | `sfx_boss_defeated.tres` | Final, ~2s mit Hall |
| `player_hit.ogg` | `sfx_player_damaged.tres` | Grunzer + Impact, 0.3s |
| `player_death.ogg` | `sfx_player_died.tres` | Game-Over-Sting, 1-2s |
| `mutation_confirm.ogg` | `sfx_mutation_picked.tres` | Positiv-Sting, 0.5s |
| `wave_incoming.ogg` | `sfx_wave_started.tres` | Build-up, 0.5-1s |

## Integration

Die `.ogg`-Files werden in `content/sounds/<sfx_id>.tres` auf
`stream` referenziert. SfxBus (ADR 0028) lauscht auf EventBus-Signals
und triggert Playback.

Music kommt mit eigenem ADR (Music-System).
