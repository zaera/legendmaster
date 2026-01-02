using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Activity;
using Toybox.Math;
using Toybox.System;
using Toybox.Position;
using Toybox.Application;

class legendmasterView extends WatchUi.View {
    var myFont, pageID = 0, currentIndex = 0, launchTime, appState = 0; 
    var controlPoints = []; 

    function initialize() { 
        View.initialize(); 
        launchTime = System.getTimer();
        loadSettings(); 
    }

    function onLayout(dc) { 
        myFont = WatchUi.loadResource(Rez.Fonts.LegendFont); 
    }

    function loadSettings() {
        var str = Application.getApp().getProperty("CP_Data");
        if (str == null || str.equals("")) {
            controlPoints = [[31,12,45,0,8,0],[32,0,122,14,0,1],[100,0,170,0,0,0]];
            return;
        }
        try {
            var points = [];
            var rawPoints = splitString(str, '|');
            for (var i = 0; i < rawPoints.size(); i++) {
                var rawData = splitString(rawPoints[i], ',');
                var pointData = new [rawData.size()];
                for (var j = 0; j < rawData.size(); j++) {
                    pointData[j] = rawData[j].toNumber();
                }
                points.add(pointData);
            }
            controlPoints = points;
        } catch (ex) {
            controlPoints = [[99, 0, 0, 0, 0, 0]]; 
        }
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

        // ========================================================
        // ИНДИВИДУАЛЬНЫЕ НАСТРОЙКИ ПОЗИЦИЙ [X_отступ, Y_высота]
        // ========================================================
        var posStart  = [55, h / 3.4];
        var posPause  = [25, h / 3.4]; // Иконка "||"
        var posResume = [65, h / 3.4];
        var posSave   = [65, h * 0.72];
        var posDisc   = [75, h * 0.72];
        // ========================================================
        
        if (System.getTimer() - launchTime < 1000) { 
            drawSplashScreen(dc, w, h); 
            WatchUi.requestUpdate();
            return; 
        }

        var info = Activity.getActivityInfo();
        if (appState == 2) { 
            drawPauseMenu(dc, info, w, h, posResume, posSave, posDisc); 
        } else if (pageID == 1) { 
            drawIcons(dc, w, h, posPause); 
        } else if (pageID == -1) { 
            drawNavigation(dc, info, w, h, posPause); 
        } else { 
            drawMain(dc, info, w, h, posStart, posPause); 
        }
    }

    function drawMain(dc, info, w, h, pStart, pPause) {
        dc.setColor(0xFFFFFF, -1);
        var dist = (info != null && info.elapsedDistance != null) ? (info.elapsedDistance/1000.0).format("%.2f") : "0.00";
        var timer = (info != null && info.timerTime != null) ? formatTime(info.timerTime) : "00:00";
        
        dc.drawText(w/2, h/2 - 60, Graphics.FONT_XTINY, "DISTANCE", 1);
        dc.drawText(w/2, h/2 - 40, Graphics.FONT_NUMBER_MEDIUM, dist, 1);
        dc.drawText(w/2, h/2 + 20, Graphics.FONT_LARGE, timer, 1);

        drawGPSBottom(dc, w, h);

        if (appState == 0) {
            dc.setColor(0x55AAFF, -1);
            dc.drawText(w - pStart[0], pStart[1], Graphics.FONT_XTINY, "START", 2);
        } else { 
            drawPauseSymbol(dc, w, h, pPause); 
        }
    }

    function drawGPSBottom(dc, w, h) {
        var posInfo = Position.getInfo();
        var acc = (posInfo != null && posInfo.accuracy != null) ? posInfo.accuracy : 0;
        var colors = [0x555555, 0xFF0000, 0xFFAA00, 0xFFFF00, 0x00FF00];
        
        var wingW = 5, wingH = 2, bodyW = 1, bodyH = 4, gap = 1, textOffset = 18;
        var totalW = (wingW * 2) + bodyW + (gap * 2);
        var x = (w / 2) - (totalW / 2) - 5;
        var y = h - 25;

        dc.setColor(colors[acc], -1);
        dc.fillRectangle(x, y + (bodyH - wingH) / 2, wingW, wingH);
        dc.fillRectangle(x + wingW + gap, y, bodyW, bodyH);
        dc.fillRectangle(x + wingW + bodyW + (gap * 2), y + (bodyH - wingH) / 2, wingW, wingH);

        dc.setColor(0xFFFFFF, -1);
        dc.drawText(x + textOffset, y - 6, Graphics.FONT_XTINY, acc.toString(), 0);
    }

    function drawPauseMenu(dc, info, w, h, pRes, pSave, pDisc) {
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2, 28, Graphics.FONT_TINY, "PAUSED", 1);
        var dist = (info != null && info.elapsedDistance != null) ? (info.elapsedDistance/1000.0).format("%.2f") : "0.00";
        var timer = (info != null && info.timerTime != null) ? formatTime(info.timerTime) : "00:00";
        dc.drawText(w/2, h/2 - 25, Graphics.FONT_SMALL, timer, 1);
        dc.drawText(w/2, h/2 + 5, Graphics.FONT_SMALL, dist + " km", 1);

        dc.setColor(0x00FF00, -1); 
        dc.drawText(w - pRes[0], pRes[1], Graphics.FONT_XTINY, "RESUME", 2);
        
        dc.setColor(0xFF5555, -1); 
        dc.drawText(w - pSave[0], pSave[1], Graphics.FONT_XTINY, "SAVE", 2);

        dc.setColor(0xAAAAAA, -1); 
        dc.drawText(pDisc[0], pDisc[1], Graphics.FONT_XTINY, "DISCARD", 0);
    }

    function drawIcons(dc, w, h, pPause) {
        var midX = w / 2, midY = h / 2;
        if (controlPoints.size() == 0) { return; }
        var currentData = controlPoints[currentIndex];
        
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(midX, 25, Graphics.FONT_XTINY, "КП " + (currentIndex + 1) + " (№" + currentData[0] + ")", 1);
        if (myFont != null) {
            var step = 42, startX = midX - (step * 2); 
            for (var i = 0; i < 5; i++) {
                if (currentData.size() > i + 1) {
                    var iconID = currentData[i + 1];
                    if (iconID != 0) {
                        var char = (57345 + iconID).toChar();
                        dc.drawText(startX + (i * step), midY, myFont, char.toString(), 1|4);
                    }
                }
            }
        }
        drawUIElements(dc, w, h, midX, midY, pPause);
    }

    function drawUIElements(dc, w, h, midX, midY, pPause) {
        var lX = w * 0.12, rX = w * 0.88;
        dc.setColor(0x55AAFF, -1);
        dc.fillPolygon([[lX-13, midY + 26], [lX - 19, midY + 35], [lX-7, midY + 35]]);
        dc.fillPolygon([[lX-8, midY + 55], [lX - 14, midY + 46], [lX -2, midY + 46]]);
        dc.setPenWidth(2);
        dc.drawLine(rX + 2 - 5, midY + 60 - 5, rX + 2 + 5, midY + 60 + 5);
        dc.drawLine(rX + 2 - 5, midY + 60 + 5, rX + 2 + 5, midY + 60 - 5);
        if (appState == 1) { drawPauseSymbol(dc, w, h, pPause); }
    }

    function drawPauseSymbol(dc, w, h, pPause) {
        dc.setColor(0x55AAFF, -1); 
        dc.setPenWidth(3);
        var targetX = w - pPause[0]; 
        var targetY = pPause[1]; 
        dc.drawLine(targetX - 3, targetY - 6, targetX - 3, targetY + 6);
        dc.drawLine(targetX + 3, targetY - 6, targetX + 3, targetY + 6);
    }

    function drawNavigation(dc, info, w, h, pPause) {
        dc.setColor(0xFFFFFF, -1);
        dc.drawText(w/2, 20, Graphics.FONT_TINY, "BACK TO START", 1);
        if (info != null && info.startLocation != null) {
            dc.setPenWidth(2); dc.drawCircle(w/2, h/2, 30); dc.drawLine(w/2, h/2, w/2, h/2 - 25);
        } else { dc.drawText(w/2, h/2, Graphics.FONT_XTINY, "WAITING GPS...", 1); }
        if (appState == 1) { drawPauseSymbol(dc, w, h, pPause); }
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