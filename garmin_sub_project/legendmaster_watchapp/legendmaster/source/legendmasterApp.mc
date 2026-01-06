using Toybox.Application;
using Toybox.Position;
using Toybox.ActivityRecording;
using Toybox.WatchUi;
using Toybox.Communications;
using Toybox.Application.Storage;

class legendmasterApp extends Application.AppBase {
    var session = null;

    function initialize() { 
        AppBase.initialize(); 
    }

    // Обработчик сообщений от телефона (Android/iOS)
// Указываем компилятору точные типы для соответствия API
function onPhoneAppMessage(msg as Communications.PhoneAppMessage) as Void {
        if (msg.data != null) {
            var app = Application.getApp();
            // Используем старый надежный метод setProperty для Fenix 3
            // Он работает и на новых, и на старых часах одинаково
            app.setProperty("cp_data", msg.data);
            WatchUi.requestUpdate();
        }
    }

    function onStart(state) {
        // Как в Hike2: включаем GPS в непрерывном режиме
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        
        // Регистрируем обработчик входящих сообщений от телефона
        Communications.registerForPhoneAppMessages(method(:onPhoneAppMessage));
    }

function onPosition(info as Position.Info) as Void {
        WatchUi.requestUpdate();
    }

    function onStop(state) {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        if (session != null && session.isRecording()) { 
            session.stop(); 
        }
    }

    function getInitialView() {
        var view = new legendmasterView();
        return [ view, new legendmasterDelegate(view) ];
    }
}