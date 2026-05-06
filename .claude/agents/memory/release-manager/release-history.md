# Release History

> Vom `release-manager` gepflegt.

## (noch keine Public-Releases)

## Internal Tags

### v0.0.6 — 2026-05-06 — Phase 2.6: Pick-Polish + Hit-Feedback

**Hauptänderungen:**
- ADR 0022 Rarity-gewichtete Picks (Common 70 / Rare 25 / Epic 4.5 / Legendary 0.5)
- ADR 0012 Damage-Number-VFX (Floating Numbers + Crit-Visualisierung)

**Was zum ersten Mal funktioniert:**
- Pick-Phase ist strategisch: Rare-Mutationen fühlen sich seltener und
  wertvoller an (~21% pro Pick statt 43% im uniform-Pool)
- Crit-Hits haben sichtbares Feedback: gelb + größer + längere Animation
- Damage-Format kompakt: 1500 → "1.5K"
- Without-Replacement: 3 Picks pro Phase, keine Duplikate

**Test-Suite:** 22 Scripts, 277 Tests, 518 Asserts — alle grün.

**Repo-Bilanz:** 14910 Zeilen total (+943 ggü. v0.0.5).

**Status:** Internal Tag. Phase 2.6 schließt das Mutation-Pick-Erlebnis ab.

### v0.0.5 — Phase 2.5: HUD + Pick + Pool + Godot 4.6

- Engine 4.3 → 4.6
- ADR 0020 HUD, ADR 0021 Mutation-Pick-Phase
- Mutation-Pool 3 → 7

**Test-Suite:** 21 Scripts, 260 Tests, 487 Asserts.

### v0.0.4 — Phase 2: spielbarer Mini-Game-Loop
**20 Scripts, 227 Tests.**

### v0.0.3 — Phase 1 vollständig: bootbares Skelett
**17 Scripts, 183 Tests.**

### v0.0.2 — Phase 1 Math-Pipeline
**13 Scripts, 128 Tests.**

### v0.0.1 — Phase 0 Skelett
**4 Scripts, 39 Tests.**

---

## Pre-Release-Checkliste-Status (aktuell)

| Check | Stand 2026-05-06 (v0.1.0) |
|-------|---------------------------|
| Tests grün | ✅ 406/406 (29 Scripts) |
| Save-Migration getestet | ✅ v1.1 additive Schema, Legacy-Saves laden mit amber=0 |
| Mod-API-Kompatibilität | ✅ nur additiv ggü. v0.0.6 (BossDef.phases-Type-Change ist Resource-Migration, kein Mod-Break) |
| BALANCE.csv aktuell | ✅ 22 Einträge synchron (mut+enemy+boss+wave+sound) |
| CHANGELOG.md hat Eintrag | ✅ v0.1.0-Block gefüllt + Phase-4-Highlight |
| Headless-Boot | ✅ MetaProgression+SfxBus laden ohne Crash |
| Godot-Version | ✅ 4.6 |
| Visual-Target-Doku | ✅ docs/art/VISUAL-TARGET.md |
| EventBus 4-fach-Sync | ✅ 22 Signals (Code/Test/Doku) |
| Version-Tag in Git | ⏳ vom User auszuführen |

## Roadmap

| Tag | Inhalt | Status |
|-----|--------|--------|
| v0.0.1 — v0.0.4 | Phase 0 + Phase 1 + Phase 2 (Math + Loop) | ✅ |
| v0.0.5 | Phase 2.5: HUD + Pick + Pool + Godot 4.6 | ✅ |
| v0.0.6 | Phase 2.6: Pick-Polish + VFX | ✅ |
| v0.0.7 | Mehr Enemies + Boss-Spawn (ADR 0023–0025) | ✅ |
| v0.0.8 | WaveDef als Content-Resource (ADR 0026) | ✅ |
| v0.0.9 | Visual-Provider + SFX-Bus Infrastruktur (ADR 0027/0028) | ✅ |
| **v0.1.0** | **Vertical-Slice: Boss-Phasen + Meta-Progression** (ADR 0029/0030) | ✅ bereit zum Tag |
| v0.1.x | Asset-Drop-Pass (Sprites + Audio referenzieren) | ⏳ |
| v0.2.0 | Meta-Shop-UI + zweite Boss-Mechanik | ⏳ |
