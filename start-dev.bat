@echo off
echo [FamilySphere] Starting Redis...
start "" /B "d:\FamilySphere\redis\redis-server.exe"
timeout /t 2 /nobreak >nul

"d:\FamilySphere\redis\redis-cli.exe" ping >nul 2>&1
if errorlevel 1 (
    echo [FamilySphere] WARNING: Redis did not respond. Server will run without OCR queue.
) else (
    echo [FamilySphere] Redis is running on port 6379
)

echo [FamilySphere] Starting backend...
cd /d "d:\FamilySphere\backend"
npm run dev
