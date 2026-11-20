import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;

// Texty su v resources/strings (anglictina, predvolena) a resources-slo/strings
// (slovencina). Hodinky vyberu jazyk podla svojho nastavenia. Slovenske texty su
// bez diakritiky, aby sa zobrazili aj na hodinkach bez slovenskych znakov v pisme.
class ReadinessView extends WatchUi.View {

    const CACHE_KEY = "cache";
    const STALE_SECS = 1800;        // data starsie ako 30 min sa pri otvoreni obnovia
    const STALE_SECS_AM = 600;      // dopoludnia 10 min: Garmin rano posiela predbezny pokojovy tep

    var _fetcher;
    var _result = null;             // posledny vypocet (Dictionary)
    var _fetchedAt = 0;             // Time.now().value() posledneho uspesneho stiahnutia
    var _status = :idle;            // :idle, :loading, :nokey, :error
    var _errorCode = 0;
    var _page = 0;                  // 0 prehlad, 1 zlozky, 2 historia 7 dni, 3 historia 30 dni
    var _t;                         // nacitane texty v jazyku hodiniek
    var _small = null;              // mensie pismo pre spodne popisky (vid smallFont)
    var _rowFont = null;
    var _titleFont = null;          // nadpisy stran (na AMOLED o nieco vacsie)            // pismo riadkov so zlozkami (na AMOLED mierne mensie)

    function initialize() {
        View.initialize();
        _t = {
            "Title" => WatchUi.loadResource(Rez.Strings.Title),
            "AppVersion" => WatchUi.loadResource(Rez.Strings.AppVersion),
            "LblPrime" => WatchUi.loadResource(Rez.Strings.LblPrime),
            "LblHigh" => WatchUi.loadResource(Rez.Strings.LblHigh),
            "LblModerate" => WatchUi.loadResource(Rez.Strings.LblModerate),
            "LblLow" => WatchUi.loadResource(Rez.Strings.LblLow),
            "LblPoor" => WatchUi.loadResource(Rez.Strings.LblPoor),
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
            "RhrShort" => WatchUi.loadResource(Rez.Strings.RhrShort),
            "RhrLong" => WatchUi.loadResource(Rez.Strings.RhrLong),
            "BodyBatLong" => WatchUi.loadResource(Rez.Strings.BodyBatLong),
            "MornShort" => WatchUi.loadResource(Rez.Strings.MornShort),
            "MornLong" => WatchUi.loadResource(Rez.Strings.MornLong),
            "MornMid" => WatchUi.loadResource(Rez.Strings.MornMid),
            "Hrv" => WatchUi.loadResource(Rez.Strings.Hrv),
            "Bb" => WatchUi.loadResource(Rez.Strings.Bb),
            "Factors" => WatchUi.loadResource(Rez.Strings.Factors),
            "BodyBat" => WatchUi.loadResource(Rez.Strings.BodyBat),
            "NotMeasured" => WatchUi.loadResource(Rez.Strings.NotMeasured),
            "Max" => WatchUi.loadResource(Rez.Strings.Max),
            "DetailFooter" => WatchUi.loadResource(Rez.Strings.DetailFooter),
            "Last7" => WatchUi.loadResource(Rez.Strings.Last7),
            "Refresh" => WatchUi.loadResource(Rez.Strings.Refresh),
            "DayOfMonth" => WatchUi.loadResource(Rez.Strings.DayOfMonth),
            "Last30" => WatchUi.loadResource(Rez.Strings.Last30),
            "Stats" => WatchUi.loadResource(Rez.Strings.Stats)
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

    // Prehlad -> zlozky -> 7 dni -> 30 dni -> prehlad
    function nextPage() {
        _page = (_page + 1) % 4;
        WatchUi.requestUpdate();
    }

    function prevPage() {
        _page = (_page + 3) % 4;
        WatchUi.requestUpdate();
    }

    function refresh(force) {
        if (_fetcher.isBusy()) { return; }
        var age = Time.now().value() - _fetchedAt;
        // cache zo starsej verzie widgetu (bez historie) sa obnovi hned
        var h = part("hist") as Array or Null;
        var complete = h != null && h.size() >= 30;
        // do 12:00 sa obnovuje castejsie, aby sa predbezny ranny pokojovy tep rychlo nahradil
        var stale = (Time.now().value() - Time.today().value() < 12 * 3600) ? STALE_SECS_AM : STALE_SECS;
        if (!force && _result != null && complete && age < stale) { return; }
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

    // Pasma a farby ako Garmin Training Readiness (Prime/High/Moderate/Low/Poor).
    // Farby su presne z 64-farebnej palety MIP displejov (zlozky 00/55/AA/FF),
    // takze vyzeraju rovnako na vivoactive 4S, Forerunner 255 aj AMOLED hodinkach.
    static function scoreColor(s) {
        if (s == null) { return Graphics.COLOR_LT_GRAY; }
        if (s >= 95) { return 0xAA55FF; }   // fialova  - Prime
        if (s >= 75) { return 0x00AAFF; }   // modra    - High
        if (s >= 50) { return 0x55FF55; }   // zelena   - Moderate
        if (s >= 25) { return 0xFFAA00; }   // oranzova - Low
        return 0xFF0000;                    // cervena  - Poor
    }

    function scoreLabel(s) {
        if (s == null) { return tx("LblNoData"); }
        if (s >= 95) { return tx("LblPrime"); }
        if (s >= 75) { return tx("LblHigh"); }
        if (s >= 50) { return tx("LblModerate"); }
        if (s >= 25) { return tx("LblLow"); }
        return tx("LblPoor");
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

    // Mensie pismo na spodne popisky. Na AMOLED displejoch s vysokym rozlisenim
    // (Venu 3, Forerunner 265...) je FONT_XTINY velke, preto sa tam pouzije vektorove
    // pismo asi o 25 % mensie. Inde (a na hodinkach bez vektorovych pisiem) FONT_XTINY.
    (:vector)
    function smallFont(dc, w, scale) {
        var base = Graphics.FONT_XTINY;
        if (w < 360 || !(Graphics has :getVectorFont)) { return base; }
        var size = (dc.getFontHeight(base) * scale).toNumber();
        var f = Graphics.getVectorFont({
            :face => ["RobotoCondensedRegular", "RobotoRegular", "RobotoCondensedBold"],
            :size => size
        });
        return f != null ? f : base;
    }

    (:novector)
    function smallFont(dc, w, scale) {
        return Graphics.FONT_XTINY;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        if (_small == null) {
            _small = smallFont(dc, w, 0.75);
            _rowFont = smallFont(dc, w, 0.82);
            _titleFont = smallFont(dc, w, 1.12);
        }
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
        } else if (_page == 3) {
            drawMonth(dc, w, h, cx, cy);
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

        // ranne skore (bez dnesnych treningov), ak je o viac ako 2 body vyssie
        var mor = part("morning");
        var ms = (mor != null) ? r(mor[0]) as Number or Null : null;
        var showMorning = ms != null && score != null && (ms - score > 2 || score - ms > 2);

        // prstenec: siva stopa + farebny obluk podla skore
        dc.setPenWidth(pen);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rad);
        // co dnesny trening "zobral": svetlosivy obluk az po ranne skore, farebny cez neho
        if (showMorning && (ms as Number) > score) {
            var m = ms as Number;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            if (m >= 100) {
                dc.drawCircle(cx, cy, rad);
            } else {
                var mEnd = 90 - (360 * m / 100);
                if (mEnd < 0) { mEnd += 360; }
                dc.drawArc(cx, cy, rad, Graphics.ARC_CLOCKWISE, 90, mEnd);
            }
        }
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
        dc.drawText(cx, cy - inner * 0.66, _titleFont, tx("Title"), vc);
        // cislo verzie drobne nad nadpisom
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - inner * 0.66 - dc.getFontHeight(_titleFont) * 0.85, _small,
            "v" + tx("AppVersion"), vc);

        var scoreText = score == null ? "--" : score.format("%d");
        var numberY = cy - inner * 0.27;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, numberY, Graphics.FONT_NUMBER_MEDIUM, scoreText, vc);

        // Ranne skore (bez dnesnych treningov) za lomitkom, male a blede -
        // iba ak sa od aktualneho lisi o viac ako 2 body (po treningu)
        if (showMorning) {
            var numW = dc.getTextWidthInPixels(scoreText, Graphics.FONT_NUMBER_MEDIUM);
            var digitH = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM) * 0.62;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + numW / 2 + 3, numberY + digitH / 2 - dc.getFontHeight(Graphics.FONT_XTINY) / 2,
                Graphics.FONT_XTINY, "/" + (ms as Number).format("%d"),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

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
        // hodinky bez HRV (alebo HRV dnes chyba): namiesto "HRV --" Body Battery
        if ((bb != null && bb[0] != null) || hrv[1] == null) {
            hrvText = tx("Bb") + " " + ((bb == null || bb[1] == null) ? "--" : r(bb[1]).format("%d"));
        }
        var line2 = hrvText
                  + gap + tx("RhrShort") + " " + (rhr[1] == null ? "--" : r(rhr[1]).format("%d"));

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawSleepLine(dc, cx, cy + inner * 0.40, line1, hhmm(sleep[1]));
        dc.drawText(cx, cy + inner * 0.60, Graphics.FONT_XTINY, line2, vc);

        dc.setColor(_status == :error ? 0xFFAA00 : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + inner * 0.82, _small, footerText(), vc);
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
        var fh = dc.getFontHeight(_rowFont);
        var mor = part("morning");
        var form = _result["form"];

        // Ranna sviezost (pred dnesnym treningom) - samostatny bledy riadok nad zlozkami,
        // za rovnakej podmienky ako ranne skore na prehlade (lisi sa o viac ako 2 body)
        var mornRow = null;
        var sNow = r(_result["score"]);
        if (mor != null && sNow != null && mor.size() > 2 && mor[1] != null && mor[2] != null) {
            var sMorn = r(mor[0]);
            if (sMorn != null && (sMorn - sNow > 2 || sNow - sMorn > 2)) {
                mornRow = [tx("MornShort"), mor[2], signed(mor[1]) + "%", null, tx("MornLong"), true,
                    tx("MornMid")];
            }
        }

        // nadpis na rovnakom mieste a rovnakym pismom ako na strankach s historiou
        var top = cy - h * 0.30;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top, _titleFont, tx("Factors"),
            Graphics.TEXT_JUSTIFY_CENTER | vc);

        var hrv = _result["hrv"];
        var sleep = _result["sleep"];
        var rhr = _result["rhr"];
        var bb = part("bb");

        // Riadok: [kratky popis, skore, hodnota, dni v priemere alebo null, dlhy popis]
        // 4. prvok: ak je v priemere (HRV, tep) malo dni, namiesto skore sa ukaze napr. "3d".
        // HRV a tep: iba dnesna hodnota; skore 85 = vlastny priemer za 4 tyzdne (vysvetlivka v pate).
        var rows = [
            [tx("Form"), form[0], form[1] == null ? "" : signed(form[1]) + "%", null, tx("FormLong")],
            [tx("Hrv"), hrv[0], hrv[1] == null ? tx("NotMeasured") :
                r(hrv[1]).format("%d"),
                hrv[1] == null ? null : baseDays(hrv), tx("Hrv")],
            [tx("Sleep"), sleep[0], hhmm(sleep[1]), null, tx("Sleep")],
            [tx("Rhr"), rhr[0], rhr[1] == null ? "" :
                r(rhr[1]).format("%d"),
                rhr[1] == null ? null : baseDays(rhr), tx("RhrLong")]
        ] as Array<Array>;

        // Body Battery: ak sa pouzilo v skore (HRV chyba alebo este zbiera priemer) alebo HRV
        // hodinky nemeraju. Ak HRV namerana je (nove hodinky, priemer sa este zbiera - "3d"),
        // riadok HRV ostane a Body Battery sa prida pod sviezost; inak nahradi "HRV --".
        if ((bb != null && bb[0] != null) || hrv[1] == null) {
            var hasBb = bb != null && bb[1] != null;
            var bbRow = [tx("BodyBat"), hasBb ? bb[0] : null,
                hasBb ? tx("Max") + " " + r(bb[1]).format("%d") : "--", null,
                tx("BodyBatLong")];
            if (hrv[1] != null) {
                var withBb = [rows[0], bbRow] as Array<Array>;
                for (var q = 1; q < rows.size(); q++) { withBb.add(rows[q]); }
                rows = withBb;
            } else {
                rows[1] = bbRow;
            }
        }

        if (mornRow != null) {
            var all = [mornRow] as Array<Array>;
            all.addAll(rows);
            rows = all;
        }
        // Riadky rozlozene tak, aby pata skoncila symetricky k nadpisu (cy + 0.30 h):
        // pri 4 riadkoch sa nedrzia hore, pri 5-6 sa zhustia. Vzdy 1.05 az 1.5 vysky pisma.
        var rowH = h * 0.60 / (rows.size() + 1.6);
        if (rowH < fh * 1.05) { rowH = fh * 1.05; }
        if (rowH > fh * 1.5) { rowH = fh * 1.5; }

        var xL = cx - w * 0.36;
        var xS = cx + w * 0.02;
        var xV = cx + w * 0.38;
        var halfScoreW = dc.getTextWidthInPixels("100", _rowFont) / 2;

        // Plne nazvy (Freshness, Resting HR, Body Battery), ak sa zmestia pred stlpec
        // so skore, inak skratky
        var room = xS - xL - halfScoreW - 4;
        for (var j = 0; j < rows.size(); j++) {
            if (dc.getTextWidthInPixels(rows[j][4] as String, _rowFont) <= room) {
                rows[j][0] = rows[j][4];
            } else if (rows[j].size() > 6 &&
                    dc.getTextWidthInPixels(rows[j][6] as String, _rowFont) <= room) {
                rows[j][0] = rows[j][6];   // stredne dlhy popis (napr. "Morning F.")
            }
        }
        var y = top;
        for (var i = 0; i < rows.size(); i++) {
            y = top + rowH * (i + 1.2);
            var sc = r(rows[i][1]);
            // ranna sviezost a HRV / tep, ktore sa este zbieraju: cely riadok svetlosivo
            var pale = rows[i].size() > 5;
            var value = rows[i][2] as String;
            var scText = "--";
            if (sc != null) {
                scText = sc.format("%d");
            } else {
                // HRV / tep sa este zbiera: riadok bledo, skore "--" a pri hodnote pocet
                // nameranych dni vratane dneska z potrebnych 7, napr. "52 (2/7)"
                var days = rows[i][3] as Number or Null;
                if (days != null) {
                    pale = true;
                    value = value + " (" + (days + 1).format("%d") + "/7)";
                }
            }
            dc.setColor(pale ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xL, y, _rowFont, rows[i][0], Graphics.TEXT_JUSTIFY_LEFT | vc);
            dc.setColor(pale ? Graphics.COLOR_LT_GRAY : scoreColor(sc), Graphics.COLOR_TRANSPARENT);
            dc.drawText(xS, y, _rowFont, scText,
                Graphics.TEXT_JUSTIFY_CENTER | vc);
            // hodnoty, ktore sa do skore nepocitaju, su bledsie ako zapocitane (LT_GRAY);
            // na AMOLED medzistupen 0x808080, na MIP displejoch tmavosiva z palety
            dc.setColor(pale ? (w >= 360 ? 0x808080 : Graphics.COLOR_DK_GRAY) : Graphics.COLOR_LT_GRAY,
                Graphics.COLOR_TRANSPARENT);
            dc.drawText(xV, y, _rowFont, value, Graphics.TEXT_JUSTIFY_RIGHT | vc);
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + rowH * 1.4, _small, tx("DetailFooter"),
            Graphics.TEXT_JUSTIFY_CENTER | vc);
    }

    // Historia: skore za poslednych 7 dni ako stlpcovy graf (najnovsi vpravo).
    function drawHistory(dc, w, h, cx, cy) {
        var vcC = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var hist = part("hist");
        var labels = part("histDays");

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 0.30, _titleFont, tx("Last7"), vcC);

        if (hist == null || labels == null) {
            dc.drawText(cx, cy, Graphics.FONT_XTINY, tx("Refresh"), vcC);
            return;
        }

        var n = hist.size() < 7 ? hist.size() : 7;
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

            dc.setColor(Graphics.COLOR_WHITE,
                Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, baseY + fh * 0.65, _small, labels[idx], vcC);
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(left, baseY, left + areaW, baseY);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, baseY + fh * 1.75, _small, tx("DayOfMonth"), vcC);
    }

    // Historia 30 dni: tenke stlpce (najnovsi vpravo), datumy kazdy 7. den,
    // pod tym priemer / minimum / maximum rannych skore.
    function drawMonth(dc, w, h, cx, cy) {
        var vcC = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var hist = part("hist");
        var labels = part("histDays");
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 0.30, _titleFont, tx("Last30"), vcC);

        if (hist == null || labels == null || hist.size() < 30) {
            dc.drawText(cx, cy, Graphics.FONT_XTINY, tx("Refresh"), vcC);
            return;
        }

        var n = 30;
        var areaW = w * 0.74;
        var slot = areaW / n;
        var barW = slot * 0.7;
        if (barW < 1) { barW = 1; }
        var baseY = cy + h * 0.12;
        var maxH = h * 0.32;
        var left = cx - areaW / 2;

        var sum = 0.0;
        var cnt = 0;
        var mn = null;
        var mx = null;
        for (var k = 0; k < n; k++) {
            var i = n - 1 - k;                // vlavo najstarsi den
            var sc = r(hist[i]);
            var x = left + slot * k + slot / 2;
            if (sc != null) {
                var bh = maxH * sc / 100.0;
                if (bh < 2) { bh = 2; }
                dc.setColor(scoreColor(sc), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x - barW / 2, baseY - bh, barW, bh);
                sum += sc;
                cnt++;
                if (mn == null || sc < mn) { mn = sc; }
                if (mx == null || sc > mx) { mx = sc; }
            }
            if (i % 7 == 0) {
                dc.setColor(Graphics.COLOR_WHITE,
                    Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, baseY + fh * 0.65, _small, labels[i], vcC);
            }
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(left, baseY, left + areaW, baseY);

        if (cnt > 0) {
            var avg = (sum / cnt + 0.5).toNumber();
            // rovnaka farba ako ostatne spodne popisky
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, baseY + fh * 1.75, _small,
                Lang.format(tx("Stats"), [avg.format("%d"), (mn as Number).format("%d"),
                    (mx as Number).format("%d")]), vcC);
        }
    }
}
