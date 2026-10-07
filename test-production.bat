@echo off
title FamilySphere - Production Test on USB Device
color 0E

echo.
echo  ================================================
echo   FamilySphere - PRODUCTION MODE USB Testing
echo  ================================================
echo.
echo  Backend: https://familysphere.onrender.com
echo  Mode: Production (deployed on Render)
echo.

set JAVA_HOME=D:\jdk-17
set PATH=D:\jdk-17\bin;D:\flutter\bin;C:\Users\kanan\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools;%PATH%

echo  [1/3] Checking connected devices...
echo.
adb devices
echo.

echo  [2/3] Available devices:
flutter devices
echo.

echo  ================================================
echo   SELECT YOUR DEVICE:
echo  ================================================
echo   1. USB Device (RZCX92TKJ0X) - Recommended
echo   2. Auto-detect USB device
echo   3. List all devices again
echo  ================================================
echo.
set /p choice="Enter choice (1/2/3): "

cd /d %~dp0mobile\familysphere_app

if "%choice%"=="1" (
    echo.
    echo  [3/3] Running on USB device RZCX92TKJ0X...
    echo  Production URL: https://familysphere.onrender.com
    echo.
    flutter run -d RZCX92TKJ0X --release
) else if "%choice%"=="2" (
    echo.
    echo  [3/3] Auto-detecting USB device...
    echo  Production URL: https://familysphere.onrender.com
    echo.
    flutter run --release
) else if "%choice%"=="3" (
    echo.
    flutter devices
    echo.
    set /p deviceId="Enter device ID: "
    echo.
    echo  [3/3] Running on device !deviceId!...
    flutter run -d !deviceId! --release
) else (
    echo  Invalid choice!
    pause
    exit /b 1
)

echo.
echo  ================================================
echo   App deployed in RELEASE mode!
echo   Testing production backend on Render
echo  ================================================
echo.
pause
