@echo off
title FamilySphere Flutter (Local)
color 0B

echo.
echo  ====================================
echo   FamilySphere Flutter - LOCAL mode
echo  ====================================
echo.

:: ── Read IP saved by start-dev.bat ────────────────────────────────────────
if exist "%~dp0.dev-ip.txt" (
    set /p PC_IP=<"%~dp0.dev-ip.txt"
) else (
    :: Fallback: detect IP now
    for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address" ^| findstr /v "127.0.0.1"') do (
        for /f "tokens=1" %%b in ("%%a") do set PC_IP=%%b
        goto :found_ip
    )
)
:found_ip

echo  Connecting Flutter to: http://%PC_IP%:5000
echo  (This overrides the production URL - no code changes needed)
echo.
echo  Hot reload is ENABLED - edit Dart files and press 'r' to reload instantly
echo  Hot restart: press 'R'
echo  Quit: press 'q'
echo.

cd /d %~dp0mobile\familysphere_app

flutter run --dart-define=API_BASE_URL=http://%PC_IP%:5000
