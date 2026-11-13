# Widget Pripravenost (Connect IQ)

Widget pre Garmin hodinky, ktory si z **intervals.icu** stiahne vase denne wellness data
a vypocita jedno ranne **skore pripravenosti 0–100** – podobne ako Garmin Training Readiness,
ale zo vsetkych aktivit (Edge 540 aj hodinky).

Podporovane hodinky: **Vivoactive 4S, Venu 3S, Venu 3, Forerunner 255 Music / 255S Music**
(dalsie sa daju pridat, vid nizsie).

Na Forerunneri 255 sa widget ovlada tlacidlami: **START** prepne detail, **podrzanie UP** (menu) obnovi data.

![nahlad](nahlad.png)

---

## Ako sa pocita skore

| Zlozka | Vaha | Odkial | Ako sa hodnoti |
|---|---|---|---|
| **Forma** | 35 % | intervals.icu (fitness – unava, zo vsetkych aktivit) | forma v % z fitness: +10 % a viac = 95 b., 0 % = 80 b., −20 % = 50 b., −40 % = 15 b. |
| **HRV** | 30 % | nocna HRV z hodiniek | dnesna hodnota oproti vasmu priemeru za ~4 tyzdne (z-skore) |
| **Spanok** | 20 % | hodinky | skore spanku; ak chyba, dlzka spanku (8 h = 100 b., 6 h = 65 b.) |
| **Pokojovy tep** | 15 % | hodinky | vyssi ako vas priemer = horsie |

Ak niektora zlozka chyba, vahy sa automaticky prepocitaju. **Vivoactive 4S HRV nemeria**,
takze skore sa pocita z formy, spanku a tepu. Po prechode na Venu 3S sa HRV zapocita samo,
netreba nic menit.

Pasma: **80+ Vyborna**, 60–79 Dobra, 40–59 Priemerna, 25–39 Nizka, pod 25 Velmi nizka.

Na priemer (baseline) HRV a tepu treba aspon 5 dni dat za posledne 4 tyzdne. Kym ich nie je dost, zlozka sa vynecha a v detaile sa namiesto skore ukaze pocet dni, napr. `3d`.

### Ovladanie
- **Stlacenie / klepnutie** – prepne medzi prehladom a detailom zloziek (skore kazdej zlozky, dnes / priemer).
- **Podrzanie (menu)** – vynutene obnovenie dat.
- Data sa pri otvoreni widgetu obnovia automaticky, ak su starsie ako 30 minut.

---

## Zostavenie a instalacia (cca 20–30 min prvykrat)

### 1. Nainstalujte nastroje (zadarmo)
1. **Visual Studio Code** – https://code.visualstudio.com
2. **Connect IQ SDK Manager** – https://developer.garmin.com/connect-iq/sdk/
   - Prihlaste sa Garmin uctom, stiahnite najnovsie **SDK**.
   - V zalozke **Devices** stiahnite **vivoactive 4S** (a neskor **Venu 3S**).
3. Vo VS Code nainstalujte rozsirenie **Monkey C** (od Garminu).
4. Vo VS Code: `Ctrl+Shift+P` → **Monkey C: Verify Installation**.
5. `Ctrl+Shift+P` → **Monkey C: Generate a Developer Key** (ulozte si ho, potrebujete ho na kazde zostavenie).

### 2. Vlozte svoj API kluc
1. Na intervals.icu: **Settings → Developer Settings** (dole na stranke) → vygenerujte **API key**.
2. Skopirujte vzor `properties.example.xml` do `resources/properties/properties.xml`.
3. V `resources/properties/properties.xml` nahradte `SEM_VLOZTE_API_KLUC` svojim klucom.
4. `athleteId` nechajte `0` (= vas ucet). Ak by widget hlasil chybu ID, zadajte svoje ID
   z adresy intervals.icu v tvare `i123456`.

> `resources/properties/properties.xml` je v `.gitignore`, takze sa vas kluc nikdy nedostane do gitu.
> Kluc vsak bude sucastou skompilovaneho suboru `.prg`. Ten nikomu neposielajte.

### 3. Vyskusajte v simulatore
1. Vo VS Code otvorte priecinok `ReadinessWidget` (File → Open Folder).
2. `Ctrl+F5` (Run Without Debugging) → vyberte **vivoactive4s**.
3. Simulator sa pripoji priamo na internet, takze uvidite skutocne data z vasho uctu.

### 4. Nahrajte do hodiniek
1. `Ctrl+Shift+P` → **Monkey C: Build for Device** → vyberte **vivoactive4s** → vyberte vystupny priecinok.
2. Pripojte hodinky USB kablom.
   - **Windows**: hodinky sa zobrazia ako disk/zariadenie.
   - **Mac**: pouzite **OpenMTP** alebo Android File Transfer (hodinky pouzivaju MTP).
3. Skopirujte vzniknuty subor `.prg` do priecinka **GARMIN/APPS** v hodinkach.
4. Odpojte hodinky. Widget najdete v zozname widgetov (na Vivoactive 4S potiahnutim hore/dole).
   Ak sa nezobrazi, pridajte ho v nastaveniach hodiniek → Widgety.

Hodinky robia webove poziadavky cez telefon, takze musi byt spustena aplikacia **Garmin Connect**
a hodinky musia byt s telefonom spojene.

---

## Pridanie dalsich hodiniek (napr. Venu 4, Forerunner 170)
Vo VS Code: `Ctrl+Shift+P` → **Monkey C: Edit Products** → zaskrtnite hodinky.
Najprv ich stiahnite v SDK Manageri (Devices). Rozlozenie obrazovky sa prisposobi samo.

---

## Riesenie problemov

| Hlasenie | Pricina |
|---|---|
| *Chyba API kluc* | kluc nie je vlozeny v `properties.xml` |
| *Zly API kluc / ID* (401/403) | nespravny kluc; vygenerujte novy |
| *Nespravne ID atleta* (404) | zadajte ID v tvare `i123456` |
| *Telefon nepripojeny* | hodinky nie su spojene s telefonom / nebezi Garmin Connect |
| *Odpoved prilis velka* | malo pamate; v `DataFetcher.mc` znizte `CHUNK_DAYS` na 4 a zvyste `CHUNKS` na 7 |
| *Neplatna odpoved* (−400) | starsi firmware nevie spracovat odpoved; dajte vediet, upravime format |
| Spanok / tep `--` | hodinky este nesynchronizovali poslednu noc do Garmin Connect a intervals.icu |

---

## Struktura projektu
```
manifest.xml                    hodinky, opravnenia, typ aplikacie (widget)
monkey.jungle                   konfiguracia zostavenia
properties.example.xml          vzor pre API kluc (skopirujte do resources/properties/properties.xml)
resources/properties/           API kluc a ID atleta (+ nastavenia pre Garmin Connect)
source/ReadinessApp.mc          vstupny bod aplikacie
source/ReadinessView.mc         kreslenie obrazovky, cache, chybove hlasenia
source/ReadinessDelegate.mc     ovladanie (tlacidla / dotyk)
source/DataFetcher.mc           stahovanie dat z intervals.icu po 7-dnovych castiach
source/ReadinessCalc.mc         vypocet skore (vahy a pasma sa daju upravit hore v subore)
```
