using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Activity;
using Toybox.System;
using Toybox.Position;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;
using Toybox.ActivityMonitor;

class legendmasterView extends WatchUi.View {
    var myFont;
    var pageID = 0; 
    var currentIndex = 0;
    var launchTime;
    var appState = 0; 
    var controlPoints = []; 
    var updateTimer as Timer.Timer?;
    var startLocation = null;
    var lastHeading = 0.0;
    var stepsOffset = null;

    function initialize() { 
        View.initialize(); 
        launchTime = System.getTimer();
        loadSettings(); 
        updateTimer = new Timer.Timer();
        updateTimer.start(method(:onTimerUpdate), 1000, true);
    }

    function onLayout(dc) { 
        try { myFont = WatchUi.loadResource(Rez.Fonts.LegendFont); } catch(ex) { myFont = null; }
    }

    function onTimerUpdate() as Void { WatchUi.requestUpdate(); }

    function getCurrentSteps() {
        var info = ActivityMonitor.getInfo();
        return (info != null && info.steps != null) ? info.steps : 0;
    }

    // --- ПОДСЧЕТ ПАР ШАГОВ (Сброс при > 999) ---
    function calculatePaces() {
        var totalSteps = getCurrentSteps();
        
        if (stepsOffset == null) { stepsOffset = totalSteps; }
        
        var localSteps = totalSteps - stepsOffset;
        if (localSteps < 0) { localSteps = 0; }
        
        var paces = localSteps / 2;

        if (paces > 999) {
            stepsOffset = totalSteps; // Обнуляем
            return 0;
        }
        return paces;
    }

    function onUpdate(dc) {
        dc.setColor(0x000000, 0x000000);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();

        // Пропорциональные отступы
        var posStart  = [55, h / 3.4];
        var posPause  = [25, h / 3.4]; 
        var posResume = [65, h / 3.4];
        var posSave   = [55, h * 0.72];
        var posDisc   = [80, h * 0.72];
        var gpsSettings = [16, 7, 2, 5, 3, h - 22];
        
        if (System.getTimer() - launchTime < 2000) { 
            drawSplashScreen(dc, w, h); 
            return; 
        }

        var info = Activity.getActivityInfo();
        if (appState == 1 && startLocation == null && info.currentLocation != null) {
            startLocation = info.currentLocation;
        }

        if (appState == 2) { 
            stepsOffset = null; 
            drawPauseMenu(dc, info, w, h, posResume, posSave, posDisc); 
        } else if (pageID == -2) { 
            drawNavigation(dc, info, w, h, posPause, gpsSettings); 
        } else if (pageID == -1) { 
            drawCompass(dc, info, w, h, posPause); 
        } else if (pageID == 0) { 
            drawMain(dc, info, w, h, posStart, posPause, gpsSettings); 
        } else if (pageID == 1) { 
            drawIcons(dc, info, w, h, posPause); 
        }
    }

    // --- ЭКРАН: КОМПАС ---
    function drawCompass(dc, info, w, h, pPause) {
        var paces = calculatePaces();
        var ringWidth = 30; 
        var arrowW = 16;          
        var arrowL = (w / 2) - 40; 
        
        var sectorColors = [0xFF0000, 0x000000, 0x0000FF, 0xFFFF00, 0x00FF00, 0xFFFFFF, 0x00FFFF, 0xFFAA00, 0xAA00FF, 0xAAAAAA, 0x00AA00, 0xAA0000, 0x0000AA, 0x00aaff, 0xff5500, 0x550055];
        var cx = w/2; var cy = h/2;
        var heading = (info != null && info.currentHeading != null) ? info.currentHeading : lastHeading;
        lastHeading = heading;

        var numSectors = 16; var sectorSize = 360.0 / numSectors; 
        for (var i = 0; i < numSectors; i++) {
            dc.setColor(sectorColors[i], -1);
            var angleDeg = (i * sectorSize).toFloat();
            dc.setPenWidth(ringWidth);
            dc.drawArc(cx, cy, (w/2) - (ringWidth/2), Graphics.ARC_CLOCKWISE, 90.0 - angleDeg, 90.0 - angleDeg - sectorSize);

            if (i % 2 != 0 && i != 1) {
                var textColor = (i == 11 || i == 15) ? 0xFFFFFF : 0x000000;
                dc.setColor(textColor, -1);
                var midAngleRad = (90.0 - angleDeg - (sectorSize / 2.0)) * (Math.PI / 180.0);
                var dist = (w / 2.0) - (ringWidth / 2.0);
                dc.drawText(cx + dist * Math.cos(midAngleRad), cy - dist * Math.sin(midAngleRad), Graphics.FONT_TINY, (65 + ((i - 3) / 2)).toChar().toString(), 1|4);
            }
        }

        var sAngle = -heading - (Math.PI / 2.0); 
        var cosA = Math.cos(sAngle); var sinA = Math.sin(sAngle);
        var cosOrth = Math.cos(sAngle + Math.PI/2.0); var sinOrth = Math.sin(sAngle + Math.PI/2.0);
        var p1 = [cx + cosOrth * (arrowW/2), cy + sinOrth * (arrowW/2)];
        var p2 = [cx - cosOrth * (arrowW/2), cy - sinOrth * (arrowW/2)];
        dc.setColor(0xFF0000, -1);
        dc.fillPolygon([p1, p2, [p2[0] + cosA * arrowL, p2[1] + sinA * arrowL], [p1[0] + cosA * arrowL, p1[1] + sinA * arrowL]]);
        var p5 = [p2[0] - cosA * arrowL, p2[1] - sinA * arrowL];
        var p6 = [p1[0] - cosA * arrowL, p1[1] - sinA * arrowL];
        dc.setColor(0xFFFFFF, -1); dc.setPenWidth(2);
        dc.drawLine(p1[0], p1[1], p6[0], p6[1]); dc.drawLine(p2[0], p2[1], p5[0], p5[1]); dc.drawLine(p5[0], p5[1], p6[0], p6[1]);

        // ШАГИ (ИСПРАВЛЕНО: w * 0.20 для адаптивности)
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(cx + (w * 0.20), cy - (h * 0.36), Graphics.FONT_TINY, paces.toString(), 2|4);

        if (appState == 1) { drawPauseSymbol(dc, w, h, pPause); }
    }

    // --- ЭКРАН: ГЛАВНЫЙ ---
    function drawMain(dc, info, w, h, pStart, pPause, gpsS) {
        var paces = calculatePaces();
        
        dc.setColor(0xFFFFFF, -1);
        var t = (info != null && info.timerTime != null) ? info.timerTime : 0;
        var d = (info != null && info.elapsedDistance != null) ? info.elapsedDistance : 0;
        var hr = (info != null && info.currentHeartRate != null) ? info.currentHeartRate : "--";
        
        dc.setColor(0xFF5555, -1);
        var hrY = h/2 - 95; 
        dc.fillCircle(w/2 - 6, hrY, 5); dc.fillCircle(w/2 + 2, hrY, 5);
        dc.fillPolygon([[w/2 - 11, hrY + 2], [w/2 + 7, hrY + 2], [w/2 - 2, hrY + 12]]);
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2 + 40, hrY - 8, Graphics.FONT_TINY, hr.toString(), 0);

        dc.drawText(w/2, h/2 - 60, Graphics.FONT_XTINY, "DISTANCE", 1);
        dc.drawText(w/2, h/2 - 40, Graphics.FONT_NUMBER_MEDIUM, (d / 1000.0).format("%.2f"), 1);
        dc.drawText(w/2, h/2 + 20, Graphics.FONT_LARGE, formatTime(t), 1);

        // ШАГИ (ИСПРАВЛЕНО: w * 0.20 для адаптивности)
        dc.drawText(w/2 + (w * 0.20), h/2 - (h * 0.36), Graphics.FONT_TINY, paces.toString(), 2|4);

        drawGPSBottom(dc, info, w, gpsS);
        if (appState == 0) {
            dc.setColor(0x55AAFF, -1);
            dc.drawText(w - pStart[0], pStart[1], Graphics.FONT_XTINY, "START", 2);
        } else { drawPauseSymbol(dc, w, h, pPause); }
    }

    // --- ЭКРАН: ИКОНКИ ---
    function drawIcons(dc, info, w, h, pPause) {
        var paces = calculatePaces();

        var midX = w / 2, midY = h / 2 + 10;
        if (controlPoints.size() == 0) {
            dc.setColor(0xFFFFFF, -1);
            dc.drawText(midX, midY, Graphics.FONT_XTINY, "NO DATA", 1|4);
            return;
        }
        var currentData = controlPoints[currentIndex];
        var orderNumStr = (currentIndex + 1).toString();
        var cpNumStr = currentData[0].toString();

        var hasIcons = false;
        for (var i = 1; i <= 6; i++) {
            if (currentData.size() > i && currentData[i] != 0) { hasIcons = true; }
        }

        // --- ХЕДЕР: ДИСТАНЦИЯ И ВРЕМЯ (Пропорционально) ---
        var t = (info != null && info.timerTime != null) ? info.timerTime : 0;
        var d = (info != null && info.elapsedDistance != null) ? info.elapsedDistance : 0;
        
        var distY = h * 0.06;
        var timeY = h * 0.17;
        var lineY = h * 0.24;

        dc.setColor(0xAAAAAA, -1);
        dc.drawText(midX, distY, Graphics.FONT_XTINY, (d / 1000.0).format("%.2f") + " km", 1|4);
        dc.drawText(midX - 15, timeY, Graphics.FONT_LARGE, formatTime(t), 1|4);

        // Линия
        dc.setPenWidth(1);
        dc.setColor(0xAAAAAA, -1);
        dc.drawLine(30, lineY, w - 30, lineY);

        // ШАГИ (ИСПРАВЛЕНО: w * 0.20 для адаптивности)
        dc.setColor(0xff5500, -1);
        dc.drawText(w/2 + (w * 0.20), h/2 - (h * 0.36), Graphics.FONT_TINY, paces.toString(), 2|4);

        if (hasIcons) {
            // --- СЦЕНАРИЙ 1 ---
            var boxSize = 38; 
            var halfBox = boxSize / 2;
            var y_delta = 30; 
            var positions = [
                [midX + halfBox, midY - boxSize - halfBox + y_delta],
                [midX - boxSize - halfBox, midY - halfBox + y_delta],
                [midX - halfBox, midY - halfBox + y_delta],
                [midX + halfBox, midY - halfBox + y_delta],
                [midX - 2*halfBox, midY + halfBox+y_delta],
                [midX , midY + halfBox+y_delta]
            ];

            dc.setPenWidth(1);
            for (var i = 0; i < 6; i++) {
                var dataIdx = i + 1;
                if (currentData.size() > dataIdx) {
                    var iconID = currentData[dataIdx];
                    if (iconID != 0) {
                        var bx = positions[i][0];
                        var by = positions[i][1];
                        dc.setColor(0xFFFFFF, -1);
                        dc.drawRectangle(bx, by, boxSize, boxSize);
                        var centerX = bx + halfBox;
                        var centerY = by + halfBox;
                        if (myFont != null) {
                            dc.drawText(centerX, centerY, myFont, (57345 + iconID).toChar().toString(), 1|4);
                        } else {
                            dc.drawText(centerX, centerY, Graphics.FONT_XTINY, iconID.toString(), 1|4);
                        }
                    }
                }
            }
            var topRowCenterY = positions[0][1] + halfBox; 
            dc.drawText(midX - 50, topRowCenterY-20, Graphics.FONT_NUMBER_HOT, cpNumStr, 2|4); 
            var cpWidth = dc.getTextWidthInPixels(cpNumStr, Graphics.FONT_NUMBER_HOT);
            dc.drawText(midX - 30 - cpWidth - 5, topRowCenterY, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);

        } else {
            // --- СЦЕНАРИЙ 2 ---
            dc.setColor(0xFFFFFF, -1);
            dc.drawText(midX, midY-19, Graphics.FONT_NUMBER_THAI_HOT, cpNumStr, 1|4);
            var bigCpWidth = dc.getTextWidthInPixels(cpNumStr, Graphics.FONT_NUMBER_THAI_HOT);
            var offsetLeft = (bigCpWidth / 2) + 10;
            dc.drawText(midX - offsetLeft - 30, midY, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);

            if (currentIndex + 1 < controlPoints.size()) {
                var y_tri_delta = 47;
                dc.setColor(0xAAAAAA, -1); 
                dc.fillPolygon([[w/2 - 6, h/2 - 4 + y_tri_delta], [w/2 + 6, h/2 - 4 + y_tri_delta], [w/2, h/2 + 4 + y_tri_delta]]);
                var nextData = controlPoints[currentIndex + 1];
                var nextCpStr = nextData[0].toString();
                dc.drawText(midX, midY + 65, Graphics.FONT_NUMBER_MEDIUM, nextCpStr, 1|4);
            }
        }
        drawUIElements(dc, w, h, midX, midY, pPause);
    }

    // --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---
    function drawNavigation(dc, info, w, h, pPause, gpsS) {
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2, 25, Graphics.FONT_TINY, "BACK TO START", 1);
        var d = (info != null && info.elapsedDistance != null) ? (info.elapsedDistance / 1000.0).format("%.2f") : "0.00";
        dc.drawText(w/2, h - 55, Graphics.FONT_MEDIUM, d + " km", 1);
        var cx = w/2, cy = h/2 - 10;
        dc.setPenWidth(2); dc.drawCircle(cx, cy, 40);
        if (startLocation != null && info != null && info.currentLocation != null) {
            var cur = info.currentLocation.toDegrees(); var st = startLocation.toDegrees();
            var arrowAngle = Math.atan2(st[1] - cur[1], st[0] - cur[0]) - ((info.currentHeading != null) ? info.currentHeading : lastHeading) + (Math.PI / 2.0);
            var x2 = cx + 35 * Math.cos(arrowAngle), y2 = cy - 35 * Math.sin(arrowAngle);
            dc.setColor(0x55AAFF, -1); dc.setPenWidth(4); dc.drawLine(cx, cy, x2, y2);
            var hs = 10; dc.fillPolygon([[x2, y2], [x2 - hs * Math.cos(arrowAngle - 0.5), y2 + hs * Math.sin(arrowAngle - 0.5)], [x2 - hs * Math.cos(arrowAngle + 0.5), y2 + hs * Math.sin(arrowAngle + 0.5)]]);
        } else { dc.drawText(cx, cy, Graphics.FONT_XTINY, "WAIT GPS", 1|4); }
        drawGPSBottom(dc, info, w, gpsS);
        if (appState == 1) { drawPauseSymbol(dc, w, h, pPause); }
    }

    function drawGPSBottom(dc, info, w, s) {
        var acc = (info != null && info.currentLocationAccuracy != null) ? info.currentLocationAccuracy : 0;
        var colors = [0x555555, 0xFF0000, 0xFFAA00, 0xFFFF00, 0x00FF00];
        var x = (w / 2) - (s[0] / 2), gY = s[5];
        dc.setColor(colors[acc], -1);
        dc.fillRectangle(x, gY + (s[1] - s[4]), s[3], s[4]);
        dc.fillRectangle(x + s[3] + ((s[0] - (s[3]*2) - s[2])/2), gY, s[2], s[1]);
        dc.fillRectangle(x + s[0] - s[3], gY + (s[1] - s[4]), s[3], s[4]);
    }

    function drawPauseMenu(dc, info, w, h, pRes, pSave, pDisc) {
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2, h * 0.1, Graphics.FONT_SMALL, "PAUSED", 1);
        dc.drawText(w/2, h/2 - (h * 0.13), Graphics.FONT_NUMBER_HOT, formatTime((info != null && info.timerTime != null) ? info.timerTime : 0), 1);
        dc.setColor(0x00FF00, -1); dc.drawText(w - pRes[0]-10, pRes[1], Graphics.FONT_XTINY, "RESUME", 2);
        dc.setColor(0xFF5555, -1); dc.drawText(w - pSave[0]-10, pSave[1], Graphics.FONT_XTINY, "SAVE", 2);
        dc.setColor(0xAAAAAA, -1); dc.drawText(pDisc[0]+10, pDisc[1], Graphics.FONT_XTINY, "DISCARD", 0);
    }

    function drawPauseSymbol(dc, w, h, pPause) {
        dc.setColor(0x55AAFF, -1); dc.setPenWidth(3);
        dc.drawLine(w-pPause[0]-3, pPause[1]-6, w-pPause[0]-3, pPause[1]+6); dc.drawLine(w-pPause[0]+3, pPause[1]-6, w-pPause[0]+3, pPause[1]+6);
    }

    function drawUIElements(dc, w, h, midX, midY, pPause) {
        var lX = w * 0.12, rX = w * 0.88;
        var x_delta = -10;
        dc.setColor(0x55AAFF, -1);
        dc.fillPolygon([[lX-10, midY + 26], [lX - 16, midY + 35], [lX-4, midY + 35]]);
        dc.fillPolygon([[lX-5, midY + 55], [lX - 11, midY + 46], [lX +1, midY + 46]]);
        dc.setPenWidth(2); dc.drawLine(rX - 5 + x_delta, midY + 55, rX + 5 +x_delta, midY + 65);
        dc.drawLine(rX - 5 + x_delta, midY + 65, rX + 5 + x_delta, midY + 55);
        if (appState == 1) { drawPauseSymbol(dc, w, h, pPause); }
    }

    function drawSplashScreen(dc, w, h) {
        dc.setColor(0xAAAAAA, -1);
        dc.drawText(w/2, h/2-75, Graphics.FONT_XTINY, "isom2024", 1|4);
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2, h/2 - 35, Graphics.FONT_LARGE, "LegendMaster", 1|4);
        dc.setColor(0xAAAAAA, -1);
        dc.drawText(w/2, h/2, Graphics.FONT_SMALL, "by punishman", 1|4);
        dc.drawText(w/2, h/2 + 40, Graphics.FONT_XTINY, "Thanks to:", 1|4);
        dc.drawText(w/2, h/2 + 55, Graphics.FONT_XTINY, "laura coach Ann10_08 killkost", 1|4);
        dc.drawText(w/2, h/2 + 75, Graphics.FONT_XTINY, "michailova22", 1|4);
    }

    function formatTime(ms) {
        var totalSeconds = ms / 1000;
        var h = totalSeconds / 3600;
        var m = (totalSeconds / 60) % 60;
        var s = totalSeconds % 60;
        
        if (h > 0) {
            return h.format("%d") + ":" + m.format("%02d") + ":" + s.format("%02d");
        } else {
            return m.format("%02d") + ":" + s.format("%02d");
        }
    }

    function loadSettings() {
        controlPoints = [
            [31, 11, 12, 13, 14, 15, 16], 
            [100, 0, 0, 0, 0, 0, 0],
            [32, 0, 0, 0, 0, 0, 0] 
        ];
    }

    function splitString(str, devider) {
        var result = [];
        var index = str.find(devider.toString());
        while (index != null) {
            result.add(str.substring(0, index));
            str = str.substring(index + 1, str.length());
            index = str.find(devider.toString());
        }
        result.add(str);
        return result;
    }

    function changePage(dir) {
        var newID = pageID + dir;
        if (newID >= -2 && newID <= 1) { pageID = newID; stepsOffset = null; WatchUi.requestUpdate(); }
    }

    function scrollIcons(step) {
        currentIndex += step;
        if (currentIndex < 0) { currentIndex = 0; }
        if (currentIndex >= controlPoints.size()) { currentIndex = controlPoints.size() - 1; }
        WatchUi.requestUpdate();
    }
}