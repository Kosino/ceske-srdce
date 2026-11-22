# Design dokument – České srdce

## Základní informace
- **Žánr:** RTS ve stylu Age of Empires II
- **Období:** 863 (Cyril a Metoděj) – 1648 (Vestfálský mír)
- **Priorita:** Zábavný AoE-like feel s českou tematikou. Historická přesnost hlavně pro kampaň.
- **Vývoj:** Solo + AI (Grok/Cursor), Godot 4

## Ages
1. **Velká Morava**
2. **Přemyslovci**
3. **Husitství**
4. **Habsburkové**

### Věky – research a unlocky

Postup věku: výzkum v Radnici (fronta; během výzkumu Radnice netrénuje). Podmínka: **2 dokončené budovy z aktuálního věku** (Radnice se nepočítá). Unlock budov/jednotek: jedna tabulka `AgeData`.

**Schváleno 2026-11-22**:

| Přechod | Cena | Čas |
|---------|------|-----|
| 1 → 2 (Přemyslovci) | 500 J | 130 s |
| 2 → 3 (Husitství) | 800 J, 200 Z | 160 s |
| 3 → 4 (Habsburkové) | 1000 J, 800 Z | 190 s |

| Od věku | Budovy | Jednotky |
|---------|--------|----------|
| 1 Velká Morava | Dům, Pila, Mlýn, Kasárna | Vesničan, Zbrojnoš |
| 2 Přemyslovci | Střelnice, Kovárna, Stáj | Kopiník, Lučištník, Lehký jezdec |
| 3 Husitství | *(data-only)* monastery | Rytíř; *(data-only)* monk |
| 4 Habsburkové | *(data-only)* castle, university | *(data-only)* siege |

**Schváleno 2026-11-22 – Stáj:** 175 D, 45 s, HP 1500, 80×80, věk 2, vyžaduje Kasárnu. Lehký jezdec (80 J, 30 s, HP 60, útok 4, zbroj 0/2, 1.6×) / Rytíř věk 3 (60 J+75 Z, 30 s, HP 100, útok 10, zbroj 2/2, 1.35×). Kopiník +15 vs jízda. Přemyslovci +10 % dmg jízdy. Kovářství platí i na jízdu. AI od věku 2 staví Stáj a míchá lehkou jízdu do vln.

**Schváleno 2026-11-22 – Kovárna:** 150 D, 40 s, HP 1800, footprint 80×80. Sprite: `assets/sprites/buildings/blacksmith.png` (63×96).

**Kovárna – výzkum (Fáze 4):** fronta 1, jednou za tým. Poškození = max(1, útok − zbroj podle typu); lukostřelci pierce, ostatní melee.
| Tech | Efekt | Cena | Čas |
|------|-------|------|-----|
| Kovářství | +1 melee útok pěchota+jízda | 150 J | 50 s |
| Kroužková zbroj | pěchota +1 melee / +1 pierce zbroj | 100 J | 40 s |
| Kalené hroty | +1 útok lukostřelců | 100 J + 50 Z | 40 s |
Platí na existující i nově vycvičené jednotky. AI po postavení Kovárny zkoumá Kovářství a Kroužkovou zbroj.

## Civilizace (multiplayer)
| Civilizace   | Unikátní jednotka          | Hlavní síla          |
|--------------|--------------------------|---------------------|
| Moravané    | Velmož knížecí družiny  | Early, dřevo       |
| Přemyslovci | Svatováclavský rytíř     | Mid, zlato + jízda |
| Husité      | Husitský bojový vůz      | Mid/Late, pěchota  |
| Habsburkové | Císařská garda          | Late, těžká pěchota|

### Civilizace – bonusy (Fáze 2)

Default skirmish: hráč **Moravané**, AI **Husité**. Unikátní jednotky zatím data-only (`CivData`). Id: `habsburkove`.

**Schváleno 2026-11-22:**

| Civilizace | Bonusy |
|------------|--------|
| Moravané | +15 % těžba dřeva; −10 % cena budov za dřevo |
| Přemyslovci | +15 % těžba zlata; +10 % poškození jízdy |
| Husité | +10 % HP pěchoty; +5 % poškození pěchoty |
| Habsburkové | +10 % těžba kamene; +15 % HP pěchoty |

Pěchota = zbrojnoš, kopiník, lučištník. Implementace: `CivData` + `GameManager.player_civ` / `enemy_civ`. UI stavby ukazují cenu po `adjust_building_cost`.

### Formace (Fáze 2)

Skupinový pohyb (2+ jednotky): formace kolem cíle RMB; celá skupina jde rychlostí nejpomalejší jednotky. Přepínač v CommandPanel.
**Řada:** jednotky stojí vedle sebe na ose **kolmé** na směr pochodu (AoE II), ne podél něj.

**Schváleno 2026-11-22:**

| Formace | Spacing (středy) |
|---------|------------------|
| Řada (`line`) | 36 px |
| Rozptyl (`scattered`) | 56 px |
| Box (`box`) | 40 px |

### Lepší AI (Fáze 2)

Nepřítel = **Husité**. Vlastní stockpile (ne GameManager hráče). Bootstrap: radnice + 3 vesničané + zdroje. Economy: těžba, Dům, Kasárna, trénink zbrojnošů. Po `WAVE_MIN_UNITS` jednotkách vysílá vlnu na hráče.

**Schváleno (CS Designer) 2026-11-22:**

| Parametr | Hodnota |
|----------|---------|
| `WAVE_MIN_UNITS` | 3 |
| `WAVE_INTERVAL_SEC` | 40 s |
| Start AI stockpile | 220 J, 220 D, 80 Z |

## Core loop
Resources → Stavění → Produkce jednotek → Combat → Postup věků

## Balance – prototyp (schváleno 2026-11-17)

Měřítko: 1 dlaždice = 40 px. Vesničan nese 10 jednotek suroviny. Start: 200 J, 200 D, 100 Z, 0 K.
Těžba za sekundu na vesničana: dřevo 0.40, jídlo z keřů 0.30, farma 0.33, zlato/kámen = dřevo × 0.9 (0.36).

| Jednotka | Cena | Čas | HP | Útok | Dosah | Rychlost | Zbroj (M/P) |
|----------|------|-----|----|------|-------|----------|-------------|
| Vesničan | 50 J | 25 s | 25 | 3 | melee | 80 px/s | 0/0 |
| Zbrojnoš | 60 J, 20 Z | 21 s | 45 | 6 | melee | 80 px/s | 0/0 |
| Kopiník | 35 J, 25 D | 22 s | 45 | 3 (+15 vs jízda) | melee | 85 px/s | 0/0 |
| Lučištník | 25 D, 45 Z | 35 s | 30 | 4 pierce | 160 px | 80 px/s | 0/0 |
| Lehký jezdec | 80 J | 30 s | 60 | 4 melee | melee | 128 px/s (1.6×) | 0/2 |
| Rytíř *(věk 3)* | 60 J, 75 Z | 30 s | 100 | 10 melee | melee | 108 px/s (1.35×) | 2/2 |

| Budova | Cena | Stavba | HP | Funkce |
|--------|------|--------|----|--------|
| Radnice | start | – | 2400 | +5 populace, drop-off vše, trénuje vesničany |
| Dům | 25 D | 25 s | 550 | +5 populace (strop 200) |
| Pila | 100 D | 25 s | 600 | 80×80, drop-off dřevo |
| Důlní tábor | 100 D | 25 s | 600 | 80×80, drop-off zlato + kámen |
| Mlýn | 100 D | 35 s | 1000 | drop-off jídlo, farmy |
| Kasárna | 175 D | 50 s | 1200 | Zbrojnoš, Kopiník |
| Střelnice | 175 D | 50 s | 1200 | Lučištník |
| Kovárna *(Schváleno 2026-11-22)* | 150 D | 40 s | 1800 | věk 2 gate; techy viz výše |
| Stáj | 175 D | 45 s | 1500 | 80×80, věk 2, vyžaduje Kasárnu; Lehký jezdec / Rytíř |

### Mapa & doly (Fáze 4)
Deterministický generátor (seed). U každé radnice (≤12 dlaždic): 1 les (~25 stromů), 6 keřů bobulí, 1 zlatý důl (7 dlaždic × 800), 1 kamenný důl (5 × 350). Zbytek mapy: 6–8 lesů + 2–3 doly (zlato/kámen), zrcadlově férové. Žádné zdroje na cestách/budovách.

Poznámka: `population_max` = Radnice +5 a každý Dům +5, strop 200 (`GameManager.add_population_cap` / `can_add_population`).
Lučištník střílí šípem na zamčenou pozici cíle v okamžiku výstřelu; zásah jen pokud cíl u dopadu zůstal (jinak miss). Žádný friendly fire.