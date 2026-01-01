using Toybox.Application;
using Toybox.WatchUi;
using Toybox.ActivityRecording;
using Toybox.Position;

class legendmasterApp extends Application.AppBase {
    var session = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        // Включаем GPS на постоянный поиск
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        
        if (session == null) {
            session = ActivityRecording.createSession({
                :name=>"Orienteering",
                :sport=>ActivityRecording.SPORT_RUNNING
            });
        }
    }

    function onStop(state) {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        if (session != null && session.isRecording()) {
            session.stop();
            session.save();
            session = null;
        }
    }

    // Обработчик для компилятора (важна типизация для SDK 8.x)
    function onPosition(info as Position.Info) as Void {
        WatchUi.requestUpdate(); 
    }

    function getInitialView() {
        var view = new legendmasterView();
        return [ view, new legendmasterDelegate(view) ];
    }
}