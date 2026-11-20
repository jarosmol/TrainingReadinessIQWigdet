import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.SensorHistory;
import Toybox.StringUtil;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Stiahne wellness data z intervals.icu po tyzdnovych castiach (9 x 7 dni),
// aby odpovede zostali male aj pre hodinky s malou pamatou (Vivoactive 4S).
class DataFetcher {

    const CHUNKS = 9;          // 9 x 7 = 63 dni: 30 dni historie + 4-tyzdnovy baseline
    const CHUNK_DAYS = 7;

    var _callback = null;   // Method(status as Symbol, payload)
    var _chunk = 0;
    var _days = null;

    const HISTORY_DAYS = 30;

    // Ranne maximum Body Battery (od polnoci) z historie senzorov hodiniek.
    // Hodinky bez tejto funkcie (alebo so starsim Connect IQ) vratia null.
    // Medzi polnocou a 5:00 este nove ranne maximum neexistuje - vtedy sa pouzije
    // posledne zname (zo vcera), ktore si widget uklada.
    static function readBodyBatteryPeak() {
        if (!(Toybox has :SensorHistory)) { return null; }
        if (!(Toybox.SensorHistory has :getBodyBatteryHistory)) { return null; }
        var today = DataFetcher.dateStr(0);
        var secs = Time.now().value() - Time.today().value();
        // (staticka funkcia nevidi konstanty triedy, preto priamo hodnota)
        var period = secs;
        if (secs < 5 * 3600) {
            var stored = Application.Storage.getValue("bbPeak");
            if (stored instanceof Lang.Dictionary) {
                var d = stored["d"] as String or Null;
                var v = stored["v"] as Float or Null;
                if (d != null && v != null &&
                    (d.equals(today) || d.equals(DataFetcher.dateStr(1)))) {
                    return v;
                }
            }
            // nic ulozene (napr. po vymazani dat) - maximum za poslednych 24 h
            period = 24 * 3600;
        }
        var it = Toybox.SensorHistory.getBodyBatteryHistory({
            :period => new Time.Duration(period)
        });
        if (it == null) { return null; }
        var peak = null;
        var sample = it.next();
        while (sample != null) {
            var val = sample.data;
            if (val != null && (peak == null || val > peak)) { peak = val; }
            sample = it.next();
        }
        if (peak == null) { return null; }
        var p = peak.toFloat();
        if (period == secs) {
            Application.Storage.setValue("bbPeak", { "d" => today, "v" => p });
            DataFetcher.saveBbHistory(today, p);
        }
        return p;
    }

    // Historia rannych maxim Body Battery (datum -> hodnota) pre 7- a 30-dnovu historiu.
    // Hodinky si historiu Body Battery drzia len par dni, preto si widget kazde dnesne
    // ranne maximum ulozi (poslednych 31 dni).
    static function saveBbHistory(date, value) {
        var h = Application.Storage.getValue("bbHist");
        var out = {};
        for (var k = 0; k < 31; k++) {
            var key = DataFetcher.dateStr(k);
            if (h instanceof Lang.Dictionary && h.hasKey(key)) { out.put(key, h[key]); }
        }
        out.put(date, value);
        Application.Storage.setValue("bbHist", out);
    }

    // Ulozene ranne maxima doplnene o tie, ktore este pamataju hodinky (posledne 3 dni,
    // maximum od polnoci do 12:00). Vdaka tomu ma Body Battery aj vcerajsi den v historii,
    // hoci ho widget vtedy este neukladal.
    static function bodyBatteryPeaks() {
        var out = {};
        var h = Application.Storage.getValue("bbHist");
        if (h instanceof Lang.Dictionary) { out = h; }
        if (!(Toybox has :SensorHistory)) { return out; }
        if (!(Toybox.SensorHistory has :getBodyBatteryHistory)) { return out; }
        var it = Toybox.SensorHistory.getBodyBatteryHistory({
            :period => new Time.Duration(3 * 86400)
        });
        if (it == null) { return out; }
        var today = DataFetcher.dateStr(0);
        // Bez Gregorian.info pre kazdu vzorku (pomale): den a hodina z casu v sekundach.
        var midnight = Time.today().value();
        var best = [null, null, null];     // maxima pre dnes, vcera, predvcerom (0-12 h)
        var sample = it.next();
        while (sample != null) {
            var v = sample.data;
            var when = sample.when;
            if (v != null && when != null) {
                var t = when.value();
                var ago = 0;                // 0 = dnes, 1 = vcera, 2 = predvcerom
                var dayStart = midnight;
                while (t < dayStart && ago < 3) { dayStart -= 86400; ago++; }
                if (ago < 3 && t - dayStart < 12 * 3600) {
                    var cur = best[ago] as Float or Null;
                    if (cur == null || v > cur) { best[ago] = v.toFloat(); }
                }
            }
            sample = it.next();
        }
        var found = {};
        for (var a = 1; a < 3; a++) {
            if (best[a] != null) { found.put(DataFetcher.dateStr(a), best[a]); }
        }
        // dnesok riesi readBodyBatteryPeak; ulozene hodnoty maju prednost
        var fk = found.keys();
        for (var i = 0; i < fk.size(); i++) {
            var key = fk[i] as String;
            if (!key.equals(today) && !out.hasKey(key)) { out.put(key, found[key]); }
        }
        return out;
    }

    var _busy = false;

    function initialize() {
    }

    function isBusy() {
        return _busy;
    }

    static function dateStr(daysAgo) {
        var t = Time.now().subtract(new Time.Duration(daysAgo * 86400));
        var i = Gregorian.info(t, Time.FORMAT_SHORT);
        return i.year.format("%04d") + "-" + i.month.format("%02d") + "-" + i.day.format("%02d");
    }

    static function readSetting(key) {
        var v = Application.Properties.getValue(key);
        if (v == null) { return ""; }
        return v.toString();
    }

    function start(callback) {
        if (_busy) { return; }
        var key = readSetting("apiKey");
        if (key.length() < 8 || key.equals("SEM_VLOZTE_API_KLUC")) {
            callback.invoke(:nokey, null);
            return;
        }
        _callback = callback;
        _chunk = 0;
        _days = {};
        _busy = true;
        requestChunk();
    }

    function requestChunk() {
        var athlete = readSetting("athleteId");
        if (athlete.length() == 0) { athlete = "0"; }
        var key = readSetting("apiKey");

        var token = StringUtil.convertEncodedString("API_KEY:" + key, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64
        });

        var newest = dateStr(_chunk * CHUNK_DAYS);
        var oldest = dateStr(_chunk * CHUNK_DAYS + CHUNK_DAYS - 1);

        Communications.makeWebRequest(
            "https://intervals.icu/api/v1/athlete/" + athlete + "/wellness",
            { "oldest" => oldest, "newest" => newest },
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => { "Authorization" => "Basic " + token },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onResponse)
        );
    }

    static function num(rec, name) {
        var v = rec[name];
        if (v == null) { return null; }
        if (v instanceof Lang.Number || v instanceof Lang.Float ||
            v instanceof Lang.Long || v instanceof Lang.Double) {
            return v.toFloat();
        }
        return null;
    }

    // Typy parametrov musia presne zodpovedat ocakavaniu Communications.makeWebRequest
    // (SDK 9.x ich kontroluje). Odpoved intervals.icu je JSON pole, preto ju
    // pretypujeme na Object a pole overime za behu.
    function onResponse(responseCode as Number,
            data as Null or ByteArray or Dictionary or String or PersistedContent.Iterator) as Void {
        if (responseCode != 200) {
            finish(:error, responseCode);
            return;
        }
        var body = data as Object or Null;
        // Ocakavame JSON pole (aj prazdne). Cokolvek ine znamena neuplne data -
        // radsej chyba, nez skore vypocitane z ciastocneho priemeru.
        if (!(body instanceof Lang.Array)) {
            _days = null;
            finish(:error, -400);
            return;
        }
        data = null;
        parseRecords(body);
        body = null;

        _chunk++;
        if (_chunk < CHUNKS) {
            requestChunk();
            return;
        }
        // Novy den zacina az novym spankom: po polnoci (do 12:00), kym intervals.icu nema
        // dnesny spanok, ale vcerajsi ma, sa ako "dnes" berie este vcerajsok. Inak by sa skore
        // po polnoci zmenilo, hoci clovek este nespal.
        var shift = 0;
        var secs = Time.now().value() - Time.today().value();
        if (secs < 12 * 3600 && !hasSleep(dateStr(0)) && hasSleep(dateStr(1))) {
            shift = 1;
        }
        var keys = [] as Array<String>;
        for (var k = 0; k < CHUNKS * CHUNK_DAYS - shift; k++) {
            keys.add(dateStr(k + shift));
        }
        var bb = (shift == 0) ? readBodyBatteryPeak() : bodyBatteryPeakFor(keys[0]);
        var result = ReadinessCalc.compute(_days, keys, bb);
        var hist = ReadinessCalc.history(_days, keys, HISTORY_DAYS, bodyBatteryPeaks());
        hist[0] = result["morning"][0];   // historia = ranne skore
        var labels = [];
        for (var k = 0; k < HISTORY_DAYS; k++) {
            var ds = keys[k] as String;   // "YYYY-MM-DD" -> den v mesiaci
            labels.add((ds.substring(8, 10).toNumber() as Number).format("%d"));
        }
        result.put("hist", hist);
        result.put("histDays", labels);
        _days = null;
        finish(:ok, result);
    }

    // Ma den v datach intervals.icu spanok (dlzku alebo skore)?
    function hasSleep(date) {
        if (_days == null || !_days.hasKey(date)) { return false; }
        var rec = _days[date];
        return rec[2] != null || rec[3] != null;
    }

    // Ranne maximum Body Battery pre dany den (vcerajsok po polnoci, kym sa nespalo).
    static function bodyBatteryPeakFor(date) {
        var stored = Application.Storage.getValue("bbPeak");
        if (stored instanceof Lang.Dictionary) {
            var d = stored["d"] as String or Null;
            if (d != null && d.equals(date)) { return stored["v"]; }
        }
        var h = Application.Storage.getValue("bbHist");
        if (h instanceof Lang.Dictionary && h.hasKey(date)) { return h[date]; }
        return null;
    }

    function parseRecords(data as Array) as Void {
        for (var i = 0; i < data.size(); i++) {
            var rec = data[i];
            if (!(rec instanceof Lang.Dictionary)) { continue; }
            var id = rec["id"];
            if (id == null) { continue; }
            _days.put(id.toString(), [
                num(rec, "hrv"),
                num(rec, "restingHR"),
                num(rec, "sleepSecs"),
                num(rec, "sleepScore"),
                num(rec, "ctl"),
                num(rec, "atl")
            ]);
        }
    }

    function finish(status, payload) {
        _busy = false;
        var cb = _callback;
        _callback = null;
        if (cb != null) {
            cb.invoke(status, payload);
        }
    }
}
