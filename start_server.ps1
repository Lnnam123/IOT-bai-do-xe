# Khởi chạy dự án Smart Parking IoT bằng Node.js và Vite
# Encoding: UTF-8

$Host.UI.RawUI.WindowTitle = "Smart Parking IoT - Node.js & Vite"

# Đảm bảo Node.js có trong PATH của phiên làm việc
if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
    if (Test-Path "C:\Program Files\nodejs") {
        $env:PATH = "C:\Program Files\nodejs;" + $env:PATH
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " HỆ THỐNG GIÁM SÁT BÃI ĐỖ XE ESP32 (SMART PARKING IOT)" -ForegroundColor Yellow
Write-Host " Phiên bản chuẩn hóa Node.js & Vite" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " [1] Chạy chế độ Phát triển (Vite Dev Server - Cổng 3000)" -ForegroundColor Cyan
Write-Host " [2] Chạy Máy chủ Node.js & Gateway ESP32 (Cổng 5000)" -ForegroundColor Yellow
Write-Host " [3] Build dự án đóng gói (Vite Build)" -ForegroundColor Magenta
Write-Host ""

$choice = Read-Host "Nhập lựa chọn của bạn (1, 2 hoặc 3) [Mặc định: 1]"
if ([string]::IsNullOrWhiteSpace($choice)) {
    $choice = "1"
}

if ($choice -eq "1") {
    Write-Host "`nĐang khởi chạy Vite Dev Server tại http://localhost:3000..." -ForegroundColor Green
    & cmd.exe /c "npm run dev"
} elseif ($choice -eq "2") {
    Write-Host "`nĐang khởi chạy Node.js Server tại http://localhost:5000..." -ForegroundColor Yellow
    & cmd.exe /c "npm start"
} elseif ($choice -eq "3") {
    Write-Host "`nĐang build dự án..." -ForegroundColor Magenta
    & cmd.exe /c "npm run build"
} else {
    Write-Host "Lựa chọn không hợp lệ." -ForegroundColor Red
}
