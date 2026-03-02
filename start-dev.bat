@echo off
title FamilySphere Local Dev
color 0A

echo.
echo  ====================================
echo   FamilySphere - Starting Local Dev
echo  ====================================
echo.

:: ── 1. Get the real WiFi/LAN IP (skip WSL 172.x and VirtualBox 192.168.56.x) ──
set PC_IP=
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    for /f "tokens=1" %%b in ("%%a") do (
        set CANDIDATE=%%b
        if not "%%b"=="172" (
            echo %%b | findstr /r "^10\. ^192\.168\. ^172\." >nul 2>&1
            if "%%b" neq "" set PC_IP=%%b
        )
    )
)
:: Pick 10.x address specifically (most likely real WiFi)
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    for /f "tokens=1" %%b in ("%%a") do (
        echo %%b | findstr /r "^10\." >nul 2>&1
        if not errorlevel 1 set PC_IP=%%b
    )
)
if "%PC_IP%"=="" (
    echo  WARNING: Could not auto-detect WiFi IP. Using fallback 10.173.37.206
    set PC_IP=10.173.37.206
)
echo  PC IP detected: %PC_IP%
echo  Flutter will connect to: http://%PC_IP%:5000
echo.

:: ── 2. Start Redis (local Windows Redis) ──────────────────────────────────
echo  [1/2] Starting Redis...
start "Redis Server" /min cmd /c "cd /d %~dp0redis && redis-server.exe redis.windows.conf"
timeout /t 2 /nobreak >nul
echo       Redis started on port 6379
echo.

:: ── 3. Start Backend (override REDIS_URL to local Redis, not Redis Cloud) ──
echo  [2/2] Starting Backend (npm run dev)...
start "Backend Server" cmd /k "cd /d %~dp0backend && set REDIS_URL=redis://localhost:6379 && npm run dev"
echo       Backend started on http://localhost:5000
echo.

:: ── 4. Save IP to a temp file for flutter-local.bat to read ───────────────
echo %PC_IP%> %~dp0.dev-ip.txt

echo  ====================================
echo   All services started!
echo.
echo   Backend : http://localhost:5000
echo   APK/Phone: http://%PC_IP%:5000
echo.
echo   Now run:  flutter-local.bat
echo   (Wait ~5 seconds for backend to be ready first)
echo  ====================================
echo.
pause
