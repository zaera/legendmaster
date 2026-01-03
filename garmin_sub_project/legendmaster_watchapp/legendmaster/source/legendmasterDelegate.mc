using Toybox.WatchUi;
using Toybox.System;
using Toybox.Application;
using Toybox.ActivityRecording;

class legendmasterDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    // Кнопка START: Старт / Пауза
    function onSelect() {
        var app = Application.getApp();
        if (view.appState == 0) { // Если еще не бежим
            app.session = ActivityRecording.createSession({:name=>"LegendRun", :sport=>ActivityRecording.SPORT_RUNNING});
            app.session.start();
            view.appState = 1;
        } else if (view.appState == 1) { // Если бежим - пауза
            app.session.stop();
            view.appState = 2;
        } else if (view.appState == 2) { // Если на паузе - возобновить
            app.session.start();
            view.appState = 1;
        }
        WatchUi.requestUpdate();
        return true;
    }

    // Кнопка BACK: Меню сохранения на паузе или выход в навигацию
    function onBack() {
        if (view.appState == 2) { // Если нажали BACK на паузе - СОХРАНИТЬ
            Application.getApp().session.save();
            System.exit();
            return true;
        }
        view.changePage(-1); // Иначе - уйти на экран навигации (ДОМОЙ)
        return true;
    }

    // Кнопки UP/DOWN: Листаем легенду, если мы на экране иконок
    function onNextPage() {
        if (view.appState == 2) { // Если на паузе - СБРОС (Discard)
            Application.getApp().session.discard();
            System.exit();
            return true;
        }
        if (view.pageID == 1) { view.scrollIcons(1); } else { view.changePage(1); }
        return true;
    }

    function onPreviousPage() {
        if (view.pageID == 1) { view.scrollIcons(-1); } else { view.changePage(-1); }
        return true;
    }
}