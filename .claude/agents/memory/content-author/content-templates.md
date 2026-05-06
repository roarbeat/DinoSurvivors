# Content Templates

> Vom `content-author` gepflegt. Boilerplate für jeden Content-Typ.

## Mutation (.tres)

```
[gd_resource type="Resource" script_class="MutationDef" load_steps=2 format=3 uid="uid://<unique>"]
[ext_resource type="Script" path="res://core/content/mutation_def.gd" id="1_mutdef"]

[resource]
script = ExtResource("1_mutdef")
id = &"<snake_case_id>"
display_name_key = &"mutation.<id>.name"
description_key = &"mutation.<id>.tooltip"
source_mod_id = &""
override_existing = false
rarity = &"common"  ; common | rare | epic | legendary
stat_modifiers = { &"<stat_key>": <float> }
tags = [&"<tag>"]
```

Nach Anlegen IMMER:
1. ID in `content-id-registry.md` eintragen
2. Translation-Keys in `locale/de.po` UND `locale/en.po` ergänzen
3. Eintrag in `BALANCE.csv` (mit Stats und Tags)
4. lore-writer für Tooltip-Text triggern

## Enemy (.tres)

```
[gd_resource type="Resource" script_class="EnemyDef" load_steps=2 format=3 uid="uid://<unique>"]
[ext_resource type="Script" path="res://core/content/enemy_def.gd" id="1_enmdef"]

[resource]
script = ExtResource("1_enmdef")
id = &"<snake_case_id>"
display_name_key = &"enemy.<id>.name"
description_key = &"enemy.<id>.tooltip"
max_health = <float>
speed = <float>
damage = <float>
xp_reward = <int>
```

## Dino (.tres)

```
[gd_resource type="Resource" script_class="DinoDef" load_steps=2 format=3 uid="uid://<unique>"]
[ext_resource type="Script" path="res://core/content/dino_def.gd" id="1_dinodef"]

[resource]
script = ExtResource("1_dinodef")
id = &"<snake_case_id>"
display_name_key = &"dino.<id>.name"
description_key = &"dino.<id>.tooltip"
max_health = <float>
base_speed = <float>
base_damage = <float>
base_attack_rate = <float>      ; Attacks pro Sekunde
pickup_radius = <float>
; character_scene = preload("...")  ; optional, ergänzt Combat-ADR
```

## Boss (.tres)

(folgt sobald Phasen-Schema spezifiziert ist — Phase 0 nutzt Stub)
