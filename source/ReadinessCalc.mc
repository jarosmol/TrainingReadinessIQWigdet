import Toybox.Lang;
import Toybox.Math;

// Vypocet skore pripravenosti (0-100) z dennych wellness dat intervals.icu.
//
// Zlozky a vahy:
//   Forma   35 %  - TSB v % z CTL (fitness - unava), pocita intervals.icu zo vsetkych aktivit
//   HRV     30 %  - nocna HRV vs. vlastny priemer za ~4 tyzdne (z-skore)
//   Spanok  20 %  - skore spanku z hodiniek, inak dlzka spanku
//   Pokojovy tep 15 % - vs. vlastny priemer (vyssi = horsie)
//   Body Battery 20 % - ranne maximum, IBA ak chyba HRV (napr. Vivoactive 4S)
// Ak niektora zlozka chyba (napr. Vivoactive 4S nema HRV), vahy sa prepocitaju
// medzi dostupne zlozky.
module ReadinessCalc {

    const W_FORM = 0.35;
    const W_HRV = 0.30;
    const W_SLEEP = 0.20;
    const W_RHR = 0.15;
    const W_BB = 0.20;    // Body Battery iba namiesto HRV (prekryva sa so spankom)
    const BASE_DAYS = 27;     // baseline HRV a tepu = predchadzajucich 27 dni (~4 tyzdne)
    const K_CTL = 0.976472;   // exp(-1/42): denny pokles fitness (intervals.icu)
    const K_ATL = 0.866878;   // exp(-1/7):  denny pokles unavy
    const MIN_BASELINE = 7;   // minimalny pocet dni pre baseline HRV / tepu

    function clamp(x, lo, hi) {
        if (x < lo) { return lo; }
        if (x > hi) { return hi; }
        return x;
    }

    // Linearna interpolacia, xs vzostupne.
    function interp(x, xs, ys) {
        if (x <= xs[0]) { return ys[0]; }
        var n = xs.size();
        if (x >= xs[n - 1]) { return ys[n - 1]; }
        for (var i = 1; i < n; i++) {
            if (x <= xs[i]) {
                var t = (x - xs[i - 1]) / (xs[i] - xs[i - 1]);
                return ys[i - 1] + t * (ys[i] - ys[i - 1]);
            }
        }
        return ys[n - 1];
    }

    // [priemer, smerodajna odchylka]
    function meanSd(values) {
        var n = values.size();
        var sum = 0.0;
        for (var i = 0; i < n; i++) { sum += values[i]; }
        var mean = sum / n;
        var sq = 0.0;
        for (var j = 0; j < n; j++) {
            var d = values[j] - mean;
            sq += d * d;
        }
        var sd = (n > 1) ? Math.sqrt(sq / (n - 1)) : 0.0;
        return [mean, sd];
    }

    function formScore(ctl, atl) {
        if (ctl == null || atl == null) { return null; }
        if (ctl < 1.0) { return null; }
        var pct = (ctl - atl) / ctl * 100.0;
        // pasma podla zon intervals.icu: -10 az -30 % je "optimalny" trening,
        // preto sa tam penalizuje miernejsie; pod -30 % (vysoke riziko) skore rychlo klesa
        return interp(pct,
            [-50.0, -40.0, -30.0, -20.0, -10.0, 0.0, 10.0],
            [ 10.0,  25.0,  45.0,  60.0,  75.0, 85.0, 95.0]);
    }

    function hrvScore(today, baseline) {
        if (today == null || baseline.size() < MIN_BASELINE) { return null; }
        var ms = meanSd(baseline);
        var sd = ms[1];
        var floor = ms[0] * 0.05;
        if (sd < floor) { sd = floor; }
        if (sd <= 0.0) { return null; }
        var z = (today - ms[0]) / sd;
        return clamp(85.0 + 25.0 * z, 5.0, 100.0);
    }

    function rhrScore(today, baseline) {
        if (today == null || baseline.size() < MIN_BASELINE) { return null; }
        var ms = meanSd(baseline);
        var sd = ms[1];
        if (sd < 1.0) { sd = 1.0; }
        var z = (today - ms[0]) / sd;
        return clamp(85.0 - 25.0 * z, 5.0, 100.0);
    }

    function sleepScoreFrom(score, secs) {
        if (score != null) { return clamp(score, 0.0, 100.0); }
        if (secs != null && secs > 0) {
            return interp(secs / 3600.0,
                [4.0, 5.0, 6.0, 7.0, 8.0],
                [20.0, 40.0, 65.0, 85.0, 100.0]);
        }
        return null;
    }

    // Hodnota z pola dna; index: 0 hrv, 1 rhr, 2 sleepSecs, 3 sleepScore, 4 ctl, 5 atl
    function field(days, key, idx) {
        if (key == null || !days.hasKey(key)) { return null; }
        return days[key][idx];
    }

    // Najnovsi z dvoch dni (dnes, vcera), ktory ma danu hodnotu.
    function pickDay(days, today, yest, idx) {
        if (field(days, today, idx) != null) { return today; }
        if (field(days, yest, idx) != null) { return yest; }
        return null;
    }

    // Baseline zlozky idx z dni keys[from..to) okrem dna skipKey.
    function baselineWindow(days, keys, from, to, skipKey, idx) {
        var out = [];
        var end = to < keys.size() ? to : keys.size();
        for (var j = from; j < end; j++) {
            var k = keys[j];
            if (skipKey != null && k.equals(skipKey)) { continue; }
            var v = field(days, k, idx);
            if (v != null) { out.add(v); }
        }
        return out;
    }

    // Sviezost RANO dna keys[i] (pred dnesnym treningom): vcerajsie fitness a unava
    // znizene o jeden den rovnako ako v intervals.icu (exponencialny pokles, 42 a 7 dni).
    // Vrati [skore, percento] alebo [null, null].
    function morningForm(days, keys, i) {
        if (i + 1 >= keys.size()) { return [null, null]; }
        var ctl = field(days, keys[i + 1], 4);
        var atl = field(days, keys[i + 1], 5);
        if (ctl == null || atl == null) { return [null, null]; }
        ctl = ctl * K_CTL;
        atl = atl * K_ATL;
        var sc = formScore(ctl, atl);
        if (sc == null) { return [null, null]; }
        return [sc, (ctl - atl) / ctl * 100.0];
    }

    // Vazeny priemer dostupnych zloziek. parts: [[skore alebo null, vaha], ...],
    // prvy prvok musi byt forma. Vrati [celkove skore alebo null, pocet zloziek].
    function combine(parts) {
        var sum = 0.0;
        var wsum = 0.0;
        var count = 0;
        for (var i = 0; i < parts.size(); i++) {
            if (parts[i][0] != null) {
                sum += parts[i][0] * parts[i][1];
                wsum += parts[i][1];
                count++;
            }
        }
        if (count >= 2 || (count == 1 && parts[0][0] != null)) {
            return [sum / wsum, count];
        }
        return [null, count];
    }

    // Body Battery (ranne maximum) -> skore. Pouziva sa iba ako nahrada HRV.
    function bodyBatteryScore(peak) {
        if (peak == null) { return null; }
        return interp(peak,
            [30.0, 50.0, 70.0, 85.0, 95.0],
            [10.0, 40.0, 70.0, 90.0, 100.0]);
    }

    // days: Dictionary "YYYY-MM-DD" -> [hrv, rhr, sleepSecs, sleepScore, ctl, atl] (Float alebo null)
    // keys: datumy od dnes (keys[0]) dozadu.
    // bbPeak: ranne maximum Body Battery z hodiniek (alebo null).
    // Vrati Dictionary s celkovym skore a zlozkami (vhodne na ulozenie do Storage).
    function compute(days, keys, bbPeak) {
        var today = keys[0];
        var yest = keys[1];

        // Forma
        var fDay = pickDay(days, today, yest, 4);
        var ctl = field(days, fDay, 4);
        var atl = field(days, fDay, 5);
        var fScore = formScore(ctl, atl);
        var fPct = null;
        if (fScore != null) { fPct = (ctl - atl) / ctl * 100.0; }
        // Sviezost rano (bez dnesnych treningov)
        var mf = morningForm(days, keys, 0);
        if (fDay != today) {   // pickDay vracia ten isty objekt, staci porovnat referenciu
            // dnesny zaznam este nie je - aktualny stav = ranny
            fScore = mf[0];
            fPct = mf[1];
        }

        // HRV
        var hDay = pickDay(days, today, yest, 0);
        var hVal = field(days, hDay, 0);
        var hBase = baselineWindow(days, keys, 0, BASE_DAYS + 1, hDay, 0);
        var hScore = hrvScore(hVal, hBase);
        var hMean = (hBase.size() > 0) ? meanSd(hBase)[0] : null;

        // Body Battery - iba ak HRV skore chyba (hodinky HRV nemeraju alebo este
        // nie je dost dni). Body Battery sa pocita aj z HRV, preto nikdy oboje naraz.
        var bScore = null;
        if (hScore == null) { bScore = bodyBatteryScore(bbPeak); }

        // Pokojovy tep
        var rDay = pickDay(days, today, yest, 1);
        var rVal = field(days, rDay, 1);
        var rBase = baselineWindow(days, keys, 0, BASE_DAYS + 1, rDay, 1);
        var rScore = rhrScore(rVal, rBase);
        var rMean = (rBase.size() > 0) ? meanSd(rBase)[0] : null;

        // Spanok (iba z poslednej noci = dnesny zaznam, pripadne vcerajsi)
        var sDay = pickDay(days, today, yest, 2);
        if (sDay == null) { sDay = pickDay(days, today, yest, 3); }
        var sSecs = field(days, sDay, 2);
        var sSc = field(days, sDay, 3);
        var sScore = sleepScoreFrom(sSc, sSecs);

        var c = combine([[fScore, W_FORM], [hScore, W_HRV], [bScore, W_BB],
                         [sScore, W_SLEEP], [rScore, W_RHR]]);
        // Ranne skore: rovnake zlozky, iba sviezost bez dnesnych treningov
        var m = combine([[mf[0], W_FORM], [hScore, W_HRV], [bScore, W_BB],
                         [sScore, W_SLEEP], [rScore, W_RHR]]);

        return {
            "score" => c[0],
            "n" => c[1],
            "morning" => [m[0], mf[1]],
            "form" => [fScore, fPct],
            "hrv" => [hScore, hVal, hMean, hBase.size()],
            "bb" => [bScore, bbPeak],
            "sleep" => [sScore, sSecs, sSc],
            "rhr" => [rScore, rVal, rMean, rBase.size()]
        };
    }

    // RANNE skore dna keys[i]: sviezost zo stavu pred treningom toho dna, spanok, HRV
    // a tep toho dna, baseline z 27 predchadzajucich dni. Body Battery historia nie je
    // dostupna, preto sa v historii nepouziva.
    function dayScore(days, keys, i) {
        var d = keys[i];
        var mf = morningForm(days, keys, i);
        var hScore = hrvScore(field(days, d, 0),
            baselineWindow(days, keys, i + 1, i + 1 + BASE_DAYS, null, 0));
        var rScore = rhrScore(field(days, d, 1),
            baselineWindow(days, keys, i + 1, i + 1 + BASE_DAYS, null, 1));
        var sScore = sleepScoreFrom(field(days, d, 3), field(days, d, 2));
        return combine([[mf[0], W_FORM], [hScore, W_HRV],
                        [sScore, W_SLEEP], [rScore, W_RHR]])[0];
    }

    // Ranne skore za poslednych n dni: index 0 = dnes. Dnesok doplni volajuci
    // rannym skore z compute() (s nahradnymi hodnotami z vcera a Body Battery).
    function history(days, keys, n) {
        var out = [];
        for (var i = 0; i < n; i++) {
            out.add(dayScore(days, keys, i));
        }
        return out;
    }
}
