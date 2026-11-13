import Toybox.Lang;
import Toybox.Math;

// Vypocet skore pripravenosti (0-100) z dennych wellness dat intervals.icu.
//
// Zlozky a vahy:
//   Forma   35 %  - TSB v % z CTL (fitness - unava), pocita intervals.icu zo vsetkych aktivit
//   HRV     30 %  - nocna HRV vs. vlastny priemer za ~4 tyzdne (z-skore)
//   Spanok  20 %  - skore spanku z hodiniek, inak dlzka spanku
//   Pokojovy tep 15 % - vs. vlastny priemer (vyssi = horsie)
// Ak niektora zlozka chyba (napr. Vivoactive 4S nema HRV), vahy sa prepocitaju
// medzi dostupne zlozky.
module ReadinessCalc {

    const W_FORM = 0.35;
    const W_HRV = 0.30;
    const W_SLEEP = 0.20;
    const W_RHR = 0.15;
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
        return interp(pct,
            [-50.0, -40.0, -30.0, -20.0, -10.0, 0.0, 10.0],
            [  5.0,  15.0,  30.0,  50.0,  65.0, 80.0, 95.0]);
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

    function baselineExcluding(days, skipKey, idx) {
        var out = [];
        var keys = days.keys();
        for (var i = 0; i < keys.size(); i++) {
            if (skipKey != null && keys[i].equals(skipKey)) { continue; }
            var v = days[keys[i]][idx];
            if (v != null) { out.add(v); }
        }
        return out;
    }

    // days: Dictionary "YYYY-MM-DD" -> [hrv, rhr, sleepSecs, sleepScore, ctl, atl] (Float alebo null)
    // Vrati Dictionary s celkovym skore a zlozkami (vhodne na ulozenie do Storage).
    function compute(days, today, yest) {
        // Forma
        var fDay = pickDay(days, today, yest, 4);
        var ctl = field(days, fDay, 4);
        var atl = field(days, fDay, 5);
        var fScore = formScore(ctl, atl);
        var fPct = null;
        if (fScore != null) { fPct = (ctl - atl) / ctl * 100.0; }

        // HRV
        var hDay = pickDay(days, today, yest, 0);
        var hVal = field(days, hDay, 0);
        var hBase = baselineExcluding(days, hDay, 0);
        var hScore = hrvScore(hVal, hBase);
        var hMean = (hBase.size() > 0) ? meanSd(hBase)[0] : null;

        // Pokojovy tep
        var rDay = pickDay(days, today, yest, 1);
        var rVal = field(days, rDay, 1);
        var rBase = baselineExcluding(days, rDay, 1);
        var rScore = rhrScore(rVal, rBase);
        var rMean = (rBase.size() > 0) ? meanSd(rBase)[0] : null;

        // Spanok (iba z poslednej noci = dnesny zaznam, pripadne vcerajsi)
        var sDay = pickDay(days, today, yest, 2);
        if (sDay == null) { sDay = pickDay(days, today, yest, 3); }
        var sSecs = field(days, sDay, 2);
        var sSc = field(days, sDay, 3);
        var sScore = sleepScoreFrom(sSc, sSecs);

        // Vazeny priemer dostupnych zloziek
        var parts = [[fScore, W_FORM], [hScore, W_HRV], [sScore, W_SLEEP], [rScore, W_RHR]];
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
        var total = null;
        if (count >= 2 || (count == 1 && fScore != null)) {
            total = sum / wsum;
        }

        return {
            "score" => total,
            "n" => count,
            "form" => [fScore, fPct],
            "hrv" => [hScore, hVal, hMean],
            "sleep" => [sScore, sSecs, sSc],
            "rhr" => [rScore, rVal, rMean]
        };
    }
}
