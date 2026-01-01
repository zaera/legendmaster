@echo off
echo ================================
echo   LEGENDMASTER - BUILD START
echo ================================

REM перейти в папку проекта
cd /d "%~dp0"

REM путь к SDK
set SDK=C:\Users\punishman\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-8.4.0-2025-12-03-5122605dc

REM путь к ключу
set KEY=C:/Users/punishman/Documents/GitHub/legendmaster/garmin_sub_project/dev_key/developer_key

REM выходной файл
set OUT=bin\legendmaster.prg

REM запуск сборки
java -Xms1g -Dfile.encoding=UTF-8 -jar "%SDK%\bin\monkeybrains.jar" ^
 -f monkey.jungle ^
 -y %KEY% ^
 -d fenix7x_sim ^
 -o %OUT% ^
 -w

echo.
echo ================================
echo   BUILD FINISHED
echo ================================
echo.

pause
