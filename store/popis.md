# Podklady pre Connect IQ obchod

Subory v tomto priecinku:
- `ikona_500.png` – ikona aplikacie do obchodu (500 x 500)
- `1_prehlad.png`, `2_zlozky.png`, `3_historia.png`, `4_mesiac.png`, `5_glance.png` – snimky obrazovky
  (Forerunner 265, simulator, anglicky) – nahravat v tomto poradi

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
(form / freshness) that intervals.icu calculates from ALL your activities – including rides recorded
on a Garmin Edge with a power meter. Ideal if most of your training is not recorded on your watch.

Score factors:
- Freshness (35 %) – fitness minus fatigue ("form") from intervals.icu; negative = tired from recent training
- HRV (30 %) – last night's HRV compared with your own 4-week baseline
- Body Battery (20 %) – morning peak, used ONLY on watches without HRV (never together with HRV)
- Sleep (20 %) – sleep score or sleep duration
- Resting heart rate (15 %) – compared with your own 4-week baseline
HRV and resting HR: 85 = your usual value, higher = better than usual.

After a workout the score drops as fatigue rises; the morning score (before today's training)
stays visible next to it (e.g. 66 /87), and the factors screen shows morning freshness.

Screens: score overview → individual factors → last 7 days → last 30 days (average, min, max).
History shows each day's morning score. Glance support on watches with a glance list
(Forerunner, Venu 3, fenix and others). Switch screens with START / tap, or UP / DOWN on button watches.

Setup: in intervals.icu go to Settings → Developer Settings and generate an API key.
In the Garmin Connect app open this widget's settings and paste the API key.
Leave athlete ID as 0.

Requires a paired phone with Garmin Connect (data is downloaded from intervals.icu).
Not affiliated with intervals.icu or Garmin.

## Popis (SK)
Pripravenost premeni wellness data z intervals.icu na jedno ranne skore 0–100.

Na rozdiel od skore pocitaneho len z hodiniek pouziva formu (fitness minus unava), ktoru
intervals.icu pocita zo VSETKYCH aktivit – aj z jazd zaznamenanych na Garmin Edge s wattmetrom.

Zlozky: sviezost (forma z intervals.icu, zaporna = unava z treningu) 35 %, HRV 30 %, Body Battery 20 % (iba na hodinkach bez HRV), spanok 20 %,
pokojovy tep 15 %. Pri HRV a tepe znamena 85 vas bezny stav, viac = lepsie ako zvycajne.

Po treningu skore klesne (rastie unava); ranne skore pred dnesnym treningom ostava viditelne
vedla neho (napr. 66 /87) a na obrazovke zloziek je ranna sviezost.

Obrazovky: prehlad → zlozky → historia 7 dni → historia 30 dni (priemer, min, max).
Historia ukazuje ranne skore kazdeho dna. Podpora glance na hodinkach so zoznamom glances.
Prepinanie: START / klepnutie, na hodinkach s tlacidlami aj UP / DOWN.

Nastavenie: na intervals.icu v Settings → Developer Settings vygenerujte API kluc a vlozte
ho v aplikacii Garmin Connect do nastaveni tohto widgetu. ID atleta nechajte 0.

## Ochrana udajov (do formulara)
The app sends your intervals.icu API key only to intervals.icu (HTTPS) to download your
wellness data. No data is sent to the developer or any third party. Body Battery is read
on the watch and never leaves the device.
