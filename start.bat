@echo off
chcp 65001 >nul
title Smart Parking IoT - Node.js & Vite Server

set "PATH=C:\Program Files\nodejs;%PATH%"

echo ==========================================================
echo   HE THONG BAI DO XE THONG MINH ESP32 (SMART PARKING IOT)
echo   Chay bang Node.js & Vite
echo ==========================================================
echo.
echo [1] Chay che do Phat trien (Vite Dev Server - Hot Reload, Port 3000)
echo [2] Chay May chu Node.js Backend & ESP32 Gateway (Port 5000)
echo [3] Build du an san xuat (Vite Build)
echo.

set /p choice="Nhap lua chon cua ban (1, 2 hoac 3) [Mac dinh: 1]: "
if "%choice%"=="" set choice=1

if "%choice%"=="1" (
    echo.
    echo Dang khoi dong Vite Dev Server...
    npm run dev
) else if "%choice%"=="2" (
    echo.
    echo Dang khoi dong Node.js Backend Server...
    npm start
) else if "%choice%"=="3" (
    echo.
    echo Dang build du an...
    npm run build
    pause
) else (
    echo Lua chon khong hop le.
    pause
)
