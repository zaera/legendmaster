using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Activity;
using Toybox.Math;
using Toybox.System;

class legendmasterView extends WatchUi.View {
    var myFont;
    var pageID = 0; 
    var currentIndex = 0;
    var launchTime;
    var appState = 0; // 0-Ready, 1-Run, 2-Pause

    var controlPoints = [
        [31, 12, 45, 0, 8, 0], [32, 0, 122, 14, 0, 1], [33, 2, 50, 0, 0, 0],
        [34, 0, 45, 45, 5, 2], [35, 10, 80, 0, 0, 0], [36, 0, 15, 12, 0, 3],
        [37, 5, 45, 0, 0, 0], [38, 0, 90, 14, 7, 0], [39, 1, 122, 0, 0, 1],
        [40, 0, 45, 0, 0, 0], [41, 0, 30, 12, 0, 0], [42, 3, 55, 0, 5, 0],
        [43, 0, 122, 15, 0, 2], [100, 0, 170, 0, 0, 0]
    ];

    function initialize() { 
        View.initialize(); 
        launchTime = System.getTimer();
    }
    
    function onLayout(dc) { 
        myFont = WatchUi.loadResource(Rez.Fonts.LegendFont); 
    }

    function changePage(dir) {
        pageID += dir;
        if (pageID < -1) { pageID = 1; }
        if (pageID > 1) { pageID = -1; }
        WatchUi.requestUpdate();
    }

    function scrollIcons(step) {
        currentIndex += step;
        var size = controlPoints.size();
        if (currentIndex < 0) { currentIndex = 0; }
        if (currentIndex >= size) { currentIndex = size - 1; }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(0x000000, 0x000000);
        dc.clear();
        
        var w = dc.getWidth(), h = dc.getHeight();
        if (System.getTimer() - launchTime < 1000) {
            drawSplashScreen(dc, w, h);
            WatchUi.requestUpdate();
            return;
        }

        var info = Activity.getActivityInfo();
        var app = Application.getApp();

        // Если ПАУЗА — рисуем меню поверх всего
        if (appState == 2) {
            drawPauseMenu(dc, info, w, h);
        } else {
            // Иначе рисуем тот экран, на котором находится пользователь
            if (pageID == 1) {
                drawIcons(dc, w, h);
            } else if (pageID == -1) {
                drawNavigation(dc, info, w, h);
            } else {
                drawMain(dc, info, app, w, h);
            }
        }
    }

    function drawSplashScreen(dc, w, h) {
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2, h/2 - 20, Graphics.FONT_LARGE, "LegendMaster", 1|4);
        dc.setColor(0xAAAAAA, -1);
        dc.drawText(w/2, h/2 + 25, Graphics.FONT_XTINY, "by punishman", 1|4);
    }

    function drawMain(dc, info, app, w, h) {
        dc.setColor(0xFFFFFF, -1);
        var dist = "0.00", timer = "00:00";
        if (info != null) {
            if (info.elapsedDistance != null) { dist = (info.elapsedDistance/1000.0).format("%.2f"); }
            if (info.timerTime != null) { timer = formatTime(info.timerTime); }
        }
        dc.drawText(w/2, h/2 - 60, Graphics.FONT_XTINY, "DISTANCE", 1);
        dc.drawText(w/2, h/2 - 40, Graphics.FONT_NUMBER_MEDIUM, dist, 1);
        dc.drawText(w/2, h/2 + 20, Graphics.FONT_LARGE, timer, 1);

        if (appState == 0) {
            dc.setColor(0x55AAFF, -1);
            dc.drawText(w - 10, h/4, Graphics.FONT_XTINY, "START", Graphics.TEXT_JUSTIFY_RIGHT);
        } else {
            drawPauseSymbol(dc, w, h);
        }
    }

    function drawPauseMenu(dc, info, w, h) {
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2, 35, Graphics.FONT_TINY, "PAUSED", 1);
        
        var dist = (info.elapsedDistance != null) ? (info.elapsedDistance/1000.0).format("%.2f") : "0.00";
        var timer = (info.timerTime != null) ? formatTime(info.timerTime) : "00:00";
        
        dc.drawText(w/2, h/2 - 15, Graphics.FONT_SMALL, timer, 1);
        dc.drawText(w/2, h/2 + 15, Graphics.FONT_SMALL, dist + " km", 1);

        dc.setColor(0x00FF00, -1);
        dc.drawText(w - 10, h/4, Graphics.FONT_XTINY, "RESUME", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(0xFF5555, -1);
        dc.drawText(w - 10, h*0.75, Graphics.FONT_XTINY, "SAVE", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(0xAAAAAA, -1);
        dc.drawText(10, h*0.75, Graphics.FONT_XTINY, "DISCARD", Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawIcons(dc, w, h) {
        var midX = w / 2, midY = h / 2;
        var currentData = controlPoints[currentIndex];
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(midX, 25, Graphics.FONT_XTINY, "КП " + (currentIndex + 1) + " (№" + currentData[0] + ")", 1);
        if (myFont != null) {
            var step = 42, startX = midX - (step * 2); 
            for (var i = 0; i < 5; i++) {
                var iconID = currentData[i + 1];
                if (iconID != 0) {
                    var char = (57345 + iconID).toChar();
                    dc.drawText(startX + (i * step), midY, myFont, char.toString(), 1|4);
                }
            }
        }
        drawUIElements(dc, w, h, midX, midY);
    }

    function drawPauseSymbol(dc, w, h) {
        dc.setColor(0x55AAFF, -1);
        dc.setPenWidth(3);
        var rightX = w * 0.88;
        var midY = h / 2;
        var pX = rightX + 2, pY = midY - 60;
        dc.drawLine(pX - 3, pY - 6, pX - 3, pY + 6);
        dc.drawLine(pX + 3, pY - 6, pX + 3, pY + 6);
    }

    function drawUIElements(dc, w, h, midX, midY) {
        var leftX = w * 0.12;
        var rightX = w * 0.88;
        dc.setColor(0x55AAFF, -1);

        // Треугольники слева
        dc.fillPolygon([[leftX-13, midY + 26], [leftX - 19, midY + 35], [leftX-7, midY + 35]]);
        dc.fillPolygon([[leftX-8, midY + 55], [leftX - 14, midY + 46], [leftX -2, midY + 46]]);

        // Крестик справа снизу
        dc.setPenWidth(2);
        var cs = 5, curX = rightX + 2, curY = midY + 60;
        dc.drawLine(curX - cs, curY - cs, curX + cs, curY + cs);
        dc.drawLine(curX - cs, curY + cs, curX + cs, curY - cs);

        // Символ паузы (если запись запущена)
        if (appState == 1) {
            drawPauseSymbol(dc, w, h);
        }
    }

    function drawNavigation(dc, info, w, h) {
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2, 20, Graphics.FONT_TINY, "BACK TO START", 1);
        if (info != null && info.startLocation != null && info.currentLocation != null) {
            dc.setPenWidth(2);
            dc.drawCircle(w/2, h/2, 30);
            dc.drawLine(w/2, h/2, w/2, h/2 - 25);
        } else {
            dc.drawText(w/2, h/2, Graphics.FONT_XTINY, "WAITING GPS...", 1);
        }

        if (appState == 1) {
            drawPauseSymbol(dc, w, h);
        }
    }

    function formatTime(ms) {
        var s = ms / 1000;
        return (s/60).format("%02d") + ":" + (s%60).format("%02d");
    }
}