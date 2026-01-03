using Toybox.Application;
using Toybox.Position;
using Toybox.ActivityRecording;
using Toybox.WatchUi;

class legendmasterApp extends Application.AppBase {
    var session = null;

    function initialize() { AppBase.initialize(); }

    function onStart(state) {
        // Как в Hike2: включаем GPS в непрерывном режиме
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function onPosition(info as Position.Info) as Void {
        WatchUi.requestUpdate();
    }

    function onStop(state) {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        if (session != null && session.isRecording()) { session.stop(); }
    }

    function getInitialView() {
        var view = new legendmasterView();
        return [ view, new legendmasterDelegate(view) ];
    }
}