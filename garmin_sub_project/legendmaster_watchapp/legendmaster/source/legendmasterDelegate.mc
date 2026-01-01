using Toybox.WatchUi;
using Toybox.System;

class legendmasterDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    // START/STOP Кнопка
    function onSelect() {
        var app = Application.getApp();
        if (app.session == null) { return true; }

        if (view.appState == 0 || view.appState == 2) {
            // Если была пауза или готовность -> Начинаем/Продолжаем
            app.session.start();
            view.appState = 1;
        } else {
            // Если бежали -> Ставим на паузу
            app.session.stop();
            view.appState = 2;
        }
        WatchUi.requestUpdate();
        return true;
    }

    // BACK Кнопка
    function onBack() {
        var app = Application.getApp();
        // В режиме паузы — это SAVE
        if (view.appState == 2) {
            if (app.session != null) {
                app.session.save();
                app.session = null;
            }
            System.exit();
            return true;
        }
        // В режиме легенды — выход на главный
        if (view.pageID == 1) {
            view.changePage(-1);
            return true;
        }
        return false; 
    }

    // DOWN Кнопка
    function onNextPage() {
        // В режиме паузы — это DISCARD
        if (view.appState == 2) {
            var app = Application.getApp();
            if (app.session != null) {
                app.session.discard();
                app.session = null;
            }
            System.exit();
            return true;
        }
        // Перелистывание
        if (view.pageID == 1) { view.scrollIcons(1); }
        else { view.changePage(1); }
        return true;
    }

    // UP Кнопка
    function onPreviousPage() {
        if (view.appState == 2) { return true; } // Блокировка в меню паузы
        
        if (view.pageID == 1) { view.scrollIcons(-1); }
        else { view.changePage(-1); }
        return true;
    }
}