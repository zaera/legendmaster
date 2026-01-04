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

    function onBack() {
        if (view.appState == 2) { 
            var app = Application.getApp();
            if (app.session != null) {
                app.session.save();
                app.session = null;
            }
            System.exit();
            return true;
        }
        view.changePage(-1); 
        return true;
    }

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

    function onPreviousPage() {
        if (view.pageID == 1) { view.scrollIcons(-1); } else { view.changePage(-1); }
        return true;
    }
}