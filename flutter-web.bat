@echo off
title FamilySphere Web (Chrome)
color 0E

echo.
echo  ====================================
echo   FamilySphere Flutter - WEB Mode
echo  ====================================
echo.
echo  Web URL : http://localhost:5050
echo  API URL : http://localhost:5000
echo.

set PATH=D:\flutter\bin;%PATH%
cd /d %~dp0mobile\familysphere_app

flutter run -d chrome --web-port=5050 --dart-define=API_BASE_URL=http://localhost:5000
