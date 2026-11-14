import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// Cas do zotavenia (Garmin recovery time) z hodiniek.
// Cita sa cez Complications API (Connect IQ 4.2+). Priame ActivityMonitor.Info.timeToRecovery
// sa nepouziva - na niektorych hodinkach (Venu 2 Plus) "has" vrati true, ale citanie spadne,
// a na Venu 3 / vivoactive 5 nie je dostupne.
// Hodinky bez Complications (vivoactive 4/4S, Venu 2) maju v monkey.jungle vylucenu
// anotaciu :recovery, takze pre ne sa prelozi verzia, ktora vracia null.
(:glance)
module RecoveryTime {

    const STORE_KEY = "rtMorning";

    // Aktualny cas do zotavenia v hodinach (Float) alebo null.
    (:recovery)
    function current() {
        if (!(Toybox has :Complications)) { return null; }
        try {
            var c = Toybox.Complications.getComplication(
                new Toybox.Complications.Id(Toybox.Complications.COMPLICATION_TYPE_RECOVERY_TIME));
            if (c == null) { return null; }
            var v = c.value;
            // hodnota je v minutach
            if (v instanceof Lang.Number || v instanceof Lang.Float ||
                v instanceof Lang.Long || v instanceof Lang.Double) {
                var h = v.toFloat() / 60.0;
                if (h < 0.0) { return null; }
                return h;
            }
        } catch (e) {
        }
        return null;
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
