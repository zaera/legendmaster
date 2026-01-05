using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Activity;
using Toybox.System;
using Toybox.Position;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;
using Toybox.ActivityMonitor;
using Toybox.Sensor;

class legendmasterView extends WatchUi.View {
    // === ПЕРЕМЕННЫЕ ДЛЯ ПОДБОРА ОТСТУПОВ ===
    var pacesMarginEnduro = 45; 
    var pacesMarginFenix  = 35;
    var cpOffsetEnduro = 70;
    var cpOffsetFenix  = 50;

    var pacesColorMain    = 0x000000; 
    var pacesColorOutline = 0xffffff; 
    // =======================================

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
    var distanceOffset = null; // Базовая дистанция для счетчика метров

    function initialize() { 
        View.initialize(); 
        launchTime = System.getTimer();
        loadSettings(); 
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        updateTimer = new Timer.Timer();
        updateTimer.start(method(:onTimerUpdate), 250, true);
    }

    function onLayout(dc) { 
        try { myFont = WatchUi.loadResource(Rez.Fonts.LegendFont); } catch(ex) { myFont = null; }
    }

    function onTimerUpdate() as Void { WatchUi.requestUpdate(); }

    function onHide() {
        if (updateTimer != null) {
            updateTimer.stop();
            updateTimer = null;
        }
    }

    function getCurrentSteps() {
        var info = ActivityMonitor.getInfo();
        return (info != null && info.steps != null) ? info.steps : 0;
    }

    function calculatePaces() {
        var totalSteps = getCurrentSteps();
        if (stepsOffset == null) { stepsOffset = totalSteps; }
        var localSteps = totalSteps - stepsOffset;
        if (localSteps < 0) { localSteps = 0; }
        var paces = localSteps / 2;
        if (paces > 999) {
            stepsOffset = totalSteps;
            return 0;
        }
        return paces;
    }

    function onUpdate(dc) {
        dc.setColor(0x000000, 0x000000);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();

        var posStart  = [55, h / 3.4];
        var posPause  = [25, h / 3.4]; 
        var posResume = [65, h / 3.4];
        var posSave   = [55, h * 0.72];
        var posDisc   = [80, h * 0.72];
        var gpsSettings = [36, 18, 6, 12, 8, h - 35];
        
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
            distanceOffset = null; // Сброс метров при паузе
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

    function drawProgressArc(dc, w, h) {
        var total = controlPoints.size();
        if (total == 0) { return; }
        var cx = w / 2; var cy = h / 2;
        var radius = (w / 2) - 2; var thickness = 3; 
        dc.setPenWidth(thickness);
        dc.setColor(0x222222, -1);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 0, 360);
        var currentIdxFloat = (currentIndex + 1).toFloat();
        var totalFloat = total.toFloat();
        var ratio = currentIdxFloat / totalFloat;
        var sweepFloat = ratio * 360.0;
        var currentSweep = sweepFloat.toNumber();
        if (currentSweep > 0) {
            dc.setColor((currentIndex == total - 1) ? 0x00FF00 : 0xff5500, -1);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, 90 - currentSweep);
        }
    }

    function drawPacesCounter(dc, w, h, paces) {
        var margin = (w >= 280) ? pacesMarginEnduro : pacesMarginFenix;
        margin = margin + 5;
        var x = w - margin; 
        var y = (h / 2) - 12; // Сдвигаем шаги чуть выше середины
        var text = paces.toString(); 
        var font = Graphics.FONT_SMALL;
        dc.setColor(pacesColorOutline, -1);
        for (var dx = -2; dx <= 2; dx++) {
            for (var dy = -2; dy <= 2; dy++) {
                var adx = (dx < 0) ? -dx : dx;
                var ady = (dy < 0) ? -dy : dy;
                if (adx + ady != 0) { dc.drawText(x + dx, y + dy, font, text, 2|4); }
            }
        }
        dc.setColor(pacesColorMain, -1);
        dc.drawText(x, y, font, text, 2|4);
    }

    function drawMetersCounter(dc, w, h) {
        var info = Activity.getActivityInfo();
        var totalDist = (info != null && info.elapsedDistance != null) ? info.elapsedDistance : 0.0;
        if (distanceOffset == null) { distanceOffset = totalDist; }
        var localDist = totalDist - distanceOffset;
        if (localDist < 0) { localDist = 0; }
        if (localDist >= 1000.0) { distanceOffset = totalDist; localDist = 0; }

        var margin = (w >= 280) ? pacesMarginEnduro : pacesMarginFenix;
        margin = margin + 5;
        var x = w - margin;
        var y = (h / 2) + 12; // Сдвигаем метры чуть ниже середины
        var text = localDist.toNumber().toString();
        var font = Graphics.FONT_SMALL;

        dc.setColor(0x000000, -1);
        for (var dx = -2; dx <= 2; dx++) {
            for (var dy = -2; dy <= 2; dy++) {
                var adx = (dx < 0) ? -dx : dx;
                var ady = (dy < 0) ? -dy : dy;
                if (adx + ady != 0) { dc.drawText(x + dx, y + dy, font, text, 2|4); }
            }
        }
        dc.setColor(0xFFFFFF, -1); // Цвет метров: Оранжевый
        dc.drawText(x, y, font, text, 2|4);
    }

    function drawCompass(dc, info, w, h, pPause) {
        var paces = calculatePaces();
        var ringWidth = 30; var arrowW = 20; var arrowL = (w / 2) - 40; 
        var cx = w / 2; var cy = h / 2;
        var sInfo = Sensor.getInfo();
        var heading = (sInfo != null && sInfo.heading != null) ? sInfo.heading : ((info != null && info.currentHeading != null) ? info.currentHeading : lastHeading);
        lastHeading = heading;
        var sectorColors = [0xFF0000, 0xFFFF00, 0x00FF00, 0x000000, 0x0000FF, 0xFFFFFF, 0x00FFFF, 0xFFAA00, 0xAA00FF, 0xAAAAAA, 0x00AA00, 0xAA0000, 0x0000AA, 0x00aaff, 0xff5500, 0x550055];
        for (var i = 0; i < 16; i++) {
            dc.setColor(sectorColors[i], -1);
            var angleDeg = (i * 22.5).toFloat();
            dc.setPenWidth(ringWidth);
            dc.drawArc(cx, cy, (w/2)-(ringWidth/2), Graphics.ARC_CLOCKWISE, 90-angleDeg, 90-angleDeg-22.5);
            if (i % 2 != 0) {
                var charIndex = (i - 1) / 2; var textColor = 0x000000;
                if (i == 3) { textColor = 0xAAAAAA; } else if (i == 11 || i == 15) { textColor = 0xFFFFFF; }
                dc.setColor(textColor, -1);
                var midAngleRad = (90 - angleDeg - 11.25) * (Math.PI / 180.0);
                var dist = (w / 2.0) - (ringWidth / 2.0);
                dc.drawText(cx + dist * Math.cos(midAngleRad), cy - dist * Math.sin(midAngleRad), Graphics.FONT_TINY, (65 + charIndex).toChar().toString(), 1|4);
            }
        }
        var sAngle = -heading - (Math.PI / 2.0); 
        var cosA = Math.cos(sAngle); var sinA = Math.sin(sAngle);
        var cosOrth = Math.cos(sAngle + Math.PI / 2.0); var sinOrth = Math.sin(sAngle + Math.PI / 2.0);
        var p1 = [cx + cosOrth * (arrowW / 2), cy + sinOrth * (arrowW / 2)];
        var p2 = [cx - cosOrth * (arrowW / 2), cy - sinOrth * (arrowW / 2)];
        dc.setColor(0xFF0000, -1);
        dc.fillPolygon([p1, p2, [p2[0] + cosA * arrowL, p2[1] + sinA * arrowL], [p1[0] + cosA * arrowL, p1[1] + sinA * arrowL]]);
        dc.setColor(0xFFFFFF, -1); dc.setPenWidth(2);
        var p5 = [p2[0] - cosA * arrowL, p2[1] - sinA * arrowL];
        var p6 = [p1[0] - cosA * arrowL, p1[1] - sinA * arrowL];
        dc.drawLine(p1[0], p1[1], p6[0], p6[1]); dc.drawLine(p2[0], p2[1], p5[0], p5[1]); dc.drawLine(p5[0], p5[1], p6[0], p6[1]);
        
        drawPacesCounter(dc, w, h, paces);
        drawMetersCounter(dc, w, h);
        if (appState == 1) { drawPauseSymbol(dc, w, h, pPause); }
    }

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
        drawPacesCounter(dc, w, h, paces);
        drawMetersCounter(dc, w, h);
        drawGPSBottom(dc, info, w, gpsS);
        if (appState == 0) {
            dc.setColor(0x55AAFF, -1);
            dc.drawText(w - pStart[0]-15, pStart[1], Graphics.FONT_XTINY, "START>", 2);
        } else { drawPauseSymbol(dc, w, h, pPause); }
    }

    function drawIcons(dc, info, w, h, pPause) {
        var paces = calculatePaces();
        var midX = w / 2, midY = h / 2 + 10;
        if (controlPoints.size() == 0) { return; }
        var currentData = controlPoints[currentIndex];
        var orderNumStr = (currentIndex + 1).toString();
        var cpNumStr = currentData[0].toString();
        var t = (info != null && info.timerTime != null) ? info.timerTime : 0;
        var d = (info != null && info.elapsedDistance != null) ? info.elapsedDistance : 0;
        dc.setColor(0xAAAAAA, -1);
        dc.drawText(midX, h * 0.06, Graphics.FONT_XTINY, (d / 1000.0).format("%.2f") + " km", 1|4);
        dc.drawText(midX, h * 0.17, Graphics.FONT_LARGE, formatTime(t), 1|4);
        dc.setPenWidth(1); dc.drawLine(30, h * 0.24, w - 30, h * 0.24);
        
        drawPacesCounter(dc, w, h, paces);
        drawMetersCounter(dc, w, h);
        drawProgressArc(dc, w, h);

        var hasIcons = false;
        for (var i = 1; i <= 6; i++) { if (currentData.size() > i && currentData[i] != 0) { hasIcons = true; } }
        if (hasIcons) {
            var boxSize = 38, halfBox = 19, y_delta = 30; 
            var positions = [[midX + halfBox, midY - boxSize - halfBox + y_delta], [midX - boxSize - halfBox, midY - halfBox + y_delta], [midX - halfBox, midY - halfBox + y_delta], [midX + halfBox, midY - halfBox + y_delta], [midX - 2*halfBox, midY + halfBox+y_delta], [midX , midY + halfBox+y_delta]];
            for (var j = 0; j < 6; j++) {
                if (currentData.size() > j + 1 && currentData[j+1] != 0) {
                    var bx = positions[j][0], by = positions[j][1];
                    dc.setColor(0xAAAAAA, -1); 
                    dc.setPenWidth(1);
                    dc.drawRectangle(bx, by, boxSize, boxSize);

                    dc.setColor(0xFFFFFF, -1);
                    if (myFont != null) { dc.drawText(bx + halfBox, by + halfBox, myFont, (57345 + currentData[j+1]).toChar().toString(), 1|4); }
                }
            }
            var cpOffset = (w >= 280) ? cpOffsetEnduro : cpOffsetFenix;
            var finalCpX; var shiftCorr;
            if (w >= 280 && cpNumStr.length() > 2) {
                finalCpX = midX - cpOffset - 40; 
                shiftCorr = 105; 
            } else {
                finalCpX = midX - cpOffset;
                shiftCorr = (w >= 280) ? 40 : (cpNumStr.length() > 2 ? 21 : 10);
            }
            dc.setColor(0xFFFFFF, -1);
            dc.drawText(finalCpX, positions[0][1] + halfBox - 20, Graphics.FONT_NUMBER_HOT, cpNumStr, 2|4); 
            var cpWidth = dc.getTextWidthInPixels(cpNumStr, Graphics.FONT_NUMBER_HOT);
            dc.drawText(finalCpX - cpWidth + shiftCorr, positions[0][1] + halfBox - 4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);
        } else {
            dc.setColor(0xFFFFFF, -1);
            dc.drawText(midX, midY-19, Graphics.FONT_NUMBER_THAI_HOT, cpNumStr, 1|4);
            var bigCpWidth = dc.getTextWidthInPixels(cpNumStr, Graphics.FONT_NUMBER_THAI_HOT);
            dc.drawText(midX - (bigCpWidth / 2) - 40, midY-4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);
            if (currentIndex + 1 < controlPoints.size()) {
                dc.setColor(0xAAAAAA, -1); 
                dc.fillPolygon([[w/2 - 6, h/2 + 43], [w/2 + 6, h/2 + 43], [w/2, h/2 + 51]]);
                dc.drawText(midX, midY + 65, Graphics.FONT_NUMBER_MEDIUM, controlPoints[currentIndex + 1][0].toString(), 1|4);
            }
        }
        drawUIElements(dc, w, h, midX, midY, pPause);
    }

    // --- НАВИГАЦИЯ: БОЛЬШАЯ СТРЕЛКА ---
 // --- НАВИГАЦИЯ: БОЛЬШАЯ СТРЕЛКА С КОНТУРНЫМ ТЕКСТОМ ---
    function drawNavigation(dc, info, w, h, pPause, gpsS) {
        var cx = w / 2;
        var cy = h / 2;
        
        var curLoc = (info != null) ? info.currentLocation : null;
        
        // Получаем направление (куда смотрят часы)
        var sInfo = Sensor.getInfo();
        var heading = (sInfo != null && sInfo.heading != null) ? sInfo.heading : (info != null && info.currentHeading != null ? info.currentHeading : lastHeading);
        lastHeading = heading;

        var directDist = 0.0;
        var arrowAngle = 0.0;

        if (startLocation != null && curLoc != null) {
            var curDeg = curLoc.toDegrees();
            var stDeg = startLocation.toDegrees();

            // 1. Расстояние по прямой (Haversine formula)
            var lat1 = Math.toRadians(curDeg[0]);
            var lon1 = Math.toRadians(curDeg[1]);
            var lat2 = Math.toRadians(stDeg[0]);
            var lon2 = Math.toRadians(stDeg[1]);

            var dLat = lat2 - lat1;
            var dLon = lon2 - lon1;

            var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                    Math.cos(lat1) * Math.cos(lat2) *
                    Math.sin(dLon/2) * Math.sin(dLon/2);
            var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
            directDist = 6371.0 * c; // Дистанция в км

            // 2. Азимут на старт (Bearing)
            var yBearing = Math.sin(dLon) * Math.cos(lat2);
            var xBearing = Math.cos(lat1) * Math.sin(lat2) -
                           Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
            var bearing = Math.atan2(yBearing, xBearing);

            // Итоговый угол стрелки относительно верха экрана
            arrowAngle = bearing - heading;
        } else {
            // Тестовые данные для симулятора
            directDist = 1.45;
            arrowAngle = 0.0; // Будет смотреть вверх
        }

        // 3. Геометрия стрелки
        var padding = (w < 240) ? 12 : 8; 
        var rTip   = (w / 2) - padding;
        var rWings = (w / 2) - padding - 25; 
        var rInner = 35;
        var wingSpan = (w / 2) * 0.65; 

        // Коррекция для системы координат Garmin (0 радиан = право, идем по часовой)
        // Нам нужно 0 = Вверх, поэтому вычитаем PI/2
        var drawAngle = arrowAngle - (Math.PI / 2.0);

        var cosA = Math.cos(drawAngle);
        var sinA = Math.sin(drawAngle);
        var cosOrth = Math.cos(drawAngle + Math.PI/2.0);
        var sinOrth = Math.sin(drawAngle + Math.PI/2.0);

        // Координаты точек (с учетом Y-вниз в dc)
        var pTip   = [cx + rTip * cosA, cy + rTip * sinA]; 
        var pWingL = [cx - rWings * cosA + wingSpan * cosOrth, cy - rWings * sinA + wingSpan * sinOrth];
        var pInner = [cx - rInner * cosA, cy - rInner * sinA];
        var pWingR = [cx - rWings * cosA - wingSpan * cosOrth, cy - rWings * sinA - wingSpan * sinOrth];

        // 4. Отрисовка стрелки
        dc.setColor(0x00AAFF, -1);
        dc.fillPolygon([pTip, pWingL, pInner, pWingR]);
        
        dc.setColor(0xFFFFFF, -1);
        dc.setPenWidth(3);
        dc.drawLine(pTip[0], pTip[1], pWingL[0], pWingL[1]);
        dc.drawLine(pWingL[0], pWingL[1], pInner[0], pInner[1]);
        dc.drawLine(pInner[0], pInner[1], pWingR[0], pWingR[1]);
        dc.drawLine(pWingR[0], pWingR[1], pTip[0], pTip[1]);

        // 5. Текст с контуром
        var distStr = (directDist < 1.0) ? (directDist * 1000).format("%d") + " m" : directDist.format("%.2f") + " km";
        drawOutlineText(dc, cx, cy - 15, Graphics.FONT_XTINY, "BACK TO START", 0x000000, 0xFFFFFF);
        drawOutlineText(dc, cx, cy + 15, Graphics.FONT_MEDIUM, distStr, 0x000000, 0xFFFFFF);

        // 6. Доп. инфо
        drawGPSBottom(dc, info, w, gpsS);
        drawPacesCounter(dc, w, h, calculatePaces());
        drawMetersCounter(dc, w, h);
    }

    // Вспомогательная функция для чистоты кода
    function drawOutlineText(dc, x, y, font, text, outColor, mainColor) {
        dc.setColor(outColor, -1);
        for (var dx = -2; dx <= 2; dx++) {
            for (var dy = -2; dy <= 2; dy++) {
                if (dx*dx + dy*dy > 0) { dc.drawText(x + dx, y + dy, font, text, 1|4); }
            }
        }
        dc.setColor(mainColor, -1);
        dc.drawText(x, y, font, text, 1|4);
    }

    function drawGPSBottom(dc, info, w, s) {
        var acc = (info != null && info.currentLocationAccuracy != null) ? info.currentLocationAccuracy : 0;
        
        // Если точность 0 или 1 (поиск или нет сигнала) — не рисуем ничего
        if (acc <= 1) {
            return;
        }

        // Цвета: [0-не исп, 1-не исп, 2-желтый, 3-желтый, 4-зеленый]
        // Используем 0x00FF00 для зеленого и 0xFFFF00 для желтого
        var colors = [0x000000, 0x000000, 0xFFFF00, 0xFFFF00, 0x00FF00];
        
        var x = (w / 2) - (s[0] / 2);
        dc.setColor(colors[acc], -1);
        
        // Рисуем увеличенные столбики
        dc.fillRectangle(x, s[5] + (s[1] - s[4]), s[3], s[4]);
        dc.fillRectangle(x + s[3] + ((s[0] - (s[3]*2) - s[2])/2), s[5], s[2], s[1]);
        dc.fillRectangle(x + s[0] - s[3], s[5] + (s[1] - s[4]), s[3], s[4]);
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
        dc.setColor(0x55AAFF, -1);
        var dx = 8; dc.fillPolygon([[w*0.12-10+dx, midY+26], [w*0.12-16+dx, midY+35], [w*0.12-4+dx, midY+35]]);
        dc.fillPolygon([[w*0.12-5+dx, midY+55], [w*0.12-11+dx, midY+46], [w*0.12+1+dx, midY+46]]);
        dc.setPenWidth(2); dc.drawLine(w*0.88-15-dx, midY+55, w*0.88-5-dx, midY+65); dc.drawLine(w*0.88-15-dx, midY+65, w*0.88-5-dx, midY+55);
        if (appState == 1) { drawPauseSymbol(dc, w, h, pPause); }
    }

    function drawSplashScreen(dc, w, h) {
        dc.setColor(0xAAAAAA, -1); dc.drawText(w/2, h/2-75, Graphics.FONT_XTINY, "isom2024", 1|4);
        dc.setColor(0xFFFFFF, -1); dc.drawText(w/2, h/2-35, Graphics.FONT_LARGE, "LegendMaster", 1|4);
        dc.drawText(w/2, h/2, Graphics.FONT_SMALL, "by punishman", 1|4);
        dc.drawText(w/2, h/2+40, Graphics.FONT_XTINY, "Thanks to:", 1|4);
        dc.drawText(w/2, h/2+55, Graphics.FONT_XTINY, "laura coach Ann10_08 killkost", 1|4);
        dc.drawText(w/2, h/2+75, Graphics.FONT_XTINY, "michailova22", 1|4);
    }

    function formatTime(ms) {
        var totalSeconds = ms / 1000;
        var h = totalSeconds / 3600;
        var m = (totalSeconds / 60) % 60, s = totalSeconds % 60;
        return (h > 0) ? h.format("%d") + ":" + m.format("%02d") + ":" + s.format("%02d") : m.format("%02d") + ":" + s.format("%02d");
    }

    function loadSettings() {
        controlPoints = [[31, 11, 12, 13, 14, 15, 16], [131, 11, 12, 13, 14, 15, 16], [100, 0, 0, 0, 0, 0, 0], [32, 0, 0, 0, 0, 0, 0], [32, 0, 0, 0, 0, 0, 0], [32, 0, 0, 0, 0, 0, 0]];
    }

    function changePage(dir) {
        var newID = pageID + dir;
        if (newID >= -2 && newID <= 1) { 
            pageID = newID; 
            stepsOffset = null; 
            distanceOffset = null; // Сброс метров при смене страницы
            WatchUi.requestUpdate(); 
        }
    }

    function scrollIcons(step) {
        currentIndex += step;
        if (currentIndex < 0) { currentIndex = 0; }
        if (currentIndex >= controlPoints.size()) { currentIndex = controlPoints.size() - 1; }
        WatchUi.requestUpdate();
    }
}