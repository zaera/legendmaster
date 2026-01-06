using Toybox.Application;
using Toybox.Position;
using Toybox.ActivityRecording;
using Toybox.WatchUi;
using Toybox.Communications;

class legendmasterApp extends Application.AppBase {
    var session = null;
    var mView = null; // Храним активную вьюху здесь

    function initialize() { 
        AppBase.initialize(); 
    }

    // Обработчик сообщений от телефона
    function onPhoneAppMessage(msg as Communications.PhoneAppMessage) as Void {
        if (msg.data != null) {
            // 1. Сохраняем данные в постоянную память (setProperty)
            // Это позволит данным выжить после закрытия приложения
            Application.getApp().setProperty("cp_data", msg.data);
            
            // 2. Передаем данные напрямую в активную вьюху для мгновенного обновления
            // Проверяем, что mView создана и в ней есть нужный метод
            if (mView != null && mView has :onDataReceived) {
                mView.onDataReceived(msg.data);
            }
            
            // 3. Запрашиваем перерисовку интерфейса
            WatchUi.requestUpdate();
        }
    }

    function onStart(state) {
        // Включаем GPS в непрерывном режиме
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        
        // Регистрируем обработчик входящих сообщений
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
        // Создаем вьюху один раз и сохраняем ссылку в переменную класса
        mView = new legendmasterView();
        return [ mView, new legendmasterDelegate(mView) ];
    }
}