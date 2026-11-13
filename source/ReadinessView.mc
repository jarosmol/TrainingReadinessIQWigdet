import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Texty su bez diakritiky, aby sa zobrazili spravne aj na hodinkach,
// ktorych systemove pisma nemaju slovenske znaky.
class ReadinessView extends WatchUi.View {

    const CACHE_KEY = "cache";
    const STALE_SECS = 1800;        // data starsie ako 30 min sa pri otvoreni obnovia

    var _fetcher;
    var _result = null;             // posledny vypocet (Dictionary)
    var _fetchedAt = 0;             // Time.now().value() posledneho uspesneho stiahnutia
    var _status = :idle;            // :idle, :loading, :nokey, :error
    var _errorCode = 0;
    var _detail = false;

    function initialize() {
        View.initialize();
        _fetcher = new DataFetcher();
        var cached = Application.Storage.getValue(CACHE_KEY);
        if (cached instanceof Lang.Dictionary && cached["t"] != null) {
            _result = cached["res"];
            _fetchedAt = cached["t"];
        }
    }

    function onShow() {
        refresh(false);
    }

    function toggleDetail() {
        _detail = !_detail;
        WatchUi.requestUpdate();
    }

    function refresh(force) {
        if (_fetcher.isBusy()) { return; }
        var age = Time.now().value() - _fetchedAt;
        if (!force && _result != null && age < STALE_SECS) { return; }
        _status = :loading;
        WatchUi.requestUpdate();
        _fetcher.start(method(:onData));
    }

    function onData(status, payload) {
        if (status == :ok) {
            _result = payload;
            _fetchedAt = Time.now().value();
            _status = :idle;
            Application.Storage.setValue(CACHE_KEY, { "res" => _result, "t" => _fetchedAt });
        } else if (status == :nokey) {
            _status = :nokey;
        } else {
            _status = :error;
            _errorCode = payload;
        }
        WatchUi.requestUpdate();
    }

    // ---------- pomocne funkcie ----------

    static function scoreColor(s) {
        if (s == null) { return Graphics.COLOR_LT_GRAY; }
        if (s >= 80) { return 0x00C853; }   // zelena
        if (s >= 60) { return 0x9CCC65; }   // svetlo zelena
        if (s >= 40) { return 0xFFC400; }   // zlta
        if (s >= 25) { return 0xFF8A00; }   // oranzova
        return 0xFF3D00;                    // cervena
    }

    static function scoreLabel(s) {
        if (s == null) { return "Malo dat"; }
        if (s >= 80) { return "Vyborna"; }
        if (s >= 60) { return "Dobra"; }
        if (s >= 40) { return "Priemerna"; }
        if (s >= 25) { return "Nizka"; }
        return "Velmi nizka";
    }

    static function r(x) {
        if (x == null) { return null; }
        return (x + 0.5).toNumber();
    }

    static function hhmm(secs) {
        if (secs == null) { return "--"; }
        var m = (secs / 60.0 + 0.5).toNumber();
        return (m / 60).format("%d") + ":" + (m % 60).format("%02d");
    }

    // Pocet dni v baseline (4. prvok zlozky), ak je ulozeny; starsia cache ho nema.
    static function baseDays(part) {
        if (part.size() > 3) { return part[3]; }
        return null;
    }

    static function signed(x) {
        var n = r(x);
        return (n > 0 ? "+" : "") + n.format("%d");
    }

    function errorText() {
        var c = _errorCode;
        if (c == 401 || c == 403) { return "Zly API kluc / ID"; }
        if (c == 404) { return "Nespravne ID atleta"; }
        if (c == -104 || c == -2) { return "Telefon nepripojeny"; }
        if (c == -300) { return "Vyprsal cas spojenia"; }
        if (c == -402 || c == -403) { return "Odpoved prilis velka"; }
        if (c == -400) { return "Neplatna odpoved"; }
        return "Chyba " + c.format("%d");
    }

    function ageText() {
        if (_fetchedAt == 0) { return ""; }
        var mins = (Time.now().value() - _fetchedAt) / 60;
        if (mins < 1) { return "prave teraz"; }
        if (mins < 60) { return "pred " + mins.format("%d") + " min"; }
        var hrs = mins / 60;
        if (hrs < 24) { return "pred " + hrs.format("%d") + " h"; }
        return "pred " + (hrs / 24).format("%d") + " d";
    }

    function footerText() {
        if (_status == :loading) { return "Nacitavam..."; }
        if (_status == :error) { return errorText(); }
        return ageText();
    }

    // ---------- kreslenie ----------

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        if (_status == :nokey) {
            drawMessage(dc, cx, cy, "Chyba API kluc", "Vlozte ho do", "properties.xml");
            return;
        }
        if (_result == null) {
            if (_status == :error) {
                drawMessage(dc, cx, cy, errorText(), "Stlacte pre", "opakovanie");
            } else {
                drawMessage(dc, cx, cy, "Pripravenost", "Nacitavam", "data...");
            }
            return;
        }

        if (_detail) {
            drawDetail(dc, w, h, cx, cy);
        } else {
            drawMain(dc, w, h, cx, cy);
        }
    }

    function drawMessage(dc, cx, cy, l1, l2, l3) {
        var fh = dc.getFontHeight(Graphics.FONT_SMALL);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - fh, Graphics.FONT_SMALL, l1, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + fh * 0.2, Graphics.FONT_XTINY, l2, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, cy + fh * 0.9, Graphics.FONT_XTINY, l3, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawMain(dc, w, h, cx, cy) {
        var score = r(_result["score"]);
        var color = scoreColor(score);
        var pen = w / 22;
        if (pen < 6) { pen = 6; }
        var rad = w / 2 - pen / 2 - 3;

        // prstenec: siva stopa + farebny obluk podla skore
        dc.setPenWidth(pen);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rad);
        if (score != null && score > 0) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            if (score >= 100) {
                dc.drawCircle(cx, cy, rad);
            } else {
                var end = 90 - (360 * score / 100);
                if (end < 0) { end += 360; }
                dc.drawArc(cx, cy, rad, Graphics.ARC_CLOCKWISE, 90, end);
            }
        }
        dc.setPenWidth(1);

        var inner = rad - pen;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - inner * 0.66, Graphics.FONT_XTINY, "PRIPRAVENOST", vc);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - inner * 0.27, Graphics.FONT_NUMBER_MEDIUM,
            score == null ? "--" : score.format("%d"), vc);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + inner * 0.12, Graphics.FONT_TINY, scoreLabel(score), vc);

        // dva riadky so zlozkami
        var form = _result["form"];
        var sleep = _result["sleep"];
        var hrv = _result["hrv"];
        var rhr = _result["rhr"];

        // na mensich displejoch (Vivoactive 4S 218 px, Forerunner 255 260 px)
        // kratsie popisky a medzery
        var small = w < 300;
        var gap = small ? "  " : "   ";
        var line1 = "Forma " + (form[1] == null ? "--" : signed(form[1]) + "%")
                  + gap + (small ? "Sp " : "Spanok ") + hhmm(sleep[1]);
        var line2 = (hrv[1] == null ? "HRV --" : "HRV " + r(hrv[1]).format("%d"))
                  + gap + "Tep " + (rhr[1] == null ? "--" : r(rhr[1]).format("%d"));

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + inner * 0.40, Graphics.FONT_XTINY, line1, vc);
        dc.drawText(cx, cy + inner * 0.60, Graphics.FONT_XTINY, line2, vc);

        dc.setColor(_status == :error ? 0xFF8A00 : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + inner * 0.82, Graphics.FONT_XTINY, footerText(), vc);
    }

    // Detail: skore kazdej zlozky (0-100) a jej hodnota.
    function drawDetail(dc, w, h, cx, cy) {
        var vc = Graphics.TEXT_JUSTIFY_VCENTER;
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var rowH = fh * 1.45;
        var top = cy - rowH * 2.2;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top, Graphics.FONT_XTINY, "ZLOZKY SKORE",
            Graphics.TEXT_JUSTIFY_CENTER | vc);

        var form = _result["form"];
        var hrv = _result["hrv"];
        var sleep = _result["sleep"];
        var rhr = _result["rhr"];

        // 4. stlpec: pocet dni v priemere (HRV, tep) - ak ich je malo, namiesto
        // skore sa zobrazi napr. "3d" (zbiera sa baseline)
        var rows = [
            ["Forma", form[0], form[1] == null ? "" : signed(form[1]) + "%", null],
            ["HRV", hrv[0], hrv[1] == null ? "nemeria" :
                r(hrv[1]).format("%d") + (hrv[2] == null ? "" : "/" + r(hrv[2]).format("%d")),
                hrv[1] == null ? null : baseDays(hrv)],
            ["Spanok", sleep[0], hhmm(sleep[1]), null],
            ["Tep", rhr[0], rhr[1] == null ? "" :
                r(rhr[1]).format("%d") + (rhr[2] == null ? "" : "/" + r(rhr[2]).format("%d")),
                rhr[1] == null ? null : baseDays(rhr)]
        ];

        var xL = cx - w * 0.36;
        var xS = cx + w * 0.02;
        var xV = cx + w * 0.36;
        for (var i = 0; i < rows.size(); i++) {
            var y = top + rowH * (i + 1.2);
            var sc = r(rows[i][1]);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xL, y, Graphics.FONT_XTINY, rows[i][0], Graphics.TEXT_JUSTIFY_LEFT | vc);
            var scText = "--";
            if (sc != null) {
                scText = sc.format("%d");
            } else {
                var days = rows[i][3] as Number or Null;
                if (days != null) {
                    scText = days.format("%d") + "d";
                }
            }
            dc.setColor(scoreColor(sc), Graphics.COLOR_TRANSPARENT);
            dc.drawText(xS, y, Graphics.FONT_XTINY, scText,
                Graphics.TEXT_JUSTIFY_CENTER | vc);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xV, y, Graphics.FONT_XTINY, rows[i][2], Graphics.TEXT_JUSTIFY_RIGHT | vc);
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top + rowH * 5.6, Graphics.FONT_XTINY, "skore  |  dnes / priemer",
            Graphics.TEXT_JUSTIFY_CENTER | vc);
    }
}
