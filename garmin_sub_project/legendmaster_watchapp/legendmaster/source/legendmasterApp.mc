using Toybox.Application;
using Toybox.WatchUi;
using Toybox.ActivityRecording;

class legendmasterApp extends Application.AppBase {
    var session = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        // Создаем сессию сразу при старте
        if (session == null) {
            session = ActivityRecording.createSession({
                :name=>"Orienteering",
                :sport=>ActivityRecording.SPORT_RUNNING
            });
        }
    }

    function onStop(state) {
        // Если приложение закрыто без сохранения — сохраняем принудительно
        if (session != null && session.isRecording()) {
            session.stop();
            session.save();
            session = null;
        }
    }

    function getInitialView() {
        var view = new legendmasterView();
        return [ view, new legendmasterDelegate(view) ];
    }
}