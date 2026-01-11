using Toybox.WatchUi;
using Toybox.System;
using Toybox.Application;
using Toybox.ActivityRecording;

// --- 1. КНОПОЧНЫЙ ДЕЛЕГАТ (Fenix 3 HR) ---
class legendmasterButtonDelegate extends WatchUi.BehaviorDelegate {
    var view;
    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() { return triggerStartStop(view); }
    function onBack() {
        if (view.pageID == 0 && view.appState == 0) { System.exit(); return true; }
        if (view.appState == 2) { 
            var app = Application.getApp();
            if (app.session != null) { app.session.save(); app.session = null; }
            System.exit(); return true;
        }
        view.changePage(-1);
        return true;
    }
    function onNextPage() { // DOWN
        if (view.appState == 2) { 
            var app = Application.getApp();
            if (app.session != null) { app.session.stop(); app.session.discard(); app.session = null; }
            System.exit(); return true;
        }
        if (view.pageID == 1) { view.scrollIcons(1); } else { view.changePage(1); }
        return true;
    }
    function onPreviousPage() { // UP
        if (view.pageID == 1) { view.scrollIcons(-1); } else { view.changePage(-1); }
        return true;
    }
    function onMenu() { // MENU (Средняя левая на F3)
        if (view.appState == 2) { view.resetSpoof(); return true; }
        return false;
    }
}

// --- 2. ТАЧ ДЕЛЕГАТ (Enduro, Fenix 7 и др.) ---
class legendmasterTouchDelegate extends WatchUi.InputDelegate {
    var view;
    function initialize(v) {
        InputDelegate.initialize();
        view = v;
    }

    function onTap(clickEvent) {
        var xy = clickEvent.getCoordinates();
        var x = xy[0]; var y = xy[1];
        var w = System.getDeviceSettings().screenWidth;
        var h = System.getDeviceSettings().screenHeight;

        if (view.msgTimer > 0) { return true; }

        if (view.appState == 2) {
            // Кнопка RESUME (справа сверху)
            if (x > w * 0.5 && y > h * 0.1 && y < h * 0.45) { return triggerStartStop(view); }
            // RESET SPOOF (Слева по центру)
            if (x < w * 0.4 && y > (h * 0.5 - 80) && y < (h * 0.5 + 20)) { 
                view.resetSpoof(); 
                return true; 
            }
            // Кнопка SAVE (справа снизу)
            if (x > w * 0.5 && y > h * 0.6) {
                var app = Application.getApp();
                if (app.session != null) { app.session.save(); app.session = null; }
                System.exit(); return true;
            }
            // Кнопка DISCARD (слева снизу)
            if (x < w * 0.5 && y > h * 0.6) {
                var app = Application.getApp();
                if (app.session != null) { app.session.stop(); app.session.discard(); app.session = null; }
                System.exit(); return true;
            }
            return true; 
        }

        // --- ЗОНА ПАУЗЫ ДЛЯ СТРАНИЦЫ 1 (ИКОНКИ) ---
        if (view.pageID == 1) {
            if (x > w * 0.7 && y > h * 0.7) { view.pageID = 0; WatchUi.requestUpdate(); return true; }
            // Расширенная зона: от центра вправо до края, по высоте от 15% до 50% экрана
            if (view.appState == 1 && x > w * 0.5 && y > h * 0.15 && y < h * 0.5) { return triggerStartStop(view); }
            return true; 
        }

        // --- ЗОНА ПАУЗЫ ДЛЯ СТРАНИЦЫ 0 (ГЛАВНАЯ) ---
        if (view.pageID == 0) {
            if (view.appState == 0) {
                if (x > w * 0.7 && y > h * 0.7) { System.exit(); return true; }
                if (x > w * 0.5 && y > h * 0.15 && y < h * 0.45) { return triggerStartStop(view); }
            } else if (view.appState == 1) {
                // Аналогично расширяем здесь
                if (x > w * 0.5 && y > h * 0.15 && y < h * 0.5) { return triggerStartStop(view); }
            }
        }
        return true; 
    }

    function onSwipe(swipeEvent) {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_UP) { if (view.pageID == 1) { view.scrollIcons(1); } else { view.changePage(1); } }
        else if (dir == WatchUi.SWIPE_DOWN) { if (view.pageID == 1) { view.scrollIcons(-1); } else { view.changePage(-1); } }
        else if (dir == WatchUi.SWIPE_LEFT) { view.changePage(1); }
        else if (dir == WatchUi.SWIPE_RIGHT) { view.changePage(-1); }
        return true;
    }

    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        
        // START/STOP
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) { return triggerStartStop(view); }
        
        // BACK/LAP
        if (key == WatchUi.KEY_ESC || key == WatchUi.KEY_LAP) {
             if (view.pageID == 0 && view.appState == 0) { System.exit(); return true; }
             if (view.appState == 2) { 
                var app = Application.getApp();
                if (app.session != null) { app.session.save(); app.session = null; }
                System.exit(); return true;
             }
             view.changePage(-1);
             return true;
        }
        
        // DOWN
        if (key == WatchUi.KEY_DOWN) {
            if (view.appState == 2) { 
                var app = Application.getApp();
                if (app.session != null) { app.session.stop(); app.session.discard(); app.session = null; }
                System.exit(); return true;
            }
            if (view.pageID == 1) { view.scrollIcons(1); } else { view.changePage(1); }
            return true;
        }
        
        // UP
        if (key == WatchUi.KEY_UP) {
            if (view.pageID == 1) { view.scrollIcons(-1); } else { view.changePage(-1); }
            return true;
        }
        
        // MENU (Средняя левая кнопка) - Сброс спуфа в паузе
        if (key == WatchUi.KEY_MENU) {
            if (view.appState == 2) { view.resetSpoof(); return true; }
        }
        
        return false;
    }
}

function triggerStartStop(view) {
    if (view.msgTimer > 0) { return true; }
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