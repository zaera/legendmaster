using Toybox.WatchUi;
using Toybox.System;

class legendmasterDelegate extends WatchUi.BehaviorDelegate {
    var view;
    function initialize(v) { BehaviorDelegate.initialize(); view = v; }

    function onSelect() {
        var app = Application.getApp();
        if (app.session == null) { return true; }
        if (view.appState == 0 || view.appState == 2) { app.session.start(); view.appState = 1; }
        else { app.session.stop(); view.appState = 2; }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (view.appState == 2) { 
            var app = Application.getApp();
            if (app.session != null) { app.session.save(); app.session = null; }
            System.exit(); return true; 
        }
        if (view.pageID == 1) { view.changePage(-1); return true; }
        return false; 
    }

    function onNextPage() {
        if (view.appState == 2) { 
            var app = Application.getApp();
            if (app.session != null) { app.session.discard(); app.session = null; }
            System.exit(); return true; 
        }
        if (view.pageID == 1) { view.scrollIcons(1); }
        else { view.changePage(1); }
        return true;
    }

    function onPreviousPage() {
        if (view.appState == 2) { return true; }
        if (view.pageID == 1) { view.scrollIcons(-1); }
        else { view.changePage(-1); }
        return true;
    }
}