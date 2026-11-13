import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Texty su v resources/strings (anglictina, predvolena) a resources-slo/strings
// (slovencina). Hodinky vyberu jazyk podla svojho nastavenia. Slovenske texty su
// bez diakritiky, aby sa zobrazili aj na hodinkach bez slovenskych znakov v pisme.
class ReadinessView extends WatchUi.View {

    const CACHE_KEY = "cache";
    const STALE_SECS = 1800;        // data starsie ako 30 min sa pri otvoreni obnovia

    var _fetcher;
    var _result = null;             // posledny vypocet (Dictionary)
    var _fetchedAt = 0;             // Time.now().value() posledneho uspesneho stiahnutia
    var _status = :idle;            // :idle, :loading, :nokey, :error
    var _errorCode = 0;
    var _page = 0;                  // 0 prehlad, 1 zlozky, 2 historia
    var _t;                         // nacitane texty v jazyku hodiniek

    function initialize() {
        View.initialize();
        _t = {
            "Title" => WatchUi.loadResource(Rez.Strings.Title),
            "LblExcellent" => WatchUi.loadResource(Rez.Strings.LblExcellent),
            "LblGood" => WatchUi.loadResource(Rez.Strings.LblGood),
            "LblFair" => WatchUi.loadResource(Rez.Strings.LblFair),
            "LblLow" => WatchUi.loadResource(Rez.Strings.LblLow),
            "LblVeryLow" => WatchUi.loadResource(Rez.Strings.LblVeryLow),
            "LblNoData" => WatchUi.loadResource(Rez.Strings.LblNoData),
            "ErrKey" => WatchUi.loadResource(Rez.Strings.ErrKey),
            "ErrId" => WatchUi.loadResource(Rez.Strings.ErrId),
            "ErrPhone" => WatchUi.loadResource(Rez.Strings.ErrPhone),
            "ErrTimeout" => WatchUi.loadResource(Rez.Strings.ErrTimeout),
            "ErrTooBig" => WatchUi.loadResource(Rez.Strings.ErrTooBig),
            "ErrInvalid" => WatchUi.loadResource(Rez.Strings.ErrInvalid),
            "ErrCode" => WatchUi.loadResource(Rez.Strings.ErrCode),
            "AgeNow" => WatchUi.loadResource(Rez.Strings.AgeNow),
            "AgeMin" => WatchUi.loadResource(Rez.Strings.AgeMin),
            "AgeHour" => WatchUi.loadResource(Rez.Strings.AgeHour),
            "AgeDay" => WatchUi.loadResource(Rez.Strings.AgeDay),
            "Loading" => WatchUi.loadResource(Rez.Strings.Loading),
            "NoKey1" => WatchUi.loadResource(Rez.Strings.NoKey1),
            "NoKey2" => WatchUi.loadResource(Rez.Strings.NoKey2),
            "NoKey3" => WatchUi.loadResource(Rez.Strings.NoKey3),
            "Retry1" => WatchUi.loadResource(Rez.Strings.Retry1),
            "Retry2" => WatchUi.loadResource(Rez.Strings.Retry2),
            "Load1" => WatchUi.loadResource(Rez.Strings.Load1),
            "Load2" => WatchUi.loadResource(Rez.Strings.Load2),
            "Load3" => WatchUi.loadResource(Rez.Strings.Load3),
            "Form" => WatchUi.loadResource(Rez.Strings.Form),
            "FormLong" => WatchUi.loadResource(Rez.Strings.FormLong),
            "Sleep" => WatchUi.loadResource(Rez.Strings.Sleep),
            "SleepShort" => WatchUi.loadResource(Rez.Strings.SleepShort),
            "Rhr" => WatchUi.loadResource(Rez.Strings.Rhr),
            "Hrv" => WatchUi.loadResource(Rez.Strings.Hrv),
            "Bb" => WatchUi.loadResource(Rez.Strings.Bb),
            "Factors" => WatchUi.loadResource(Rez.Strings.Factors),
            "BodyBat" => WatchUi.loadResource(Rez.Strings.BodyBat),
            "NotMeasured" => WatchUi.loadResource(Rez.Strings.NotMeasured),
            "Max" => WatchUi.loadResource(Rez.Strings.Max),
            "DetailFooter" => WatchUi.loadResource(Rez.Strings.DetailFooter),
            "Last7" => WatchUi.loadResource(Rez.Strings.Last7),
            "Refresh" => WatchUi.loadResource(Rez.Strings.Refresh),
            "DayOfMonth" => WatchUi.loadResource(Rez.Strings.DayOfMonth)
        };
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

    // Prehlad -> zlozky -> historia -> prehlad
    function nextPage() {
        _page = (_page + 1) % 3;
        WatchUi.requestUpdate();
    }

    function refresh(force) {
        if (_fetcher.isBusy()) { return; }
        var age = Time.now().value() - _fetchedAt;
        // cache zo starsej verzie widgetu (bez historie) sa obnovi hned
        var complete = part("hist") != null;
        if (!force && _result != null && complete && age < STALE_SECS) { return; }
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

    // Text v jazyku hodiniek
    function tx(key) {
        return _t[key];
    }

    static function scoreColor(s) {
        if (s == null) { return Graphics.COLOR_LT_GRAY; }
        if (s >= 80) { return 0x00C853; }   // zelena
        if (s >= 60) { return 0x9CCC65; }   // svetlo zelena
        if (s >= 40) { return 0xFFC400; }   // zlta
        if (s >= 25) { return 0xFF8A00; }   // oranzova
        return 0xFF3D00;                    // cervena
    }

    function scoreLabel(s) {
        if (s == null) { return tx("LblNoData"); }
        if (s >= 80) { return tx("LblExcellent"); }
        if (s >= 60) { return tx("LblGood"); }
        if (s >= 40) { return tx("LblFair"); }
        if (s >= 25) { return tx("LblLow"); }
        return tx("LblVeryLow");
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

    // Zlozka z vysledku, ak existuje (starsia cache nove kluce nema).
    function part(key) {
        if (_result instanceof Lang.Dictionary && _result.hasKey(key)) {
            return _result[key];
        }
        return null;
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
        if (c == 401 || c == 403) { return tx("ErrKey"); }
        if (c == 404) { return tx("ErrId"); }
        if (c == -104 || c == -2) { return tx("ErrPhone"); }
        if (c == -300) { return tx("ErrTimeout"); }
        if (c == -402 || c == -403) { return tx("ErrTooBig"); }
        if (c == -400) { return tx("ErrInvalid"); }
        return Lang.format(tx("ErrCode"), [c.format("%d")]);
    }

    function ageText() {
        if (_fetchedAt == 0) { return ""; }
        var mins = (Time.now().value() - _fetchedAt) / 60;
        if (mins < 1) { return tx("AgeNow"); }
        if (mins < 60) { return Lang.format(tx("AgeMin"), [mins.format("%d")]); }
        var hrs = mins / 60;
        if (hrs < 24) { return Lang.format(tx("AgeHour"), [hrs.format("%d")]); }
        return Lang.format(tx("AgeDay"), [(hrs / 24).format("%d")]);
    }

    function footerText() {
        if (_status == :loading) { return tx("Loading"); }
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
            drawMessage(dc, cx, cy, tx("NoKey1"), tx("NoKey2"), tx("NoKey3"));
            return;
        }
        if (_result == null) {
            if (_status == :error) {
                drawMessage(dc, cx, cy, errorText(), tx("Retry1"), tx("Retry2"));
            } else {
                drawMessage(dc, cx, cy, tx("Load1"), tx("Load2"), tx("Load3"));
            }
            return;
        }

        if (_page == 1) {
            drawDetail(dc, w, h, cx, cy);
        } else if (_page == 2) {
            drawHistory(dc, w, h, cx, cy);
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
        dc.drawText(cx, cy - inner * 0.66, Graphics.FONT_XTINY, tx("Title"), vc);

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
        // spanok je oznaceny ikonou mesiaca (kratsie nez slovo, rovnake v kazdom jazyku)
        var line1 = tx("Form") + " " + (form[1] == null ? "--" : signed(form[1]) + "%") + gap;
        // Body Battery sa zobrazi namiesto HRV, ak sa pouzilo v skore
        var bb = part("bb");
        var hrvText = tx("Hrv") + " " + (hrv[1] == null ? "--" : r(hrv[1]).format("%d"));
        if (bb != null && bb[0] != null) {
            hrvText = tx("Bb") + " " + r(bb[1]).format("%d");
        }
        var line2 = hrvText
                  + gap + tx("Rhr") + " " + (rhr[1] == null ? "--" : r(rhr[1]).format("%d"));

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawSleepLine(dc, cx, cy + inner * 0.40, line1, hhmm(sleep[1]));
        dc.drawText(cx, cy + inner * 0.60, Graphics.FONT_XTINY, line2, vc);

        dc.setColor(_status == :error ? 0xFF8A00 : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + inner * 0.82, Graphics.FONT_XTINY, footerText(), vc);
    }

    // Riadok "<prefix> [mesiac] <cas spanku>" vycentrovany na cx.
    function drawSleepLine(dc, cx, y, prefix, value) {
        var font = Graphics.FONT_XTINY;
        var fh = dc.getFontHeight(font);
        var r = fh * 0.30;
        if (r < 3) { r = 3; }
        var sp = dc.getTextWidthInPixels(" ", font);
        var w1 = dc.getTextWidthInPixels(prefix, font);
        var w2 = dc.getTextWidthInPixels(value, font);
        var x = cx - (w1 + r * 2 + sp + w2) / 2;
        var vl = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, prefix, vl);

        // mesiac: biely kruh, z ktoreho cierny kruh vyreze kosacik
        var mx = x + w1 + r;
        dc.fillCircle(mx, y, r);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx + r * 0.55, y - r * 0.35, r * 0.85);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mx + r + sp, y, font, value, vl);
    }

    // Detail: skore kazdej zlozky (0-100) a jej hodnota.
    function drawDetail(dc, w, h, cx, cy) {
        var vc = Graphics.TEXT_JUSTIFY_VCENTER;
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var rowH = fh * 1.45;
        var top = cy - rowH * 2.2;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top, Graphics.FONT_XTINY, tx("Factors"),
            Graphics.TEXT_JUSTIFY_CENTER | vc);

        var form = _result["form"];
        var hrv = _result["hrv"];
        var sleep = _result["sleep"];
        var rhr = _result["rhr"];
        var bb = part("bb");

        // 4. stlpec: pocet dni v priemere (HRV, tep) - ak ich je malo, namiesto
        // skore sa zobrazi napr. "3d" (zbiera sa baseline)
        var rows = [
            [tx("Form"), form[0], form[1] == null ? "" : signed(form[1]) + "%", null],
            [tx("Hrv"), hrv[0], hrv[1] == null ? tx("NotMeasured") :
                r(hrv[1]).format("%d") + (hrv[2] == null ? "" : "/" + r(hrv[2]).format("%d")),
                hrv[1] == null ? null : baseDays(hrv)],
            [tx("Sleep"), sleep[0], hhmm(sleep[1]), null],
            [tx("Rhr"), rhr[0], rhr[1] == null ? "" :
                r(rhr[1]).format("%d") + (rhr[2] == null ? "" : "/" + r(rhr[2]).format("%d")),
                rhr[1] == null ? null : baseDays(rhr)]
        ];

        // Ak sa v skore pouzilo Body Battery (namiesto HRV), ukaz ho v riadku HRV
        if (bb != null && bb[0] != null) {
            rows[1] = [tx("BodyBat"), bb[0], tx("Max") + " " + r(bb[1]).format("%d"), null];
        }

        var xL = cx - w * 0.36;
        var xS = cx + w * 0.02;
        var xV = cx + w * 0.36;

        // Plny nazov (Freshness), ak sa zmesti pred stlpec so skore, inak skratka (Fresh)
        var longLabel = tx("FormLong");
        var room = xS - xL - dc.getTextWidthInPixels("100", Graphics.FONT_XTINY) / 2 - 4;
        if (dc.getTextWidthInPixels(longLabel, Graphics.FONT_XTINY) <= room) {
            rows[0][0] = longLabel;
        }
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
        dc.drawText(cx, top + rowH * 5.6, Graphics.FONT_XTINY, tx("DetailFooter"),
            Graphics.TEXT_JUSTIFY_CENTER | vc);
    }

    // Historia: skore za poslednych 7 dni ako stlpcovy graf (najnovsi vpravo).
    function drawHistory(dc, w, h, cx, cy) {
        var vcC = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var hist = part("hist");
        var labels = part("histDays");

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 0.30, Graphics.FONT_XTINY, tx("Last7"), vcC);

        if (hist == null || labels == null) {
            dc.drawText(cx, cy, Graphics.FONT_XTINY, tx("Refresh"), vcC);
            return;
        }

        var n = hist.size();
        var areaW = w * 0.70;
        var slot = areaW / n;
        var barW = slot * 0.62;
        var baseY = cy + h * 0.17;
        var maxH = h * 0.32;
        var left = cx - areaW / 2;
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);

        for (var k = 0; k < n; k++) {
            var idx = n - 1 - k;              // vlavo najstarsi den
            var sc = r(hist[idx]);
            var x = left + slot * k + slot / 2;

            if (sc != null) {
                var bh = maxH * sc / 100.0;
                if (bh < 2) { bh = 2; }
                dc.setColor(scoreColor(sc), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x - barW / 2, baseY - bh, barW, bh);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, baseY - bh - fh * 0.55, Graphics.FONT_XTINY, sc.format("%d"), vcC);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, baseY - fh * 0.55, Graphics.FONT_XTINY, "-", vcC);
            }

            dc.setColor(idx == 0 ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
                Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, baseY + fh * 0.65, Graphics.FONT_XTINY, labels[idx], vcC);
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(left, baseY, left + areaW, baseY);
        dc.drawText(cx, baseY + fh * 1.75, Graphics.FONT_XTINY, tx("DayOfMonth"), vcC);
    }
}
