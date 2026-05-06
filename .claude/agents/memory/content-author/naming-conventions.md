# Naming Conventions

> Vom `content-author` gepflegt. Wie IDs aufgebaut sind.

## Allgemein

- Format: `snake_case`
- Erlaubte Zeichen: `a-z`, `0-9`, `_`
- Maximum: 40 Zeichen
- ASCII only — keine Umlaute, keine Sonderzeichen

## Pro Type

| Type | Beispiel | Convention |
|------|----------|------------|
| mutation | `triceratops_horns` | `<dino>_<feature>` oder `<theme>_<effect>` |
| enemy | `raptor_grunt` | `<species>_<role>` |
| boss | `tyrannosaurus_prime` | `<species>_<title>` |
| dino | `trex`, `raptor` | `<species>` (kurz, Spieler-Char-Slot) |

## i18n-Key-Format

`<type>.<id>.<field>` — z.B. `mutation.triceratops_horns.tooltip`.

Felder pro Type:
- mutation: `name`, `tooltip`
- enemy: `name`, `tooltip`
- boss: `name`, `tooltip`, `intro`
- dino: `name`, `tooltip`

## Reservierte Präfixe

`core_` ist Core-only — Mods dürfen das Präfix nicht nutzen.
ContentLoader rejectet Mod-IDs mit diesem Präfix automatisch.

## Stat-Keys (Auswahl, vollständige Liste in BALANCE.csv)

- `damage_pct` — additiver Damage-Modifier (0.15 = +15%)
- `crit_chance` — additiv, 0.0–1.0
- `crit_damage_pct` — multiplikativ
- `melee_range_pct` — additiv
- `move_speed_pct` — additiv
- `max_health_pct` — additiv
- `pickup_radius_pct` — additiv
