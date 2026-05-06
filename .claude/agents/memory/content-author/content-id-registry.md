# Content-ID Registry

> Vom `content-author` gepflegt. Jede vergebene ID kommt hier rein —
> einmal vergeben, NIEMALS umbenennen (Prinzip 6).

Format: `<type>:<id>` — kurze Notiz — Erstellungsdatum

## mutation

- `mutation:triceratops_horns` — Common, Horn-Build-Anker, +15% Damage / +10% Melee-Range — 2026-05-06
- `mutation:spinosaur_sail` — Rare, Crit-Build-Anker, +10% Crit-Chance / +50% Crit-Damage — 2026-05-06
- `mutation:ankylosaur_plates` — Common, Tank-Build-Anker, +20% Armor / +15% max HP — 2026-05-06
- `mutation:velociraptor_dash` — Common, Speed-Build-Anker, +20% Speed / +10% Pickup-Radius — 2026-05-06
- `mutation:t_rex_jaw` — Rare, Big-Bite-Damage, +25% Damage / +10% Crit-Damage — 2026-05-06
- `mutation:stegosaurus_thagomizer` — Common, Hybrid-Damage, +15% Damage / +5% Crit-Chance — 2026-05-06
- `mutation:pterodactyl_glide` — Rare, Speed+Pickup-Synergie, +25% Speed / +15% Pickup — 2026-05-06

## dino

- `dino:trex` — Allrounder-Starter-Char, 120 HP / 15 DMG / 180 Speed — 2026-05-06

## enemy

- `enemy:raptor_grunt` — Schwarm-Gegner, 25 HP / 8 DMG / 120 Speed — 2026-05-06
- `enemy:pteranodon` — Flieger, 18 HP / 6 DMG / 180 Speed — 2026-05-06
- `enemy:raptor_alpha` — Mid-Tier, 60 HP / 18 DMG / 140 Speed — 2026-05-06
- `enemy:armored_carnotaurus` — Tank, 150 HP / 25 DMG / 80 Speed — 2026-05-06

## boss

- `boss:tyrannosaurus_prime` — Stub, 800 HP / 50 currency reward — 2026-05-06
  (Spawn-Mechanik aktiv seit ADR 0025: alle 5 Wellen)

## wave (ADR 0026)

- `wave:wave_default` — Curve-Default (is_default=true), base_rate=0.5, per_wave=0.3, max=5.0 — 2026-05-06
- `wave:wave_5_tyrannosaurus` — Override Welle 5, Boss + {grunt; alpha; ptera} — 2026-05-06
- `wave:wave_10_tyrannosaurus` — Override Welle 10, Boss + {grunt; alpha; ptera; carno} — 2026-05-06

## sound (ADR 0028)

- `sound:sfx_enemy_died` — Enemy-Tod, vol=-3dB, pitch ±0.1 — Stub (stream=null) — 2026-05-06
- `sound:sfx_boss_defeated` — Boss-Defeat-Sting, vol=+2dB — Stub — 2026-05-06
- `sound:sfx_player_damaged` — Hit-Grunt, vol=0dB, pitch ±0.05 — Stub — 2026-05-06
- `sound:sfx_player_died` — Game-Over-Sting, vol=0dB — Stub — 2026-05-06
- `sound:sfx_mutation_picked` — Mutation-Confirm-Sting, vol=+1dB — Stub — 2026-05-06
- `sound:sfx_wave_started` — Wave-Incoming-Build-up, vol=-2dB — Stub — 2026-05-06

## Reservierte Präfixe

- `core_` darf nur Core-Content nutzen (Mod-Loader rejectet Mod-IDs mit
  diesem Präfix). Aktuell nutzen wir das Präfix bewusst nicht — schlanke
  IDs sind lesbarer. Bei Konflikten mit Mod-Universum später aktivieren.
