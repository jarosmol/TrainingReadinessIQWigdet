import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Glance (riadok v zozname widgetov na hodinkach s glances, napr. Forerunner 255).
// Nema vlastne stahovanie dat - ukazuje posledne skore, ktore ulozil widget
// (Application.Storage "cache"). Hodinky bez glances (vivoactive 4S) ho nepouziju.
(:glance)
class ReadinessGlance extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    // Rovnake pasma a farby ako ReadinessView.scoreColor (paleta MIP displejov)
    static function colorFor(s) {
        if (s >= 95) { return 0xAA55FF; }
        if (s >= 75) { return 0x00AAFF; }
        if (s >= 50) { return 0x55FF55; }
        if (s >= 25) { return 0xFFAA00; }
        return 0xFF0000;
    }

    static function labelFor(s) {
        if (s >= 95) { return WatchUi.loadResource(Rez.Strings.LblPrime); }
        if (s >= 75) { return WatchUi.loadResource(Rez.Strings.LblHigh); }
        if (s >= 50) { return WatchUi.loadResource(Rez.Strings.LblModerate); }
        if (s >= 25) { return WatchUi.loadResource(Rez.Strings.LblLow); }
        return WatchUi.loadResource(Rez.Strings.LblPoor);
    }

    function onUpdate(dc) {
        // Zapamataj ranny cas do zotavenia (prvy pohlad na glance rano, este pred treningom).
        RecoveryTime.morning(RecoveryTime.current());

        var score = null;
        var morning = null;
        var cached = Application.Storage.getValue("cache");
        if (cached instanceof Lang.Dictionary) {
            var res = cached["res"];
            if (res instanceof Lang.Dictionary) {
                var sv = res["score"];
                if (sv instanceof Lang.Float) {
                    score = (sv + 0.5).toNumber();
                }
                var m = res["morning"];
                if (m instanceof Lang.Array && m.size() > 0) {
                    var m0 = m[0];
                    if (m0 instanceof Lang.Float) {
                        morning = (m0 + 0.5).toNumber();
                    }
                }
            }
        }

        var h = dc.getHeight();
        var vl = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var lineY = h * 0.68;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 0.28, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.Title), vl);

        if (score == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, lineY, Graphics.FONT_XTINY,
                WatchUi.loadResource(Rez.Strings.LblNoData), vl);
            return;
        }

        // "66 /87 Moderate": skore vo farbe pasma, ranne skore (ak sa lisi) bledo, popis
        var color = colorFor(score);
        var text = score.format("%d");
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, lineY, Graphics.FONT_SMALL, text, vl);
        var x = dc.getTextWidthInPixels(text, Graphics.FONT_SMALL) + 4;

        if (morning != null && (morning - score > 2 || score - morning > 2)) {
            var mText = "/" + morning.format("%d");
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, lineY, Graphics.FONT_XTINY, mText, vl);
            x += dc.getTextWidthInPixels(mText, Graphics.FONT_XTINY) + 6;
        } else {
            x += 4;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, lineY, Graphics.FONT_XTINY, labelFor(score), vl);
    }
}
