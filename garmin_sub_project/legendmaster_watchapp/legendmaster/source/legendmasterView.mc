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
    var updateTimer as Timer.Timer?;
    var startLocation = null;
    var lastHeading = 0.0;
    var stepsOffset = null;
    var distanceOffset = null; 

    function initialize() { 
        View.initialize(); 
        launchTime = System.getTimer();
        stepsOffset = getCurrentSteps(); 
        loadSettings(); 
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        updateTimer = new Timer.Timer();
        updateTimer.start(method(:onTimerUpdate), 250, true);
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

// function onDataReceived(newData) {
//     controlPoints = newData; // Обновляем данные в памяти
//     msgTimer = 8; // Ставим таймер (если экран обновляется 4 раза в сек, это 2 секунды)
//     WatchUi.requestUpdate(); // Заставляем экран перерисоваться
// }

function onTimerUpdate() as Void { 
        // Мы оставляем только запрос на обновление экрана (4 раза в секунду),
        // чтобы навигация и время обновлялись плавно.
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
        // Базовая очистка экрана
        dc.setColor(0x000000, 0x000000);
        dc.clear();
        
        var w = dc.getWidth();
        var h = dc.getHeight();

        // --- ЛОГИКА УВЕДОМЛЕНИЯ О ПРИЕМЕ ДАННЫХ ---
        if (msgTimer > 0) {
            msgTimer--; 
            
            var rectW = 200; // Ширина рамки
            var rectH = 80;  // Высота рамки
            var rectX = (w - rectW) / 2;
            var rectY = (h - rectH) / 2;

            // Рисуем черный фон подложки
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.fillRectangle(rectX, rectY, rectW, rectH);

            // Рисуем зеленую рамку
            dc.setColor(0x00FF00, -1); 
            dc.setPenWidth(4); // Жирная рамка
            dc.drawRectangle(rectX, rectY, rectW, rectH);

            // Рисуем текст
            dc.drawText(w/2, h/2, Graphics.FONT_MEDIUM, "Data received!", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            
            return; 
        }

        // --- ЛОГИКА ОПРЕДЕЛЕНИЯ СПУФА ---
        var info = Activity.getActivityInfo();
        if (appState == 1 && info != null && info.currentLocation != null) {
            var curLoc = info.currentLocation.toDegrees();
            if (lastValidLoc == null) {
                lastValidLoc = curLoc;
            } else {
                var dLat = curLoc[0] - lastValidLoc[0];
                var dLon = curLoc[1] - lastValidLoc[1];
                var distSq = dLat*dLat + dLon*dLon;
                
                if (!isSpoofing && (distSq > 0.04 || (info.currentSpeed != null && info.currentSpeed > 16.6))) {
                    isSpoofing = true;
                } else if (isSpoofing && distSq < 0.04) {
                    isSpoofing = false;
                }
                
                if (!isSpoofing) { 
                    lastValidLoc = curLoc; 
                }
            }
        } else if (appState == 0) {
            lastValidLoc = null;
        }

        // Твои координаты элементов интерфейса
        var posStart    = [55, h / 3.4];
        var posPause    = [25, h / 3.4]; 
        var posResume   = [65, h / 3.4];
        var posSave     = [55, h * 0.72];
        var posDisc     = [80, h * 0.72];
        var gpsSettings = [36, 18, 6, 12, 8, h - 35];
        
        // Сплэш-скрин при запуске (2 секунды)
        if (System.getTimer() - launchTime < 2000) { 
            drawSplashScreen(dc, w, h); 
            return; 
        }

        // Фиксация точки старта
        if (appState == 1 && startLocation == null && info.currentLocation != null) {
            startLocation = info.currentLocation;
        }

        // Отрисовка экранов
        if (appState == 2) { 
            stepsOffset = null; 
            distanceOffset = null; 
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

    // Добавь также этот метод внутрь класса View
    function onDataReceived(newData) {
        controlPoints = newData;
        currentIndex = 0; // Сбрасываем на первое КП
        msgTimer = 8;     // 8 тиков по 250мс = 2 секунды
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
        
        // --- ЛОГИКА ТЕКСТА ПРИ СПУФЕ ---
        var text = isSpoofing ? "SPO" : paces.toString(); 
        // ------------------------------
        
        var font = Graphics.FONT_SMALL;
        dc.setColor(pacesColorOutline, -1);
        for (var dx = -2; dx <= 2; dx++) {
            for (var dy = -2; dy <= 2; dy++) {
                var adx = (dx < 0) ? -dx : dx;
                var ady = (dy < 0) ? -dy : dy;
                if (adx + ady != 0) { dc.drawText(x + dx, y + dy, font, text, 2|4); }
            }
        }
        // Если спуф - красим основной текст в красный
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
        
        // --- ЛОГИКА ТЕКСТА ПРИ СПУФЕ ---
        var text = isSpoofing ? "OF!" : localDist.toNumber().toString();
        // ------------------------------
        
        var font = Graphics.FONT_SMALL;

        // РИСУЕМ КОНТУР (КАНТ)
        // Если спуф — кант белый (как у SPO), если нет — кант черный
        dc.setColor(isSpoofing ? 0xFFFFFF : 0x000000, -1);
        for (var dx = -2; dx <= 2; dx++) {
            for (var dy = -2; dy <= 2; dy++) {
                var adx = (dx < 0) ? -dx : dx;
                var ady = (dy < 0) ? -dy : dy;
                if (adx + ady != 0) { dc.drawText(x + dx, y + dy, font, text, 2|4); }
            }
        }

        // РИСУЕМ ОСНОВНОЙ ТЕКСТ (ЦЕНТР)
        // Если спуф — красный центр, если нет — белый метраж
        dc.setColor(isSpoofing ? 0xFF0000 : 0xFFFFFF, -1); 
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
        // Покраснение текста (время и дистанция)
        var txtColor = isSpoofing ? 0xFF0000 : 0xFFFFFF;
        dc.setColor(txtColor, -1);
        
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
        } else { drawPauseSymbol(dc, w, h, pPause); }

        // РИСУЕМ СИНИЙ КРЕСТИК ВЫХОДА
        // РИСУЕМ КРЕСТИК ВЫХОДА (КОПИЯ С ЭКРАНА ИКОНОК)
        if (appState == 0) {
            dc.setColor(0x55AAFF, -1);
            dc.setPenWidth(2);
            var midY = h / 2 + 10;
            var dx = 8; 
            // Рисуем крестик точно по твоим координатам из drawUIElements
            var centerX = w * 0.88 - 10 - dx;
            var centerY = midY + 60;
            var sz = 5; // Размер плеча крестика

            dc.drawLine(centerX - sz, centerY - sz, centerX + sz, centerY + sz);
            dc.drawLine(centerX - sz, centerY + sz, centerX + sz, centerY - sz);
        }
    }

    function drawIcons(dc, info, w, h, pPause) {
    var paces = calculatePaces();
    var midX = w / 2, midY = h / 2 + 10;
    if (controlPoints.size() == 0) { return; }
    
    var currentData = controlPoints[currentIndex];
    
    // ПРЕДОХРАНИТЕЛЬ: порядковый номер не может быть > 99
    var displayIdx = currentIndex + 1;
    if (displayIdx > 99) { displayIdx = 99; }
    var orderNumStr = displayIdx.toString();
    
    var cpNumStr = currentData[0].toString();
    
    var t = (info != null && info.timerTime != null) ? info.timerTime : 0;
    var d = (info != null && info.elapsedDistance != null) ? info.elapsedDistance : 0;
    
    // Цвет текста меняется на красный только при спуфинге
    var txtColor = isSpoofing ? 0xFF0000 : 0xFFFFFF;

    // Верхняя панель инфо
    dc.setColor(0xAAAAAA, -1);
    dc.drawText(midX, h * 0.06, Graphics.FONT_XTINY, (d / 1000.0).format("%.2f") + " km", 1|4);
    dc.setColor(txtColor, -1); // Краснеет при спуфе
    dc.drawText(midX, h * 0.17, Graphics.FONT_LARGE, formatTime(t), 1|4);
    dc.setPenWidth(1); dc.drawLine(30, h * 0.24, w - 30, h * 0.24);
    
    drawPacesCounter(dc, w, h, paces);
    drawMetersCounter(dc, w, h);
    drawProgressArc(dc, w, h);

    // Проверка наличия контента в ячейках (индексы 1-6)
    var hasContent = false;
    for (var i = 1; i <= 6; i++) { 
        if (currentData.size() > i && currentData[i] != 0 && currentData[i] != null) { 
            hasContent = true; 
            break; 
        } 
    }

    if (hasContent) {
        var boxSize = 38, halfBox = 19, y_delta = 30; 
        // Координаты 6 квадратов
        var positions = [
            [midX + halfBox, midY - boxSize - halfBox + y_delta], 
            [midX - boxSize - halfBox, midY - halfBox + y_delta], 
            [midX - halfBox, midY - halfBox + y_delta], 
            [midX + halfBox, midY - halfBox + y_delta], 
            [midX - 2*halfBox, midY + halfBox + y_delta], 
            [midX, midY + halfBox + y_delta]
        ];

        for (var j = 0; j < 6; j++) {
            var item = (currentData.size() > j + 1) ? currentData[j+1] : 0;
            
            if (item != 0 && item != null) {
                var bx = positions[j][0], by = positions[j][1];
                
                // Рисуем серую рамку (тонкую)
                dc.setColor(0xAAAAAA, -1); 
                dc.setPenWidth(1);
                dc.drawRectangle(bx, by, boxSize, boxSize);

                dc.setColor(txtColor, -1); // Краснеет при спуфе

                // ЛОГИКА ВЫБОРА: ИКОНКА ИЛИ ТЕКСТ
                if (item instanceof Toybox.Lang.Number) {
                    // Используем myFont1/myFont2 как в остальном коде, или myFont если он один
                    var fontToUse = (item < 90) ? myFont1 : myFont2;
                    var finalID = (item < 90) ? (33 + item) : (33 + (item - 90));
                    if (fontToUse != null) {
                        dc.drawText(bx + halfBox, by + halfBox, fontToUse, finalID.toChar().toString(), 1|4);
                    }
                } else if (item instanceof Toybox.Lang.String) {
                    if (item.length() > 0) {
                        var charToDraw = item.substring(0, 1);
                        dc.drawText(bx + halfBox, by + halfBox, Graphics.FONT_LARGE, charToDraw, 1|4);
                    }
                }
            }
        }
        
        // Отрисовка номера КП слева от сетки
        var cpOffset = (w >= 280) ? cpOffsetEnduro : cpOffsetFenix;
        var finalCpX = (w >= 280 && cpNumStr.length() > 2) ? midX - cpOffset - 40 : midX - cpOffset;
        var shiftCorr = (w >= 280 && cpNumStr.length() > 2) ? 105 : ((w >= 280) ? 40 : (cpNumStr.length() > 2 ? 21 : 10));
        
        dc.setColor(txtColor, -1); // Краснеет при спуфе
        dc.drawText(finalCpX, positions[0][1] + halfBox - 20, Graphics.FONT_NUMBER_HOT, cpNumStr, 2|4); 
        var cpWidth = dc.getTextWidthInPixels(cpNumStr, Graphics.FONT_NUMBER_HOT);

        if (currentData[0] > 99) {
            dc.drawText(finalCpX - cpWidth + shiftCorr - 5, positions[0][1] + halfBox - 4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);
        } else {
            if (w <= 218) {
                if (currentData[0] > 9) {
                     if (displayIdx > 9) {
                            dc.drawText(finalCpX - cpWidth + shiftCorr - 15, positions[0][1] + halfBox - 4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);

                        } 
                        else{
                            dc.drawText(finalCpX - cpWidth + shiftCorr - 5, positions[0][1] + halfBox - 4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);
                        }
                    }
                else{
                        if (displayIdx > 9) {
                            dc.drawText(finalCpX - cpWidth + shiftCorr - 45, positions[0][1] + halfBox - 4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);
                        } 
                        else{
                            dc.drawText(finalCpX - cpWidth + shiftCorr - 25, positions[0][1] + halfBox - 4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);
                        }
                    }
            } else {
                if (currentData[0] > 9) {
                    dc.drawText(finalCpX - cpWidth + shiftCorr, positions[0][1] + halfBox - 4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);
                    }
                else{
                    if (displayIdx > 9) {
                        dc.drawText(finalCpX - cpWidth + shiftCorr-45, positions[0][1] + halfBox - 4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);
                        }
                    else{
                        dc.drawText(finalCpX - cpWidth + shiftCorr-30, positions[0][1] + halfBox - 4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);
                    }
                    
                    }
            }
        } 

    } else {
        // --- СЦЕНАРИЙ 2: НЕТ ИКОНОК (БОЛЬШОЙ НОМЕР ПО ЦЕНТРУ) ---
        dc.setColor(txtColor, -1); // Краснеет при спуфе
        dc.drawText(midX, midY - 19, Graphics.FONT_NUMBER_THAI_HOT, cpNumStr, 1|4);
        var bigCpWidth = dc.getTextWidthInPixels(cpNumStr, Graphics.FONT_NUMBER_THAI_HOT);
        
        // Отрисовка порядкового номера (например, "81.")
        if (currentData[0] > 99) {
            dc.drawText(midX - (bigCpWidth / 2) - 45, midY - 4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);
        } else {
            dc.drawText(midX - (bigCpWidth / 2) - 40, midY - 4, Graphics.FONT_LARGE, orderNumStr + ".", 2|4);
        }

        // --- ВОЗВРАТ ПОДСКАЗКИ СЛЕДУЮЩЕГО КП ---
        if (currentIndex + 1 < controlPoints.size()) {
            dc.setColor(0xAAAAAA, -1); 
            // Рисуем номер следующего КП серым цветом с твоими точными координатами
            if (w <= 218) {
                dc.fillPolygon([
                    [midX - 6, midY + 38 - 5], 
                    [midX + 6, midY + 38 - 5], 
                    [midX, midY + 49 - 5]
                ]);
                dc.drawText(midX, midY + 68, Graphics.FONT_NUMBER_MEDIUM, controlPoints[currentIndex + 1][0].toString(), 1|4);
            } else {
                dc.fillPolygon([
                    [midX - 6, midY + 38], 
                    [midX + 6, midY + 38], 
                    [midX, midY + 49]
                ]);
                dc.drawText(midX, midY + 85, Graphics.FONT_NUMBER_MEDIUM, controlPoints[currentIndex + 1][0].toString(), 1|4);
            }
        }
    }
    drawUIElements(dc, w, h, midX, midY, pPause);
}

    function drawNavigation(dc, info, w, h, pPause, gpsS) {
        var cx = w / 2;
        var cy = h / 2;
        var curLoc = (info != null) ? info.currentLocation : null;
        var sInfo = Sensor.getInfo();
        var heading = (sInfo != null && sInfo.heading != null) ? sInfo.heading : (info != null && info.currentHeading != null ? info.currentHeading : lastHeading);
        lastHeading = heading;

        var directDist = 0.0;
        var arrowAngle = 0.0;

        if (startLocation != null && curLoc != null) {
            var curDeg = curLoc.toDegrees();
            var stDeg = startLocation.toDegrees();
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
            directDist = 6371.0 * c;

            var yBearing = Math.sin(dLon) * Math.cos(lat2);
            var xBearing = Math.cos(lat1) * Math.sin(lat2) -
                           Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
            var bearing = Math.atan2(yBearing, xBearing);
            arrowAngle = bearing - heading;
        }

        var padding = (w < 240) ? 12 : 8; 
        var rTip   = (w / 2) - padding;
        var rWings = (w / 2) - padding - 25; 
        var rInner = 35;
        var wingSpan = (w / 2) * 0.65; 

        var drawAngle = arrowAngle - (Math.PI / 2.0);
        var cosA = Math.cos(drawAngle);
        var sinA = Math.sin(drawAngle);
        var cosOrth = Math.cos(drawAngle + Math.PI/2.0);
        var sinOrth = Math.sin(drawAngle + Math.PI/2.0);

        var pTip   = [cx + rTip * cosA, cy + rTip * sinA]; 
        var pWingL = [cx - rWings * cosA + wingSpan * cosOrth, cy - rWings * sinA + wingSpan * sinOrth];
        var pInner = [cx - rInner * cosA, cy - rInner * sinA];
        var pWingR = [cx - rWings * cosA - wingSpan * cosOrth, cy - rWings * sinA - wingSpan * sinOrth];

        dc.setColor(0x00AAFF, -1);
        dc.fillPolygon([pTip, pWingL, pInner, pWingR]);
        
        dc.setColor(0xFFFFFF, -1);
        dc.setPenWidth(3);
        dc.drawLine(pTip[0], pTip[1], pWingL[0], pWingL[1]);
        dc.drawLine(pWingL[0], pWingL[1], pInner[0], pInner[1]);
        dc.drawLine(pInner[0], pInner[1], pWingR[0], pWingR[1]);
        dc.drawLine(pWingR[0], pWingR[1], pTip[0], pTip[1]);

        // Покраснение текста (одометр "домой" / расстояние)
        var txtColor = isSpoofing ? 0xFF0000 : 0xFFFFFF;
        var distStr = isSpoofing ? "GPS ERROR" : ((directDist < 1.0) ? (directDist * 1000).format("%d") + " m" : directDist.format("%.2f") + " km");
        drawOutlineText(dc, cx, cy - 15, Graphics.FONT_XTINY, "BACK TO START", 0x000000, txtColor);
        drawOutlineText(dc, cx, cy + 15, Graphics.FONT_MEDIUM, distStr, 0x000000, txtColor);

        drawGPSBottom(dc, info, w, gpsS);
        drawPacesCounter(dc, w, h, calculatePaces());
        drawMetersCounter(dc, w, h);
    }

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
        if (acc <= 1) { return; }
        var colors = [0x000000, 0x000000, 0xFFFF00, 0xFFFF00, 0x00FF00];
        var x = (w / 2) - (s[0] / 2);
        dc.setColor(colors[acc], -1);
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

    // function loadSettings() {

    //     controlPoints = [
    //         [1, 0, 1, 2, 3, 4, 5],
    //         [22, 90, 91, 92, 93, 94, 95],
    //         [11, 0, 0, 0, 0, 0, 0],
    //         [1, 0, 0, 0, 0, 0, 0],
    //         [39, 0, 0, 0, 0, 0, 0], // Самые последние иконки
    //                 // --- ШРИФТ 1 (myFont1): Иконки 0-89 ---
    //     [100, 0, 1, 2, 3, 4, 5],
    //     [2, 6, 7, 8, 9, 10, 11],
    //     [3, 12, 13, 14, 15, 16, 17],
    //     [4, 18, 19, 20, 21, 22, 23],
    //     [5, 24, 25, 26, 27, 28, 29],
    //     [6, 30, 31, 32, 33, 34, 35],
    //     [37, 36, 37, 38, 39, 40, 41],
    //     [8, 42, 43, 44, 45, 46, 47],
    //     [49, 48, 49, 50, 51, 52, 53],
    //     [10, 54, 55, 56, 57, 58, 59],
    //     [11, 60, 61, 62, 63, 64, 65],
    //     [12, 66, 67, 68, 69, 70, 71],
    //     [13, 72, 73, 74, 75, 76, 77],
    //     [14, 78, 79, 80, 81, 82, 83],
    //     [15, 84, 85, 86, 87, 88, 89], // Последние иконки первого шрифта

    //     [11, 0, 0, 0, 0, 0, 0],
    //     [100, 0, 0, 0, 0, 0, 0],
    //         [1, 0, 0, 0, 0, 0, 0],


    //     // --- МОМЕНТ ПЕРЕКЛЮЧЕНИЯ (СМЕШАННЫЙ КП) ---
    //     // Здесь первые 3 иконки из Font1, последние 3 из Font2
    //     [100, 87, 88, 89, 90, 91, 92], 

    //     // --- ШРИФТ 2 (myFont2): Иконки 90-179 ---
    //     [17, 90, 91, 92, 93, 94, 95],
    //     [18, 96, 97, 98, 99, 100, 101],
    //     [19, 102, 103, 104, 105, 106, 107],
    //     [20, 108, 109, 110, 111, 112, 113],
    //     [21, 114, 115, 116, 117, 118, 119],
    //     [22, 120, 121, 122, 123, 124, 125],
    //     [23, 126, 127, 128, 129, 130, 131],
    //     [24, 132, 133, 134, 135, 136, 137],
    //     [25, 138, 139, 140, 141, 142, 143],
    //     [26, 144, 145, 146, 147, 148, 149],
    //     [27, 150, 151, 152, 153, 154, 155],
    //     [28, 156, 157, 158, 159, 160, 161],
    //     [29, 162, 163, 164, 165, 166, 167],
    //     [30, 168, 169, 170, 171, 172, 173],
    //     [31, 174, 175, 176, 177, 178, 179], // Самые последние иконки
        
             
    //          ];
    // }

function loadSettings() {
        var app = Application.getApp();
        // getProperty — это "золотой стандарт" для CIQ 1.x
        var data = app.getProperty("cp_data");

        if (data != null && data instanceof Toybox.Lang.Array) {
            controlPoints = data;
        } else {
            // Твои стандартные КП
            controlPoints = [[31, 179, 178, 177, 176, 175, 174]];
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