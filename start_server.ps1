# Khởi chạy máy chủ Web tĩnh cục bộ cho dự án Smart Parking WebIOT
# Không cần cài đặt Node.js hay Python, sử dụng sẵn .NET của Windows

$Port = 8080
$Root = $PSScriptRoot

if (-not $Root) {
    $Root = (Get-Location).Path
}

$Listener = New-Object System.Net.HttpListener
$Prefix = "http://localhost:$Port/"
$Listener.Prefixes.Add($Prefix)

try {
    $Listener.Start()
} catch {
    Write-Host "[!] Không thể mở cổng $Port. Thử đổi cổng khác hoặc chạy với quyền Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " HỆ THỐNG GIÁM SÁT BÃI ĐỖ XE ESP32 (SMART PARKING IOT)" -ForegroundColor Yellow
Write-Host " Máy chủ đang chạy tại: $Prefix" -ForegroundColor Green
Write-Host " Đang tự động mở trình duyệt..." -ForegroundColor Gray
Write-Host " Nhấn Ctrl+C để dừng máy chủ." -ForegroundColor DarkGray
Write-Host "==========================================================" -ForegroundColor Cyan

# Mở trình duyệt mặc định
Start-Process $Prefix

$MimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".ico"  = "image/x-icon"
}

while ($Listener.IsListening) {
    $Context = $Listener.GetContext()
    $Request = $Context.Request
    $Response = $Context.Response

    $UrlPath = $Request.Url.LocalPath.TrimStart('/')
    if ([string]::IsNullOrEmpty($UrlPath) -or $UrlPath -eq "/") {
        $UrlPath = "index.html"
    }

    $FilePath = Join-Path $Root $UrlPath

    if (Test-Path $FilePath -PathType Leaf) {
        $Ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
        $ContentType = "text/plain"
        if ($MimeTypes.ContainsKey($Ext)) {
            $ContentType = $MimeTypes[$Ext]
        }

        $Bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $Response.ContentType = $ContentType
        $Response.ContentLength64 = $Bytes.Length
        $Response.AddHeader("Access-Control-Allow-Origin", "*")
        $Response.StatusCode = 200
        $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
    } else {
        $Response.StatusCode = 404
        $ErrMsg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $UrlPath")
        $Response.OutputStream.Write($ErrMsg, 0, $ErrMsg.Length)
    }

    $Response.OutputStream.Close()
}
