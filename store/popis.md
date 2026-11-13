# Podklady pre Connect IQ obchod

Subory v tomto priecinku:
- `ikona_500.png` – ikona aplikacie do obchodu (500 x 500)
- `1_prehlad.png`, `2_zlozky.png`, `3_historia.png` – snimky obrazovky (Forerunner 255, simulator)

Do obchodu sa nahrava subor `.iq` (Monkey C: Export Project), nie tieto obrazky.
Obrazky sa pridavaju vo formulari pri nahravani.

---

## Nazov
Readiness for intervals.icu

## Kratky popis (EN)
Morning training readiness score from your intervals.icu data – rides from your Edge, runs and hikes from your watch, HRV, sleep and resting heart rate.

## Popis (EN)
Readiness turns your intervals.icu wellness data into one morning score from 0 to 100.

Unlike readiness scores calculated only from your watch, it uses fitness and fatigue
(form) that intervals.icu calculates from ALL your activities – including rides recorded
on a Garmin Edge with a power meter. Ideal if most of your training is not recorded on your watch.

Score factors:
- Form (35 %) – fitness minus fatigue from intervals.icu
- HRV (30 %) – last night's HRV compared with your own 4-week baseline
- Body Battery (20 %) – morning peak, used ONLY on watches without HRV (never together with HRV)
- Sleep (20 %) – sleep score or sleep duration
- Resting heart rate (15 %) – compared with your own 4-week baseline

Screens: score overview → individual factors → last 7 days history.

Setup: in intervals.icu go to Settings → Developer Settings and generate an API key.
In the Garmin Connect app open this widget's settings and paste the API key.
Leave athlete ID as 0.

Requires a paired phone with Garmin Connect (data is downloaded from intervals.icu).
Not affiliated with intervals.icu or Garmin.

## Popis (SK)
Pripravenost premeni wellness data z intervals.icu na jedno ranne skore 0–100.

Na rozdiel od skore pocitaneho len z hodiniek pouziva formu (fitness minus unava), ktoru
intervals.icu pocita zo VSETKYCH aktivit – aj z jazd zaznamenanych na Garmin Edge s wattmetrom.

Zlozky: forma 35 %, HRV 30 %, Body Battery 20 % (iba na hodinkach bez HRV), spanok 20 %,
pokojovy tep 15 %. Obrazovky: prehlad → zlozky → historia 7 dni.

Nastavenie: na intervals.icu v Settings → Developer Settings vygenerujte API kluc a vlozte
ho v aplikacii Garmin Connect do nastaveni tohto widgetu. ID atleta nechajte 0.

## Ochrana udajov (do formulara)
The app sends your intervals.icu API key only to intervals.icu (HTTPS) to download your
wellness data. No data is sent to the developer or any third party. Body Battery is read
on the watch and never leaves the device.
