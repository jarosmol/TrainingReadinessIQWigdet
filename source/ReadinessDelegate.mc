import Toybox.Lang;
import Toybox.WatchUi;

class ReadinessDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Tlacidlo / klepnutie: prehlad -> zlozky -> historia, pripadne obnovi data.
    function onSelect() {
        _view.nextPage();
        _view.refresh(false);
        return true;
    }

    // DOWN / potiahnutie nahor: dalsia obrazovka (na hodinkach s tlacidlami, napr. Forerunner).
    // V slucke widgetov (vivoactive 4S) tieto gesta riadia hodinky, vtedy sa sem nedostanu.
    function onNextPage() {
        _view.nextPage();
        _view.refresh(false);
        return true;
    }

    // UP / potiahnutie nadol: predchadzajuca obrazovka.
    function onPreviousPage() {
        _view.prevPage();
        _view.refresh(false);
        return true;
    }

    // Menu (dlhe podrzanie): vynutene obnovenie dat.
    function onMenu() {
        _view.refresh(true);
        return true;
    }
}
