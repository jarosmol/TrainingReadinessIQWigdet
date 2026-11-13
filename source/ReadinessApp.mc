import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ReadinessApp extends Application.AppBase {

    var _view = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        _view = new ReadinessView();
        return [_view, new ReadinessDelegate(_view)];
    }

    // Po zmene nastaveni (napr. API kluca) nacitaj data znova.
    function onSettingsChanged() {
        if (_view != null) {
            _view.refresh(true);
        }
        WatchUi.requestUpdate();
    }
}
