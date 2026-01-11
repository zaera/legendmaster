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

    var msgTimer = 0; // Таймер для сообщения

    var pacesColorMain    = 0x000000; 
    var pacesColorOutline = 0xffffff; 
    // =======================================

    // === ПЕРЕМЕННЫЕ СПУФИНГА ===
    var isSpoofing = false;
    var lastValidLoc = null;
    var autoTestCounter = 0; // Счетчик тиков таймера
    // ===========================

    var myFont1; 
    var myFont2; 
    var pageID = 0; 
    var currentIndex = 0;
    var launchTime;
    var appState = 0; 
    var controlPoints = []; 
    var updateTimer; 
    var startLocation = null;
    var lastHeading = 0.0;
    var stepsOffset = null;
    var distanceOffset = null; 

    function resetSpoof() {
        isSpoofing = false;
        lastValidLoc = null;
        WatchUi.requestUpdate();
    }

    function startSession() {
        if (appState == 0) {
            appState = 1;
            WatchUi.requestUpdate();
        }
    }

    function exitApp() {
        System.exit();
    }

    function initialize() { 
        View.initialize(); 
        launchTime = System.getTimer();
        stepsOffset = getCurrentSteps(); 
        loadSettings(); 
        
        if (Sensor has :setEnabledSensors) {
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        }
        
        updateTimer = new Timer.Timer();
        updateTimer.start(method(:onTimerUpdate), 250, true);

        if (Sensor has :registerSensorDataListener) {
            try {
                Sensor.registerSensorDataListener(method(:onSensor), { :period => 1 });
            } catch(ex) {
                System.println("Sensor listener not supported");
            }
        }
    }

    function onSensor(sensorData as Toybox.Sensor.SensorData) as Void {
        // Оставляем пустым, это нужно только для поддержания активности сенсоров
    }

    function onLayout(dc) { 
        try { 
            myFont1 = WatchUi.loadResource(Rez.Fonts.LegendFont1); 
            myFont2 = WatchUi.loadResource(Rez.Fonts.LegendFont2); 
        } catch(ex) { 
            myFont1 = null; 
            myFont2 = null; 
        }
    }

    function onTimerUpdate() as Void { 
        WatchUi.requestUpdate(); 
    }

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

        var posStart    = [55, h / 3.4];
        var posPause    = [25, h / 3.4]; 
        var posResume   = [65, h / 3.4];
        var posSave     = [55, h * 0.72];
        var posDisc     = [80, h * 0.72];
        var gpsSettings = [36, 18, 6, 12, 8, h - 35];
        
        var settings = System.getDeviceSettings();
        var hasTouch = (settings has :isTouchScreen) ? settings.isTouchScreen : false;

        if (msgTimer > 0) {
            msgTimer--; 
            var rectW = 200; var rectH = 80;
            var rectX = (w - rectW) / 2; var rectY = (h - rectH) / 2;
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.fillRectangle(rectX, rectY, rectW, rectH);
            dc.setColor(0x00FF00, -1); 
            dc.setPenWidth(4);
            dc.drawRectangle(rectX, rectY, rectW, rectH);
            dc.drawText(w/2, h/2, Graphics.FONT_MEDIUM, "Data received!", 1|4);
            return; 
        }

        var info = Activity.getActivityInfo();
        if (appState == 1 && info != null && info.currentLocation != null) {
            var curLoc = info.currentLocation.toDegrees();
            if (lastValidLoc == null) { lastValidLoc = curLoc; } 
            else {
                var dLat = curLoc[0] - lastValidLoc[0];
                var dLon = curLoc[1] - lastValidLoc[1];
                var distSq = dLat*dLat + dLon*dLon;
                if (!isSpoofing && (distSq > 0.04 || (info.currentSpeed != null && info.currentSpeed > 16.6))) {
                    isSpoofing = true;
                } else if (isSpoofing && distSq < 0.04) {
                    isSpoofing = false;
                }
                if (!isSpoofing) { lastValidLoc = curLoc; }
            }
        } else if (appState == 0) {
            lastValidLoc = null;
        }

        if (System.getTimer() - launchTime < 2000) { 
            drawSplashScreen(dc, w, h); 
            return; 
        }

        if (appState == 1 && startLocation == null && info.currentLocation != null) {
            startLocation = info.currentLocation;
        }

        if (appState == 2) { 
            stepsOffset = null; distanceOffset = null; 
            drawPauseMenu(dc, info, w, h, posResume, posSave, posDisc); 
        } else if (pageID == -2) { 
            drawNavigation(dc, info, w, h, posPause, gpsSettings); 
        } else if (pageID == -1) { 
            drawCompass(dc, info, w, h, posPause); 
        } else if (pageID == 0) { 
            drawMain(dc, info, w, h, posStart, posPause, gpsSettings, hasTouch); 
        } else if (pageID == 1) { 
            drawIcons(dc, info, w, h, posPause); 
        }
    }

    function onDataReceived(newData) {
        controlPoints = newData;
        currentIndex = 0; 
        msgTimer = 8; 
        WatchUi.requestUpdate();
    }

    function drawProgressArc(dc, w, h) {
        var total = controlPoints.size();
        if (total == 0) { return; }
        var displayTotal = (total > 99) ? 99 : total;
        
        var cx = w / 2; var cy = h / 2;
        var radius = (w / 2) - 2; var thickness = 3; 
        dc.setPenWidth(thickness);
        dc.setColor(0x222222, -1);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 0, 360);
        
        var currentIdxFloat = (currentIndex + 1).toFloat();
        var totalFloat = displayTotal.toFloat();
        var ratio = currentIdxFloat / totalFloat;
        var sweepFloat = ratio * 360.0;
        var currentSweep = sweepFloat.toNumber();
        if (currentSweep > 0) {
            dc.setColor((currentIndex == displayTotal - 1) ? 0x00FF00 : 0xff5500, -1);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, 90 - currentSweep);
        }
    }

    function drawPacesCounter(dc, w, h, paces) {
        var margin = (w >= 280) ? pacesMarginEnduro : pacesMarginFenix;
        margin = margin + 5;
        var x = w - margin; 
        var y = (h / 2) - 12; 
        
        var text = isSpoofing ? "SPO" : paces.toString(); 
        
        var font = Graphics.FONT_SMALL;
        dc.setColor(pacesColorOutline, -1);
        for (var dx = -2; dx <= 2; dx++) {
            for (var dy = -2; dy <= 2; dy++) {
                var adx = (dx < 0) ? -dx : dx;
                var ady = (dy < 0) ? -dy : dy;
                if (adx + ady != 0) { dc.drawText(x + dx, y + dy, font, text, 2|4); }
            }
        }
        dc.setColor(isSpoofing ? 0xFF0000 : pacesColorMain, -1);
        dc.drawText(x, y, font, text, 2|4);
    }

    function drawMetersCounter(dc, w, h) {
        if (appState == 0) { 
            distanceOffset = null; 
            return; 
        }
        var info = Activity.getActivityInfo();
        var totalDist = (info != null && info.elapsedDistance != null) ? info.elapsedDistance : 0.0;
        if (distanceOffset == null) { distanceOffset = totalDist; }
        var localDist = totalDist - distanceOffset;
        if (localDist < 0) { localDist = 0; }
        if (localDist >= 1000.0) { distanceOffset = totalDist; localDist = 0; }

        var margin = (w >= 280) ? pacesMarginEnduro : pacesMarginFenix;
        margin = margin + 5;
        var x = w - margin;
        var y = (h / 2) + 12; 
        
        var text = isSpoofing ? "OF!" : localDist.toNumber().toString();
        
        var font = Graphics.FONT_SMALL;

        dc.setColor(isSpoofing ? 0xFFFFFF : 0x000000, -1);
        for (var dx = -2; dx <= 2; dx++) {
            for (var dy = -2; dy <= 2; dy++) {
                var adx = (dx < 0) ? -dx : dx;
                var ady = (dy < 0) ? -dy : dy;
                if (adx + ady != 0) { dc.drawText(x + dx, y + dy, font, text, 2|4); }
            }
        }

        dc.setColor(isSpoofing ? 0xFF0000 : 0xFFFFFF, -1); 
        dc.drawText(x, y, font, text, 2|4);
    }

    function drawCompass(dc, info, w, h, pPause) {
        var paces = calculatePaces();
        var ringWidth = 30; 
        var arrowW = 20; 
        var arrowL = (w / 2) - 40; 
        var cx = w / 2; 
        var cy = h / 2;
        
        var curHeading = null;
        var sInfo = Sensor.getInfo();

        if (sInfo != null && sInfo has :heading && sInfo.heading != null) {
            curHeading = sInfo.heading;
        } 
        else if (info != null && info has :currentHeading && info.currentHeading != null) {
            curHeading = info.currentHeading;
        }

        if (curHeading != null) {
            lastHeading = curHeading;
        }
        var heading = lastHeading;

        var sectorColors = [0xFF0000, 0xFFFF00, 0x00FF00, 0x000000, 0x0000FF, 0xFFFFFF, 0x00FFFF, 0xFFAA00, 0xAA00FF, 0xAAAAAA, 0x00AA00, 0xAA0000, 0x0000AA, 0x00aaff, 0xff5500, 0x550055];
        
        for (var i = 0; i < 16; i++) {
            dc.setColor(sectorColors[i], -1);
            var angleDeg = (i * 22.5).toFloat();
            dc.setPenWidth(ringWidth);
            dc.drawArc(cx, cy, (w/2)-(ringWidth/2), Graphics.ARC_CLOCKWISE, 90-angleDeg, 90-angleDeg-22.5);
            
            if (i % 2 != 0) {
                var charIndex = (i - 1) / 2; 
                var textColor = 0x000000;
                if (i == 3) { textColor = 0xAAAAAA; } 
                else if (i == 11 || i == 15) { textColor = 0xFFFFFF; }
                
                dc.setColor(textColor, -1);
                var midAngleRad = (90 - angleDeg - 11.25) * (Math.PI / 180.0);
                var dist = (w / 2.0) - (ringWidth / 2.0);
                dc.drawText(cx + dist * Math.cos(midAngleRad), cy - dist * Math.sin(midAngleRad), Graphics.FONT_TINY, (65 + charIndex).toChar().toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        var sAngle = -heading - (Math.PI / 2.0); 
        var cosA = Math.cos(sAngle); 
        var sinA = Math.sin(sAngle);
        var cosOrth = Math.cos(sAngle + Math.PI / 2.0); 
        var sinOrth = Math.sin(sAngle + Math.PI / 2.0);

        var p1 = [cx + cosOrth * (arrowW / 2), cy + sinOrth * (arrowW / 2)];
        var p2 = [cx - cosOrth * (arrowW / 2), cy - sinOrth * (arrowW / 2)];
        var p3 = [p2[0] + cosA * arrowL, p2[1] + sinA * arrowL];
        var p4 = [p1[0] + cosA * arrowL, p1[1] + sinA * arrowL];

        dc.setColor(0xFF0000, -1);
        dc.fillPolygon([p1, p2, p3, p4]);

        dc.setColor(0xFFFFFF, -1); 
        dc.setPenWidth(2);
        var p5 = [p2[0] - cosA * arrowL, p2[1] - sinA * arrowL];
        var p6 = [p1[0] - cosA * arrowL, p1[1] - sinA * arrowL];
        
        dc.drawLine(p1[0], p1[1], p6[0], p6[1]); 
        dc.drawLine(p2[0], p2[1], p5[0], p5[1]); 
        dc.drawLine(p5[0], p5[1], p6[0], p6[1]);
        
        drawPacesCounter(dc, w, h, paces);
        drawMetersCounter(dc, w, h);
    }

    function drawMain(dc, info, w, h, pStart, pPause, gpsS, hasTouch) {
        var paces = calculatePaces();
        var txtColor = isSpoofing ? 0xFF0000 : 0xFFFFFF;
        var t = (info != null && info.timerTime != null) ? info.timerTime : 0;
        var d = (info != null && info.elapsedDistance != null) ? info.elapsedDistance : 0;
        var hr = (info != null && info.currentHeartRate != null) ? info.currentHeartRate : "--";
        
        dc.setColor(0xFF5555, -1);
        var hrY = h/2 - 95; 
        dc.fillCircle(w/2 - 6, hrY, 5); dc.fillCircle(w/2 + 2, hrY, 5);
        dc.fillPolygon([[w/2 - 11, hrY + 2], [w/2 + 7, hrY + 2], [w/2 - 2, hrY + 12]]);
        
        dc.setColor(txtColor, -1);
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
            
            if (hasTouch) {
                dc.setPenWidth(2);
                var midY = h / 2 + 10;
                var centerX = w * 0.88 - 18; var centerY = midY + 60;
                dc.drawLine(centerX - 5, centerY - 5, centerX + 5, centerY + 5);
                dc.drawLine(centerX - 5, centerY + 5, centerX + 5, centerY - 5);
            }
        } else { 
            drawPauseSymbol(dc, w, h, pPause); 
        }
    }

    function drawIcons(dc, info, w, h, pPause) {
        var paces = calculatePaces();
        var midX = w / 2, midY = h / 2 + 10;
        if (controlPoints.size() == 0) { return; }
        
        var currentData = controlPoints[currentIndex];
        var displayIdx = currentIndex + 1;
        if (displayIdx > 99) { displayIdx = 99; }
        var orderNumStr = displayIdx.toString() + ".";
        var cpNumStr = currentData[0].toString();
        
        var t = (info != null && info.timerTime != null) ? info.timerTime : 0;
        var d = (info != null && info.elapsedDistance != null) ? info.elapsedDistance : 0;
        var txtColor = isSpoofing ? 0xFF0000 : 0xFFFFFF;

        // 1. Верхняя панель инфо
        dc.setColor(0xAAAAAA, -1);
        dc.drawText(midX, h * 0.06, Graphics.FONT_XTINY, (d / 1000.0).format("%.2f") + " km", 1|4);
        dc.setColor(txtColor, -1); 
        dc.drawText(midX, h * 0.17, Graphics.FONT_LARGE, formatTime(t), 1|4);
        dc.setPenWidth(1); dc.drawLine(30, h * 0.24, w - 30, h * 0.24);
        
        drawPacesCounter(dc, w, h, paces);
        drawMetersCounter(dc, w, h);
        drawProgressArc(dc, w, h);

        // Проверка наличия контента в ячейках
        var hasContent = false;
        for (var i = 1; i <= 6; i++) { 
            // ИЗМЕНЕНО: Проверка только на null, чтобы 0 был валидным
            if (currentData.size() > i && currentData[i] != null) { 
                hasContent = true; 
                break; 
            } 
        }

        if (hasContent) {
            var boxSize = 38, halfBox = 19, y_delta = 30; 
            var positions = [[midX + halfBox, midY - boxSize - halfBox + y_delta], [midX - boxSize - halfBox, midY - halfBox + y_delta], [midX - halfBox, midY - halfBox + y_delta], [midX + halfBox, midY - halfBox + y_delta], [midX - 2*halfBox, midY + halfBox + y_delta], [midX, midY + halfBox + y_delta]];

            for (var j = 0; j < 6; j++) {
                // ИЗМЕНЕНО: Если данных нет в массиве, считаем это null
                var item = (currentData.size() > j + 1) ? currentData[j+1] : null;
                
                // ИЗМЕНЕНО: Теперь 0 проходит проверку, а null - нет
                if (item != null) {
                    var bx = positions[j][0], by = positions[j][1];
                    dc.setColor(0xAAAAAA, -1); 
                    dc.setPenWidth(1);
                    dc.drawRectangle(bx, by, boxSize, boxSize);
                    dc.setColor(txtColor, -1);

                    // Безопасная проверка типа для старых часов
                    if (item instanceof Toybox.Lang.Number) {
                        var fontToUse = (item < 90) ? myFont1 : myFont2;
                        var finalID = (item < 90) ? (33 + item) : (33 + (item - 90));
                        if (fontToUse != null) {
                            dc.drawText(bx + halfBox, by + halfBox, fontToUse, finalID.toChar().toString(), 1|4);
                        }
                    } else {
                        // Если строка, берем первый символ безопасно
                        var s = item.toString();
                        if (s.length() > 0) {
                            dc.drawText(bx + halfBox, by + halfBox, Graphics.FONT_LARGE, s.substring(0, 1), 1|4);
                        }
                    }
                }
            }

            dc.setColor(txtColor, -1);
            var topBoxX = positions[0][0];
            var vCenterY = positions[0][1] + halfBox - 4;
            var cpAnchorX = topBoxX - 20;

            dc.drawText(cpAnchorX, vCenterY - 16, Graphics.FONT_NUMBER_HOT, cpNumStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(topBoxX + 25, vCenterY - 35, Graphics.FONT_LARGE, orderNumStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        } else {
            // --- СЦЕНАРИЙ 2: НЕТ ИКОНОК (ПО ЦЕНТРУ) ---
            dc.setColor(txtColor, -1);
            dc.drawText(midX, midY - 19, Graphics.FONT_NUMBER_THAI_HOT, cpNumStr, 1|4);
            
            var wBigCP = dc.getTextWidthInPixels(cpNumStr, Graphics.FONT_NUMBER_THAI_HOT);
            var orderX = midX - (wBigCP / 2) - 12;
            dc.drawText(orderX, midY - 4, Graphics.FONT_LARGE, orderNumStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

            if (currentIndex + 1 < controlPoints.size()) {
                dc.setColor(0xAAAAAA, -1); 
                var polyY = (w <= 218) ? midY + 33 : midY + 38;
                dc.fillPolygon([[midX - 6, polyY], [midX + 6, polyY], [midX, polyY + 11]]);
                
                var nextCpStr = controlPoints[currentIndex + 1][0].toString();
                dc.drawText(midX, (w <= 218) ? midY + 68 : midY + 85, Graphics.FONT_NUMBER_MEDIUM, nextCpStr, 1|4);
            }
        }
        drawUIElements(dc, w, h, midX, midY, pPause);
    }

    function drawNavigation(dc, info, w, h, pPause, gpsS) {
        var cx = w / 2; var cy = h / 2;
        var curLoc = (info != null) ? info.currentLocation : null;
        var sInfo = Sensor.getInfo();
        var heading = (sInfo != null && sInfo has :heading && sInfo.heading != null) ? sInfo.heading : (info != null && info has :currentHeading && info.currentHeading != null ? info.currentHeading : lastHeading);
        lastHeading = heading;
        
        var directDist = 0.0; var arrowAngle = 0.0;
        if (startLocation != null && curLoc != null) {
            var curD = curLoc.toDegrees(); var stD = startLocation.toDegrees();
            var lat1 = Math.toRadians(curD[0]); var lon1 = Math.toRadians(curD[1]);
            var lat2 = Math.toRadians(stD[0]); var lon2 = Math.toRadians(stD[1]);
            var dLat = lat2 - lat1; var dLon = lon2 - lon1;
            var a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon/2) * Math.sin(dLon/2);
            directDist = 6371.0 * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)));
            arrowAngle = Math.atan2(Math.sin(dLon) * Math.cos(lat2), Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon)) - heading;
        }
        
        var drawA = arrowAngle - (Math.PI / 2.0);
        var cosA = Math.cos(drawA); var sinA = Math.sin(drawA);
        var cosO = Math.cos(drawA + Math.PI/2.0); var sinO = Math.sin(drawA + Math.PI/2.0);
        var rTip = (w/2)-8; var rIn = 35; var span = (w/2)*0.65;
        
        dc.setColor(0x00AAFF, -1);
        dc.fillPolygon([[cx + rTip*cosA, cy + rTip*sinA], [cx - (rTip-25)*cosA + span*cosO, cy - (rTip-25)*sinA + span*sinO], [cx - rIn*cosA, cy - rIn*sinA], [cx - (rTip-25)*cosA - span*cosO, cy - (rTip-25)*sinA - span*sinO]]);
        
        var txtColor = isSpoofing ? 0xFF0000 : 0xFFFFFF;
        var distS = isSpoofing ? "GPS ERROR" : ((directDist < 1.0) ? (directDist * 1000).format("%d") + " m" : directDist.format("%.2f") + " km");
        
        drawOutlineText(dc, cx, cy - 15, Graphics.FONT_XTINY, "BACK TO START", 0x000000, txtColor);
        drawOutlineText(dc, cx, cy + 15, Graphics.FONT_MEDIUM, distS, 0x000000, txtColor);

        // --- КООРДИНАТЫ С ЧЕРНОЙ ОКАНТОВКОЙ (ДЛЯ ЧИТАЕМОСТИ) ---
        if (info != null && info.currentLocation != null) {
            var loc = info.currentLocation.toDegrees();
            var latStr = loc[0].format("%.5f");
            var lonStr = loc[1].format("%.5f");
            
            // Используем серый или белый цвет для самих цифр, а черный для контура
            var coordColor = 0xAAAAAA; 
            drawOutlineText(dc, cx, cy + 42, Graphics.FONT_XTINY, latStr, 0x000000, coordColor);
            drawOutlineText(dc, cx, cy + 60, Graphics.FONT_XTINY, lonStr, 0x000000, coordColor);
        }

        drawGPSBottom(dc, info, w, gpsS);
        drawPacesCounter(dc, w, h, calculatePaces());
        drawMetersCounter(dc, w, h);
    }

    function drawOutlineText(dc, x, y, font, text, outColor, mainColor) {
        dc.setColor(outColor, -1);
        for (var dx = -2; dx <= 2; dx++) { for (var dy = -2; dy <= 2; dy++) { if (dx*dx+dy*dy>0) { dc.drawText(x+dx, y+dy, font, text, 1|4); } } }
        dc.setColor(mainColor, -1); dc.drawText(x, y, font, text, 1|4);
    }

    function drawGPSBottom(dc, info, w, s) {
        var acc = (info != null && info.currentLocationAccuracy != null) ? info.currentLocationAccuracy : 0;
        if (acc <= 1) { return; }
        dc.setColor([0x000000, 0x000000, 0xFFFF00, 0xFFFF00, 0x00FF00][acc], -1);
        var x = (w / 2) - (s[0] / 2);
        dc.fillRectangle(x, s[5] + (s[1] - s[4]), s[3], s[4]);
        dc.fillRectangle(x + s[3] + ((s[0] - (s[3]*2) - s[2])/2), s[5], s[2], s[1]);
        dc.fillRectangle(x + s[0] - s[3], s[5] + (s[1] - s[4]), s[3], s[4]);
    }

function drawPauseMenu(dc, info, w, h, pRes, pSave, pDisc) {
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2, h * 0.1, Graphics.FONT_SMALL, "PAUSED", 1);
        dc.drawText(w/2, h/2 - (h * 0.13), Graphics.FONT_NUMBER_HOT, formatTime((info != null && info.timerTime != null) ? info.timerTime : 0), 1);
        
        // Правые кнопки
        dc.setColor(0x00FF00, -1); dc.drawText(w - pRes[0]-10, pRes[1], Graphics.FONT_XTINY, "RESUME", 2);
        dc.setColor(0xFF5555, -1); dc.drawText(w - pSave[0]-10, pSave[1], Graphics.FONT_XTINY, "SAVE", 2);

        // Левая верхняя (Discard)
        dc.setColor(0xAAAAAA, -1); dc.drawText(pDisc[0]+10, pDisc[1], Graphics.FONT_XTINY, "DISCARD", 0);
        
        // --- ЛОГИКА RESET SPOOF С ИНДИКАТОРОМ КНОПКИ ---
        var textX = pDisc[0] + 15; // Чуть больше отступ для линии
        var textY = h / 2 - 40;
        var buttonY = h / 2;      // Уровень средней кнопки
        
        dc.setColor(0xFFAA00, -1); 
        
        // 1. Рисуем жирную точку прямо напротив средней кнопки
        // (x=5 для XP3, чтобы была у самого края)
        dc.fillCircle(8, buttonY, 4); 

        // 2. Рисуем соединительную линию от точки вверх до надписи
        dc.setPenWidth(2);
        dc.drawLine(8, buttonY, 8, textY);     // Вертикальная линия
        dc.drawLine(8, textY, textX - 5, textY); // Короткая горизонтальная к тексту
        dc.setPenWidth(1);

        // 3. Сама надпись
        dc.drawText(textX, textY, Graphics.FONT_XTINY, "RESET\nSPOOF", 0 | 4);
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
        dc.drawText(w/2, h/2+55, Graphics.FONT_XTINY, "laura coach", 1|4);
        dc.drawText(w/2, h/2+75, Graphics.FONT_XTINY, "Ann10_08 killkost", 1|4);
        dc.drawText(w/2, h/2+95, Graphics.FONT_XTINY, "michailova22", 1|4);
    }

    function formatTime(ms) {
        var totalSeconds = ms / 1000;
        var h = totalSeconds / 3600;
        var m = (totalSeconds / 60) % 60, s = totalSeconds % 60;
        return (h > 0) ? h.format("%d") + ":" + m.format("%02d") + ":" + s.format("%02d") : m.format("%02d") + ":" + s.format("%02d");
    }

    function loadSettings() {
        var data = Application.getApp().getProperty("cp_data");
        if (data != null && data instanceof Toybox.Lang.Array) {
            controlPoints = data;
        } else {
            controlPoints = [[31, 0, 56, null, 95, 109, null]];
        }
    }

    function changePage(dir) {
        var newID = pageID + dir;
        if (newID >= -2 && newID <= 1) { 
            pageID = newID; 
            stepsOffset = null; 
            distanceOffset = null; 
            WatchUi.requestUpdate(); 
        }
    }

    function scrollIcons(step) {
        var newIdx = currentIndex + step;
        var maxIdx = controlPoints.size() - 1;
        if (maxIdx > 98) { maxIdx = 98; }
        if (newIdx < 0) { newIdx = 0; }
        if (newIdx > maxIdx) { newIdx = maxIdx; }
        currentIndex = newIdx;
        WatchUi.requestUpdate();
    }
}