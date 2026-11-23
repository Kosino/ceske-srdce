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
| 3 Husitství | Hrad, Klášter, Tržiště *(NÁVRH)* | Rytíř; unikátní jednotky; Mnich |
| 4 Habsburkové | Univerzita *(NÁVRH techs)*; Obléhací dílna | Beranidlo, Trebuchet |

**Schváleno 2026-11-22 – Hrad:** 650 K, 120 s, HP 4800, 160×160, věk 3; šípy 8 pierce / 8 dlaždic; +10 populace. Trénuje unikátní jednotku civilizace (35 s). AI od věku 3 staví Hrad při kameni a míchá unikáty do vln.

**Unikátní jednotky (Hrad, 35 s):**
| Civ | Jednotka | Cena | HP | Útok | Zbroj | Rychlost | Poznámka |
|-----|----------|------|----|------|-------|----------|----------|
| Moravané | Bojovník s bradaticí | 60 J + 30 Z | 70 | 9 melee (+8 vs budovy) | 1/1 | 1.0× | Bradatice — typická zbraň velkomoravské pěchoty. |
| Přemyslovci | Družiník | 70 J + 70 Z | 120 | 11 melee | 2/3 | 1.3× jízda | Panovnická družina Přemyslovců, těžká jízda. |
| Husité | Válečný vůz | 110 D + 60 Z | 180 | 7 pierce / 5 dlaždic | 0/6 | 0.8× | Okovaný vůz z husitských vozových hradeb. |
| Habsburkové | Lancknecht | 55 J + 45 Z | 75 | 8 melee (+6 vs jízda) | 1/1 | 1.0× | Žoldnéřská pěchota císařských armád 16. stol. |

Civ bonusy + Kovárna platí i na unikáty (Kalené hroty na válečný vůz).

**Schváleno 2026-11-22 – Stáj:** 175 D, 45 s, HP 1500, 80×80, věk 2, vyžaduje Kasárnu. Lehký jezdec (80 J, 30 s, HP 60, útok 4, zbroj 0/2, 1.6×) / Rytíř věk 3 (60 J+75 Z, 30 s, HP 100, útok 10, zbroj 2/2, 1.35×). Kopiník +15 vs jízda. Přemyslovci +10 % dmg jízdy. Kovářství platí i na jízdu. AI od věku 2 staví Stáj a míchá lehkou jízdu do vln.

**Schváleno 2026-11-22 – Kovárna:** 150 D, 40 s, HP 1800, footprint 80×80. Sprite: `assets/sprites/buildings/blacksmith.png` (63×96).

**Kovárna – výzkum (Fáze 4):** fronta 1, jednou za tým. Poškození = max(1, útok − zbroj podle typu); lukostřelci pierce, ostatní melee.
| Tech | Efekt | Cena | Čas |
|------|-------|------|-----|
| Kovářství | +1 melee útok pěchota+jízda | 150 J | 50 s |
| Kroužková zbroj | pěchota +1 melee / +1 pierce zbroj | 100 J | 40 s |
| Kalené hroty | +1 útok lukostřelců | 100 J + 50 Z | 40 s |
Platí na existující i nově vycvičené jednotky. AI po postavení Kovárny zkoumá Kovářství a Kroužkovou zbroj.

**Univerzita – výzkum *(NÁVRH AoE II-like)*:** stejný systém jako Kovárna (fronta 1, jednou za tým). Platí na existující i nové budovy/jednotky/věže.

| Tech | Efekt | Cena | Čas |
|------|-------|------|-----|
| Zednictví | +10 % HP budovy + zdi | 150 D + 175 K | 60 s |
| Balistika | lukostřelci + věže +1 dlaždice dosahu *(zjednodušení; lead-target později)* | 300 D + 175 Z | 60 s |
| Strojní věž | věže +2 útok a +1 dlaždice dosahu | 200 D + 100 K | 50 s |

## Civilizace (multiplayer)
| Civilizace   | Unikátní jednotka          | Hlavní síla          |
|--------------|--------------------------|---------------------|
| Moravané    | Bojovník s bradaticí     | Early, dřevo       |
| Přemyslovci | Družiník                 | Mid, zlato + jízda |
| Husité      | Válečný vůz              | Mid/Late, pěchota  |
| Habsburkové | Lancknecht               | Late, těžká pěchota|

### Civilizace – bonusy (Fáze 2)

Default skirmish: hráč **Moravané**, AI **Husité**. Unikátní jednotky trénuje Hrad (`CivData`). Id: `habsburkove`.

**Schváleno 2026-11-22:**

| Civilizace | Bonusy |
|------------|--------|
| Moravané | +15 % těžba dřeva; −10 % cena budov za dřevo |
| Přemyslovci | +15 % těžba zlata; +10 % poškození jízdy |
| Husité | +10 % HP pěchoty; +5 % poškození pěchoty |
| Habsburkové | +10 % těžba kamene; +15 % HP pěchoty |

Pěchota = zbrojnoš, kopiník, lučištník, bojovník s bradaticí, lancknecht. Implementace: `CivData` + `GameManager.player_civ` / `enemy_civ`. UI stavby ukazují cenu po `adjust_building_cost`.

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
| Bojovník s bradaticí | 60 J, 30 Z | 35 s | 70 | 9 (+8 vs budovy) | melee | 80 px/s | 1/1 |
| Družiník | 70 J, 70 Z | 35 s | 120 | 11 melee | melee | 104 px/s (1.3×) | 2/3 |
| Válečný vůz | 110 D, 60 Z | 35 s | 180 | 7 pierce | 200 px | 64 px/s (0.8×) | 0/6 |
| Lancknecht | 55 J, 45 Z | 35 s | 75 | 8 (+6 vs jízda) | melee | 80 px/s | 1/1 |
| Beranidlo *(věk 4)* | 160 D, 75 Z | 36 s | 175 | 2 (+125 vs budovy) | melee (jen stavby) | 40 px/s | 0/7 |
| Trebuchet *(věk 4)* | 200 D, 200 Z | 50 s | 150 | 40 pierce (jen stavby) | 160–640 px | packed 48 / unpacked 0 | 2/8 |

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
| Hrad | 650 K | 120 s | 4800 | 160×160, věk 3; šípy 8 pierce / 8 dlaždic; +10 pop; unikátní jednotka |
| Palisáda *(Schváleno 2026-11-22)* | 2 D / dlaždice | 5 s | 250 | 40×40, věk 1; drag (rovně/úhlopříčně); blokuje cestu |
| Kamenná zeď *(Schváleno 2026-11-22)* | 5 K / dlaždice | 8 s | 1800 | 40×40, věk 2; drag; blokuje cestu |
| Brána *(Schváleno 2026-11-22)* | 30 K | 10 s | 1500 | nahrazuje 3 segmenty; vlastní jednotky projdou, nepřátelé ne |
| Strážní věž *(Schváleno 2026-11-22)* | 125 K + 25 D | 40 s | 1000 | 40×40, věk 2; útok 5 pierce / dosah 7 dlaždic |
| Klášter *(NÁVRH AoE II-like)* | 175 D | 40 s | 2100 | 80×80, věk 3; trénuje Mnicha |
| Tržiště *(NÁVRH AoE II-like)* | 175 D | 60 s | 2100 | 80×80, věk 3; obchod (základ) |
| Univerzita *(NÁVRH AoE II-like)* | 200 D | 60 s | 2100 | 80×80, věk 4; techy Zednictví / Balistika / Strojní věž |
| Obléhací dílna *(Schváleno T-13)* | 200 D | 60 s | 2100 | 80×80, věk 4; vyžaduje Univerzitu; Beranidlo + Trebuchet |

| Jednotka | Cena | Čas | HP | Funkce |
|----------|------|-----|----|--------|
| Mnich *(NÁVRH AoE II-like)* | 100 Z | 51 s | 30 | věk 3 (Klášter); léčení + konverze; bez klasického útoku; rychlost 56 px/s (0.7×); heal 4 HP/s / dosah 4 dlaždice; konverze ~8 s |
| Beranidlo *(Schváleno T-13)* | 160 D, 75 Z | 36 s | 175 | věk 4 (Obléhací dílna); jen budovy/zdi; útok 2 + **125 vs budovy**; zbroj 0/7; 40 px/s (0.5×) |
| Trebuchet *(Schváleno T-13)* | 200 D, 200 Z | 50 s | 150 | věk 4; jen budovy; pack/unpack 8 s; dosah 16 dlaždic / min 4; útok 40 pierce; zbroj 2/8; packed 48 px/s, unpacked 0 |

#### Rationale (AoE II + historie)
- **Beranidlo:** AoE II Battering Ram — pomalá „krabice“ s vysokou pierce zbrojí a obřím bonusem vs zdi/budovy; útok jen na stavby (žádný duel s pěchotou). Historicky berany u husitských/císařských obléhání (Žižkovo období — lámání bran a palisád).
- **Trebuchet:** AoE II Trebuchet — dlouhý dostřel, minimum range, musí se rozložit; střílí jen stavby. Pozdně středověké / raně novověké obléhací stroje (pákové prakové stroje) jako předloha „imperial“ věku Habsburků.

Oprava: vesničan RMB na poškozenou vlastní budovu/zeď — +1 HP/s; plná oprava stojí 25 % stavební ceny (odečítá se průběžně).

### Mapa & doly (Fáze 4)
Deterministický generátor (seed). U každé radnice (≤12 dlaždic): 1 les (~25 stromů), 6 keřů bobulí, 1 zlatý důl (7 dlaždic × 800), 1 kamenný důl (5 × 350). Zbytek mapy: 6–8 lesů + 2–3 doly (zlato/kámen), zrcadlově férové. Žádné zdroje na cestách/budovách.

Poznámka: `population_max` = Radnice +5 a každý Dům +5, strop 200 (`GameManager.add_population_cap` / `can_add_population`).
Lučištník střílí šípem na zamčenou pozici cíle v okamžiku výstřelu; zásah jen pokud cíl u dopadu zůstal (jinak miss). Žádný friendly fire.