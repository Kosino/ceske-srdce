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

## Civilizace (multiplayer)
| Civilizace   | Unikátní jednotka          | Hlavní síla          |
|--------------|--------------------------|---------------------|
| Moravané    | Velmož knížecí družiny  | Early, dřevo       |
| Přemyslovci | Svatováclavský rytíř     | Mid, zlato + jízda |
| Husité      | Husitský bojový vůz      | Mid/Late, pěchota  |
| Habsburkové | Císařská garda          | Late, těžká pěchota|

## Core loop
Resources → Stavění → Produkce jednotek → Combat → Postup věků

## Balance – prototyp (schváleno 2026-11-17)

Měřítko: 1 dlaždice = 40 px. Vesničan nese 10 jednotek suroviny. Start: 200 J, 200 D, 100 Z, 0 K.
Těžba za sekundu na vesničana: dřevo 0.40, jídlo z keřů 0.30, farma 0.33, zlato 0.35, kámen 0.35.

| Jednotka | Cena | Čas | HP | Útok | Dosah | Rychlost |
|----------|------|-----|----|------|-------|----------|
| Vesničan | 50 J | 25 s | 25 | 3 | melee | 80 px/s |
| Zbrojnoš | 60 J, 20 Z | 21 s | 45 | 6 | melee | 80 px/s |
| Kopiník | 35 J, 25 D | 22 s | 45 | 3 (+15 vs jízda) | melee | 85 px/s |
| Lučištník | 25 D, 45 Z | 35 s | 30 | 4 (projektil ~400 px/s) | 160 px | 80 px/s |

| Budova | Cena | Stavba | HP | Funkce |
|--------|------|--------|----|--------|
| Radnice | start | – | 2400 | +5 populace, drop-off vše, trénuje vesničany |
| Dům | 25 D | 25 s | 550 | +5 populace (strop 200) |
| Pila | 100 D | 35 s | 1000 | drop-off dřevo |
| Mlýn | 100 D | 35 s | 1000 | drop-off jídlo, farmy |
| Kasárna | 175 D | 50 s | 1200 | Zbrojnoš, Kopiník |
| Střelnice | 175 D | 50 s | 1200 | Lučištník |

Poznámka: `population_max` = Radnice +5 a každý Dům +5, strop 200 (`GameManager.add_population_cap` / `can_add_population`).
Lučištník střílí šípem na zamčenou pozici cíle v okamžiku výstřelu; zásah jen pokud cíl u dopadu zůstal (jinak miss). Žádný friendly fire.