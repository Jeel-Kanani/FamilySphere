@echo off
echo [FamilySphere] Starting Redis...

"d:\FamilySphere\redis\redis-cli.exe" ping >nul 2>&1
if errorlevel 1 (
    start "" /B "d:\FamilySphere\redis\redis-server.exe" "d:\FamilySphere\redis\redis.windows.conf"
    timeout /t 2 /nobreak >nul
    "d:\FamilySphere\redis\redis-cli.exe" ping >nul 2>&1
    if errorlevel 1 (
        echo [FamilySphere] WARNING: Redis did not start. OCR queue will be disabled.
    ) else (
        echo [FamilySphere] Redis started successfully on port 6379
    )
) else (
    echo [FamilySphere] Redis already running on port 6379
)

echo [FamilySphere] Starting backend...
cd /d "d:\FamilySphere\backend"
npm run dev
