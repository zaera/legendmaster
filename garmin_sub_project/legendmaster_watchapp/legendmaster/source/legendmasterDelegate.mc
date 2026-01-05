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

    // Обработка кнопки START/STOP (Верхняя правая)
    function onSelect() {
        var app = Application.getApp();
        if (view.appState == 0) { 
            app.session = ActivityRecording.createSession({:name=>"LegendRun", :sport=>ActivityRecording.SPORT_RUNNING});
            app.session.start();
            view.appState = 1;
        } else if (view.appState == 1) { 
            if (app.session != null && app.session.isRecording()) { app.session.stop(); }
            view.appState = 2;
        } else if (view.appState == 2) { 
            if (app.session != null) { app.session.start(); }
            view.appState = 1;
        }
        WatchUi.requestUpdate();
        return true;
    }

    // Обработка кнопки BACK (Нижняя правая)
    function onBack() {
        // 1. Если мы на ГЛАВНОМ экране и старт НЕ нажат — ВЫХОД из программы
        if (view.pageID == 0 && view.appState == 0) {
            System.exit();
            return true;
        }

        // 2. Если мы в меню ПАУЗЫ — СОХРАНИТЬ и ВЫЙТИ
        if (view.appState == 2) { 
            var app = Application.getApp();
            if (app.session != null) {
                app.session.save();
                app.session = null;
            }
            System.exit();
            return true;
        }

        // 3. Во всех остальных случаях (экран иконок, компас и т.д.) — листаем страницу НАЗАД
        // На экране иконок (pageID 1) это вернет нас на главный экран (pageID 0)
        view.changePage(-1); 
        return true;
    }

    // Обработка кнопки DOWN (Нижняя левая)
    function onNextPage() {
        if (view.appState == 2) { 
            var app = Application.getApp();
            if (app.session != null) {
                app.session.stop();
                app.session.discard();
                app.session = null;
            }
            System.exit();
            return true;
        }
        if (view.pageID == 1) { view.scrollIcons(1); } else { view.changePage(1); }
        return true;
    }

    // Обработка кнопки UP (Средняя левая)
    function onPreviousPage() {
        if (view.pageID == 1) { view.scrollIcons(-1); } else { view.changePage(-1); }
        return true;
    }
}