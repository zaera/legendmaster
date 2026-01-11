using Toybox.Application;
using Toybox.Position;
using Toybox.ActivityRecording;
using Toybox.WatchUi;
using Toybox.Communications;

class legendmasterApp extends Application.AppBase {
    var session = null;
    var mView = null; 

    function initialize() { 
        AppBase.initialize(); 
    }

    function onPhoneAppMessage(msg as Communications.PhoneAppMessage) as Void {
        if (msg.data != null) {
            Application.getApp().setProperty("cp_data", msg.data);
            if (mView != null && mView has :onDataReceived) {
                mView.onDataReceived(msg.data);
            }
            WatchUi.requestUpdate();
        }
    }

    function onStart(state) {
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        Communications.registerForPhoneAppMessages(method(:onPhoneAppMessage));
    }

    function onPosition(info as Position.Info) as Void {
        WatchUi.requestUpdate();
    }

    function onStop(state) {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    function getInitialView() {
        mView = new legendmasterView();
        var settings = System.getDeviceSettings();
        
        // Проверяем наличие тача
        if (settings has :isTouchScreen && settings.isTouchScreen) {
            // Если тач есть — даем мощный InputDelegate
            return [ mView, new legendmasterTouchDelegate(mView) ];
        } else {
            // Если тача нет — даем стабильный BehaviorDelegate
            return [ mView, new legendmasterButtonDelegate(mView) ];
        }
    }
}