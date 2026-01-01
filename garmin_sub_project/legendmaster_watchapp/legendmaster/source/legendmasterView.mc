using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Activity;
using Toybox.Math;
using Toybox.System;
using Toybox.Position;

class legendmasterView extends WatchUi.View {
    var myFont, pageID = 0, currentIndex = 0, launchTime, appState = 0; 

    var controlPoints = [
        [31, 12, 45, 0, 8, 0], [32, 0, 122, 14, 0, 1], [33, 2, 50, 0, 0, 0],
        [34, 0, 45, 45, 5, 2], [35, 10, 80, 0, 0, 0], [36, 0, 15, 12, 0, 3],
        [37, 5, 45, 0, 0, 0], [38, 0, 90, 14, 7, 0], [39, 1, 122, 0, 0, 1],
        [40, 0, 45, 0, 0, 0], [41, 0, 30, 12, 0, 0], [42, 3, 55, 0, 5, 0],
        [43, 0, 122, 15, 0, 2], [100, 0, 170, 0, 0, 0]
    ];

    function initialize() { View.initialize(); launchTime = System.getTimer(); }
    function onLayout(dc) { myFont = WatchUi.loadResource(Rez.Fonts.LegendFont); }

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
        
        // Исправлено: заставка теперь уходит сама через 1 сек
        if (System.getTimer() - launchTime < 2000) { 
            drawSplashScreen(dc, w, h); 
            WatchUi.requestUpdate();
            return; 
        }

        var info = Activity.getActivityInfo();
        if (appState == 2) { drawPauseMenu(dc, info, w, h); }
        else if (pageID == 1) { drawIcons(dc, w, h); }
        else if (pageID == -1) { drawNavigation(dc, info, w, h); }
        else { drawMain(dc, info, w, h); }
    }

    function drawMain(dc, info, w, h) {
        dc.setColor(0xFFFFFF, -1);
        var dist = (info != null && info.elapsedDistance != null) ? (info.elapsedDistance/1000.0).format("%.2f") : "0.00";
        var timer = (info != null && info.timerTime != null) ? formatTime(info.timerTime) : "00:00";
        dc.drawText(w/2, h/2 - 60, Graphics.FONT_XTINY, "DISTANCE", 1);
        dc.drawText(w/2, h/2 - 40, Graphics.FONT_NUMBER_MEDIUM, dist, 1);
        dc.drawText(w/2, h/2 + 20, Graphics.FONT_LARGE, timer, 1);

        drawGPSBottom(dc, w, h);

        if (appState == 0) {
            dc.setColor(0x55AAFF, -1);
            dc.drawText(w - 10, h/4, Graphics.FONT_XTINY, "START", 2);
        } else { drawPauseSymbol(dc, w, h); }
    }

    function drawGPSBottom(dc, w, h) {
        var posInfo = Position.getInfo();
        var acc = (posInfo != null && posInfo.accuracy != null) ? posInfo.accuracy : 0;
        var colors = [0x555555, 0xFF0000, 0xFFAA00, 0xFFFF00, 0x00FF00];
        
        // --- НАСТРОЙКИ ГЕОМЕТРИИ ИКОНКИ ---
        var wingW = 6;      // Ширина боковых крыльев
        var wingH = 3;      // Толщина (высота) боковых крыльев
        var bodyW = 2;      // Ширина центральной палочки
        var bodyH = 8;      // Высота центральной палочки
        var gap   = 2;      // Зазор между крылом и центром
        
        var textOffset = 38; // ОТСТУП ЦИФРЫ ОТ НАЧАЛА ИКОНКИ (контролируй здесь)
        // ----------------------------------

        // Вычисляем общую ширину всей иконки для центровки
        var totalWidth = (wingW * 2) + bodyW + (gap * 2);
        var x = (w / 2) - (totalWidth / 2) - 5; // Смещение влево для компенсации цифры
        var y = h - 25;

        dc.setColor(colors[acc], -1);

        // 1. Левое крыло
        // Центрируем по вертикали относительно высоты центральной палочки
        dc.fillRectangle(x, y + (bodyH - wingH) / 2, wingW, wingH);
        
        // 2. Центральная палочка
        dc.fillRectangle(x + wingW + gap, y, bodyW, bodyH);
        
        // 3. Правое крыло
        dc.fillRectangle(x + wingW + bodyW + (gap * 2), y + (bodyH - wingH) / 2, wingW, wingH);

        // 4. Отрисовка цифры
        dc.setColor(0xFFFFFF, -1);
        // textOffset считается от левого края иконки (переменная x)
        dc.drawText(x + textOffset, y - 6, Graphics.FONT_XTINY, acc.toString(), 0);
    }

    function drawPauseMenu(dc, info, w, h) {
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2, 35, Graphics.FONT_TINY, "PAUSED", 1);
        var dist = (info != null && info.elapsedDistance != null) ? (info.elapsedDistance/1000.0).format("%.2f") : "0.00";
        var timer = (info != null && info.timerTime != null) ? formatTime(info.timerTime) : "00:00";
        dc.drawText(w/2, h/2 - 15, Graphics.FONT_SMALL, timer, 1);
        dc.drawText(w/2, h/2 + 15, Graphics.FONT_SMALL, dist + " km", 1);
        dc.setColor(0x00FF00, -1); dc.drawText(w - 10, h/4, Graphics.FONT_XTINY, "RESUME", 2);
        dc.setColor(0xFF5555, -1); dc.drawText(w - 10, h*0.75, Graphics.FONT_XTINY, "SAVE", 2);
        dc.setColor(0xAAAAAA, -1); dc.drawText(10, h*0.75, Graphics.FONT_XTINY, "DISCARD", 0);
    }

    function drawIcons(dc, w, h) {
        var midX = w / 2, midY = h / 2, currentData = controlPoints[currentIndex];
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

    function drawUIElements(dc, w, h, midX, midY) {
        var lX = w * 0.12, rX = w * 0.88;
        dc.setColor(0x55AAFF, -1);
        dc.fillPolygon([[lX-13, midY + 26], [lX - 19, midY + 35], [lX-7, midY + 35]]);
        dc.fillPolygon([[lX-8, midY + 55], [lX - 14, midY + 46], [lX -2, midY + 46]]);
        dc.setPenWidth(2);
        dc.drawLine(rX + 2 - 5, midY + 60 - 5, rX + 2 + 5, midY + 60 + 5);
        dc.drawLine(rX + 2 - 5, midY + 60 + 5, rX + 2 + 5, midY + 60 - 5);
        if (appState == 1) { drawPauseSymbol(dc, w, h); }
    }

    function drawPauseSymbol(dc, w, h) {
        dc.setColor(0x55AAFF, -1); dc.setPenWidth(3);
        var rX = w * 0.88, mY = h / 2 - 60;
        dc.drawLine(rX - 1, mY - 6, rX - 1, mY + 6);
        dc.drawLine(rX + 5, mY - 6, rX + 5, mY + 6);
    }

    function drawNavigation(dc, info, w, h) {
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2, 20, Graphics.FONT_TINY, "BACK TO START", 1);
        if (info != null && info.startLocation != null) {
            dc.setPenWidth(2); dc.drawCircle(w/2, h/2, 30); dc.drawLine(w/2, h/2, w/2, h/2 - 25);
        } else { dc.drawText(w/2, h/2, Graphics.FONT_XTINY, "WAITING GPS...", 1); }
        if (appState == 1) { drawPauseSymbol(dc, w, h); }
    }

    function drawSplashScreen(dc, w, h) {
        dc.setColor(0xFFFFFF, -1); dc.drawText(w/2, h/2 - 20, Graphics.FONT_LARGE, "LegendMaster", 1|4);
        dc.setColor(0xAAAAAA, -1); dc.drawText(w/2, h/2 + 25, Graphics.FONT_XTINY, "by punishman", 1|4);
    }

    function formatTime(ms) {
        var s = ms / 1000;
        return (s/60).format("%02d") + ":" + (s%60).format("%02d");
    }
}