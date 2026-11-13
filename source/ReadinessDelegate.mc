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

    // Menu (dlhe podrzanie): vynutene obnovenie dat.
    function onMenu() {
        _view.refresh(true);
        return true;
    }
}
