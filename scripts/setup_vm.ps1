# SkyDesk OS - Windows Cloud VM Setup & Provisioning Script
# Designed for High-Performance GitHub Actions Windows Server Runner
# =========================================================================

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [SkyDesk OS] Starting Automated Windows Provisioning Engine " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Setup Password & User Accounts
$username = "runneradmin"
$password = $env:CUSTOM_PASSWORD

if ([string]::IsNullOrWhiteSpace($password)) {
    $charSet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*"
    $random = New-Object System.Random
    $password = -join ((1..16) | ForEach-Object { $charSet[$random.Next(0, $charSet.Length)] })
}

Write-Host "[+] Configuring User Account: $username" -ForegroundColor Yellow
try {
    net user $username $password /add /expires:never /active:yes 2>$null
    net localgroup "Administrators" $username /add 2>$null
    net localgroup "Remote Desktop Users" $username /add 2>$null
    Write-Host "[✓] User '$username' configured with Administrator & RDP privileges." -ForegroundColor Green
} catch {
    Write-Host "[!] User config notice: $_" -ForegroundColor DarkGray
}

# 2. Enable Remote Desktop (RDP) & Network Tweaks
Write-Host "[+] Enabling Remote Desktop Protocol (RDP) & Firewall Rules..." -ForegroundColor Yellow
try {
    Set-ItemProperty -Path 'HKLM:SystemCurrentControlSetControlTerminal Server' -Name "fDenyTSConnections" -Value 0 -Force
    Set-ItemProperty -Path 'HKLM:SystemCurrentControlSetControlTerminal ServerWinStationsRDP-Tcp' -Name "UserAuthentication" -Value 0 -Force
    Set-ItemProperty -Path 'HKLM:SystemCurrentControlSetControlTerminal ServerWinStationsRDP-Tcp' -Name "fDisableAudioCapture" -Value 0 -Force
    Set-ItemProperty -Path 'HKLM:SOFTWAREPoliciesMicrosoftWindowsPersonalization' -Name "NoLockScreen" -Value 1 -Force -ErrorAction SilentlyContinue
    
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "SkyDesk RDP TCP 3389" -Direction Inbound -LocalPort 3389 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "SkyDesk Web 8080" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
    
    Set-Service -Name "TermService" -StartupType Automatic
    Start-Service -Name "TermService"
    Write-Host "[✓] Windows RDP service is ACTIVE on port 3389." -ForegroundColor Green
} catch {
    Write-Host "[!] RDP config notice: $_" -ForegroundColor DarkGray
}

$workDir = "C:SkyDesk"
if (!(Test-Path $workDir)) {
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
}

# 3. Optional: Install Developer & Student Software Bundle
if ($env:INSTALL_TOOLS -eq 'true' -or $env:INSTALL_TOOLS -eq $true) {
    Write-Host "[+] Installing Student & Developer Software Bundle via Winget..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command `"
        try {
            winget install --id Google.Chrome --accept-package-agreements --accept-source-agreements --silent --disable-interactivity 2`$null
            winget install --id Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements --silent --disable-interactivity 2`$null
            winget install --id Git.Git --accept-package-agreements --accept-source-agreements --silent --disable-interactivity 2`$null
            winget install --id 7zip.7zip --accept-package-agreements --accept-source-agreements --silent --disable-interactivity 2`$null
        } catch {}
    `"" -WindowStyle Hidden
}

# 4. Setup Web-based Remote Desktop Gateway
$html5Script = @"
import http.server
import socketserver
import json

PORT = 8080
HTML_CONTENT = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SkyDesk Cloud PC</title>
    <style>
        body { font-family: system-ui, sans-serif; background: #0a0d14; color: #fff; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
        .box { background: #111726; border: 1px solid #1f293d; border-radius: 16px; padding: 32px; max-width: 520px; width: 90%; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
        .badge { background: #10b98125; color: #10b981; border: 1px solid #10b98150; padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: bold; }
        .row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #1f293d; font-family: monospace; font-size: 14px; }
        .btn { display: block; width: 100%; text-align: center; background: #4f46e5; color: #fff; padding: 12px; border-radius: 10px; text-decoration: none; font-weight: bold; margin-top: 20px; box-sizing: border-box; }
    </style>
</head>
<body>
    <div class="box">
        <span class="badge">● ONLINE</span>
        <h2 style="margin: 12px 0 8px 0;">SkyDesk Cloud PC Active</h2>
        <p style="color: #9ca3af; font-size: 13px; margin-bottom: 20px;">Windows Server 2022 Cloud VM is ready for remote connection.</p>
        <div class="row"><span style="color:#6b7280;">Host:</span><span style="color:#38bdf8;">__RDP_ENDPOINT_PLACEHOLDER__</span></div>
        <div class="row"><span style="color:#6b7280;">Username:</span><span>runneradmin</span></div>
        <div class="row"><span style="color:#6b7280;">Password:</span><span style="color:#fbbf24;">__PASSWORD_PLACEHOLDER__</span></div>
        <a href="/download-rdp" class="btn">⬇ Download .RDP Profile</a>
    </div>
</body>
</html>
'''

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(HTML_CONTENT.encode('utf-8'))
        elif self.path == '/download-rdp':
            rdp_content = "full address:s:__RDP_ENDPOINT_PLACEHOLDER__
username:s:runneradmin
prompt for credentials:i:1
screen mode id:i:2
desktopwidth:i:1920
desktopheight:i:1080
session bpp:i:32
authentication level:i:2
"
            self.send_response(200)
            self.send_header('Content-type', 'application/x-rdp')
            self.send_header('Content-Disposition', 'attachment; filename="SkyDesk-CloudVM.rdp"')
            self.end_headers()
            self.wfile.write(rdp_content.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
    httpd.serve_forever()
"@

$html5Script | Out-File -FilePath "$workDirweb_gateway.py" -Encoding utf8 -Force

# 5. Initialize Tunnels
$cfWebUrl = ""
$cfRdpUrl = ""
$pinggyRdpUrl = ""
$ngrokRdpUrl = ""

# 5.1 Cloudflare Tunnel
$cfPath = "$workDircloudflared.exe"
if (!(Test-Path $cfPath)) {
    try {
        Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile $cfPath -TimeoutSec 30
    } catch {}
}

# 5.2 Pinggy TCP Tunnel
$pinggyLog = "$workDirpinggy.log"
Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command `"ssh -p 443 -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -R0:localhost:3389 a.pinggy.io > $pinggyLog 2>&1`"" -WindowStyle Hidden
Start-Sleep -Seconds 5
if (Test-Path $pinggyLog) {
    $pinggyContent = Get-Content $pinggyLog -Raw
    if ($pinggyContent -match 'tcp://([a-zA-Z0-9.-]+):(d+)') {
        $pinggyRdpUrl = "$($Matches[1]):$($Matches[2])"
        Write-Host "[✓] Pinggy RDP Endpoint: $pinggyRdpUrl" -ForegroundColor Green
    }
}

# 5.3 Cloudflare Quick Web Tunnel
Start-Process -FilePath "python.exe" -ArgumentList "$workDirweb_gateway.py" -WindowStyle Hidden -ErrorAction SilentlyContinue
if (Test-Path $cfPath) {
    $cfLog = "$workDircloudflare_web.log"
    Start-Process -FilePath $cfPath -ArgumentList "tunnel --url http://localhost:8080 --no-autoupdate" -RedirectStandardError $cfLog -WindowStyle Hidden
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 2
        if (Test-Path $cfLog) {
            $cfContent = Get-Content $cfLog -Raw
            if ($cfContent -match 'https://[a-zA-Z0-9-]+.trycloudflare.com') {
                $cfWebUrl = $Matches[0]
                Write-Host "[✓] Cloudflare Web Access URL: $cfWebUrl" -ForegroundColor Green
                break
            }
        }
    }
}

$primaryRdp = if (![string]::IsNullOrWhiteSpace($pinggyRdpUrl)) { $pinggyRdpUrl } else { "127.0.0.1:3389" }

if (Test-Path "$workDirweb_gateway.py") {
    $content = Get-Content "$workDirweb_gateway.py" -Raw
    $content = $content -replace '__PASSWORD_PLACEHOLDER__', $password
    $content = $content -replace '__RDP_ENDPOINT_PLACEHOLDER__', $primaryRdp
    $content | Out-File -FilePath "$workDirweb_gateway.py" -Encoding utf8 -Force
}

# 6. Construct Token Payload
$osInfo = Get-CimInstance Win32_OperatingSystem
$cpuInfo = Get-CimInstance Win32_Processor
$totalRamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$freeDiskGB = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
$runnerIp = $env:RUNNER_PUBLIC_IP
if ([string]::IsNullOrWhiteSpace($runnerIp)) { $runnerIp = "GitHub Hosted Runner" }

$sessionDuration = 6
if ($env:SESSION_HOURS -match '^d+$') { $sessionDuration = [int]$env:SESSION_HOURS }
$expiresAt = (Get-Date).AddHours($sessionDuration).ToString("yyyy-MM-ddTHH:mm:ssZ")
$createdAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
$sessionId = [guid]::NewGuid().ToString("N")

$tokenPayload = @{
    id = $sessionId
    version = "2.0"
    status = "active"
    created_at = $createdAt
    expires_at = $expiresAt
    os = "$($osInfo.Caption) ($($osInfo.OSArchitecture))"
    specs = @{
        cpu = "$($cpuInfo.Name) ($($cpuInfo.NumberOfLogicalProcessors) vCPUs)"
        ram = "$totalRamGB GB DDR4"
        disk_free = "$freeDiskGB GB Free SSD"
        public_ip = $runnerIp
    }
    credentials = @{
        username = $username
        password = $password
        domain = "."
    }
    endpoints = @{
        rdp_host = $primaryRdp
        web_remote_url = $cfWebUrl
        pinggy_endpoint = $pinggyRdpUrl
    }
    workflow = @{
        repo = $env:GITHUB_REPO
        run_id = $env:GITHUB_RUN_ID
    }
}

$tokenJson = $tokenPayload | ConvertTo-Json -Depth 5
$tokenBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($tokenJson))
$skydeskToken = "skydesk_vm_$tokenBase64"

$tokenPayload | Add-Member -MemberType NoteProperty -Name "vm_token" -Value $skydeskToken -Force
$tokenPayload | ConvertTo-Json -Depth 5 | Out-File -FilePath "./vm-token.json" -Encoding utf8 -Force

# 7. Write Summary to GITHUB_STEP_SUMMARY
$summaryMd = @"
# 🚀 SkyDesk Cloud VM is Online!
### 🔑 VM Session Access Token
```text
$skydeskToken
```
| Parameter | Value |
| :--- | :--- |
| **Status** | 🟢 **ACTIVE / READY** |
| **Direct RDP Endpoint** | `$primaryRdp` |
| **In-Browser Web Access** | [$($cfWebUrl -replace 'https://', '')]($cfWebUrl) |
| **Username** | `$username` |
| **Password** | `$password` |
| **Session Expiration** | $expiresAt (6 Hours Max) |
"@

$summaryMd | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append

if (![string]::IsNullOrWhiteSpace($env:WEB_PORTAL_URL)) {
    try {
        $publishBody = @{ token = $skydeskToken; session = $tokenPayload } | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri "$($env:WEB_PORTAL_URL.TrimEnd('/'))/api/token/publish" -Method Post -Body $publishBody -ContentType "application/json" -TimeoutSec 15
    } catch {}
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [✓] SkyDesk Cloud VM Ready! Token: $skydeskToken" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
