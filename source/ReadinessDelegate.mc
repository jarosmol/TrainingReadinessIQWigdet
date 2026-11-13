import Toybox.Lang;
import Toybox.WatchUi;

class ReadinessDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Tlacidlo / klepnutie: prepne prehlad <-> detail zloziek a pripadne obnovi data.
    function onSelect() {
        _view.toggleDetail();
        _view.refresh(false);
        return true;
    }

    // Menu (dlhe podrzanie): vynutene obnovenie dat.
    function onMenu() {
        _view.refresh(true);
        return true;
    }
}
