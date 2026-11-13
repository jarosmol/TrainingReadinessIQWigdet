import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.StringUtil;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Stiahne wellness data z intervals.icu po tyzdnovych castiach (4 x 7 dni),
// aby odpovede zostali male aj pre hodinky s malou pamatou (Vivoactive 4S).
class DataFetcher {

    const CHUNKS = 4;
    const CHUNK_DAYS = 7;

    var _callback = null;   // Method(status as Symbol, payload)
    var _chunk = 0;
    var _days = null;
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
        if (body instanceof Lang.Array) {
            data = null;
            parseRecords(body);
        }
        body = null;

        _chunk++;
        if (_chunk < CHUNKS) {
            requestChunk();
            return;
        }
        var result = ReadinessCalc.compute(_days, dateStr(0), dateStr(1));
        _days = null;
        finish(:ok, result);
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
