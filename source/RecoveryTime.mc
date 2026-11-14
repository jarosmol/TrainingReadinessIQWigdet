import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// Cas do zotavenia (Garmin recovery time) z hodiniek.
// Cita sa z ActivityMonitor.Info.timeToRecovery (hodiny, Connect IQ 3.3+). Complications API
// by vyzadovalo opravnenie, ktore widget nemoze mat. Hodinky, ktore hodnotu neposkytuju
// (Venu 3, vivoactive 5), vratia null a zlozka sa vynecha.
// Venu 2 hlasi "has :timeToRecovery", ale citanie spadne - preto ma Venu 2 (a vivoactive 4/4S)
// v monkey.jungle vylucenu anotaciu :recovery a prelozi sa verzia, ktora vracia null.
(:glance)
module RecoveryTime {

    const STORE_KEY = "rtMorning";

    // Aktualny cas do zotavenia v hodinach (Float) alebo null.
    (:recovery)
    function current() {
        var info = ActivityMonitor.getInfo();
        if (info == null || !(info has :timeToRecovery)) { return null; }
        var v = info.timeToRecovery;
        if (v == null) { return null; }
        var h = v.toFloat();
        if (h < 0.0) { return null; }
        return h;
    }

    (:norecovery)
    function current() {
        return null;
    }

    // Cas do zotavenia "bez dnesneho treningu" pre ranne skore.
    // Prva hodnota dna (widget alebo glance) sa ulozi aj s casom a dalej sa odpocitava
    // rovnako ako na hodinkach (1 h za hodinu). Ak trening cas zvysi, aktualna hodnota
    // je vyssia nez odpocitana - ranne skore pouzije odpocitanu. Ak je aktualna nizsia
    // (hodinky upravili cas napr. po spanku), ulozi sa ona.
    function morning(cur) {
        var today = Time.today().value();
        var now = Time.now().value();
        var st = Application.Storage.getValue(STORE_KEY);
        if (st instanceof Lang.Dictionary) {
            var d = st["d"];
            var v = st["v"];
            var t = st["t"];
            if (d instanceof Lang.Number && d == today && v instanceof Lang.Float &&
                t instanceof Lang.Number) {
                var proj = v - (now - t) / 3600.0;
                if (proj < 0.0) { proj = 0.0; }
                if (cur == null || cur >= proj) { return proj; }
            }
        }
        if (cur == null) { return null; }
        try {
            Application.Storage.setValue(STORE_KEY, { "d" => today, "v" => cur, "t" => now });
        } catch (e) {
            // niektore hodinky nedovolia zapis do Storage z glance
        }
        return cur;
    }
}
