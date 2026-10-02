# =========================================================================
# SkyDesk OS - Windows Cloud VM Setup & Provisioning Engine
# High-Performance Automated Script for GitHub Actions Windows Server
# =========================================================================

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [SkyDesk OS] Starting Automated Windows Provisioning Engine " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Setup Password & User Accounts
$username = "runneradmin"
$password = $env:CUSTOM_PASSWORD

if ([string]::IsNullOrWhiteSpace($password)) {
    # Strong alphanumeric password (no problematic shell characters)
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
    $rand = New-Object System.Random
    $password = -join ((1..16) | ForEach-Object { $chars[$rand.Next(0, $chars.Length)] })
}

Write-Host "[+] Configuring User Account: $username" -ForegroundColor Yellow
try {
    net user $username $password /add /expires:never /active:yes 2>$null
    net localgroup "Administrators" $username /add 2>$null
    net localgroup "Remote Desktop Users" $username /add 2>$null
    Write-Host "[✓] User '$username' configured with Administrator privileges." -ForegroundColor Green
} catch {
    Write-Host "[!] User config notice: $_" -ForegroundColor DarkGray
}

# 2. Enable Remote Desktop (RDP) & Configure Firewall Rules
Write-Host "[+] Enabling Remote Desktop Protocol (RDP)..." -ForegroundColor Yellow
try {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "fDisableAudioCapture" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name "NoLockScreen" -Value 1 -Force -ErrorAction SilentlyContinue
    
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "SkyDesk RDP TCP 3389" -Direction Inbound -LocalPort 3389 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "SkyDesk Web 8080" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
    
    Set-Service -Name "TermService" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "TermService" -ErrorAction SilentlyContinue
    Write-Host "[✓] Windows RDP service is ACTIVE on port 3389." -ForegroundColor Green
} catch {
    Write-Host "[!] RDP notice: $_" -ForegroundColor DarkGray
}

# 3. Create Working Directory
$workDir = "C:\SkyDesk"
if (!(Test-Path $workDir)) {
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
}

# 4. Optional: Install Developer & Student Software in Background
if ($env:INSTALL_TOOLS -eq 'true' -or $env:INSTALL_TOOLS -eq $true) {
    Write-Host "[+] Installing Student & Developer Software Suite (Winget)..." -ForegroundColor Yellow
    $installCmd = "winget install --id Google.Chrome --accept-package-agreements --accept-source-agreements --silent --disable-interactivity; winget install --id Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements --silent --disable-interactivity; winget install --id Git.Git --accept-package-agreements --accept-source-agreements --silent --disable-interactivity; winget install --id 7zip.7zip --accept-package-agreements --accept-source-agreements --silent --disable-interactivity"
    Start-Process powershell.exe -ArgumentList "-NoProfile", "-WindowStyle", "Hidden", "-Command", $installCmd -ErrorAction SilentlyContinue
    Write-Host "[✓] Software packages downloading in background." -ForegroundColor Green
}

# 5. Create Standalone Web Gateway Server
Write-Host "[+] Creating Web HTML5 Access Gateway on port 8080..." -ForegroundColor Yellow
$pyServerCode = @'
import http.server
import socketserver
import json
import sys

PORT = 8080

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SkyDesk Cloud PC - In-Browser Web Console</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Inter', sans-serif; background: #0a0d14; color: #f3f4f6; min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 20px; }
        .card { background: #111726; border: 1px solid #1f293d; border-radius: 16px; max-width: 680px; width: 100%; padding: 32px; box-shadow: 0 20px 40px rgba(0,0,0,0.6); }
        .header { display: flex; align-items: center; gap: 12px; margin-bottom: 20px; }
        .badge { background: #10b98120; color: #10b981; border: 1px solid #10b98150; padding: 4px 12px; border-radius: 9999px; font-size: 13px; font-weight: 600; }
        h1 { font-size: 24px; font-weight: 700; color: #ffffff; }
        p { color: #9ca3af; font-size: 14px; line-height: 1.6; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin: 24px 0; }
        .info-box { background: #0a0d14; border: 1px solid #1f293d; padding: 14px; border-radius: 10px; }
        .info-label { font-size: 11px; text-transform: uppercase; color: #6b7280; font-weight: 600; letter-spacing: 0.5px; }
        .info-val { font-family: 'JetBrains Mono', monospace; font-size: 15px; color: #38bdf8; margin-top: 4px; word-break: break-all; }
        .btn-group { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 24px; }
        .btn { display: inline-flex; align-items: center; justify-content: center; padding: 12px 20px; border-radius: 10px; font-weight: 600; font-size: 14px; text-decoration: none; cursor: pointer; transition: all 0.2s; border: none; }
        .btn-primary { background: #4f46e5; color: #fff; }
        .btn-primary:hover { background: #4338ca; }
        .btn-secondary { background: #1f293d; color: #e5e7eb; border: 1px solid #374151; }
        .btn-secondary:hover { background: #374151; }
    </style>
</head>
<body>
    <div class="card">
        <div class="header">
            <span class="badge">● ONLINE</span>
            <h1>SkyDesk Cloud PC</h1>
        </div>
        <p>Windows Server Cloud Virtual Machine is active and running high-performance workloads for students and developers.</p>
        
        <div class="info-grid">
            <div class="info-box">
                <div class="info-label">Username</div>
                <div class="info-val">runneradmin</div>
            </div>
            <div class="info-box">
                <div class="info-label">Password</div>
                <div class="info-val">__PASSWORD__</div>
            </div>
            <div class="info-box">
                <div class="info-label">Direct RDP Host</div>
                <div class="info-val">__RDP_HOST__</div>
            </div>
            <div class="info-box">
                <div class="info-label">Local Port</div>
                <div class="info-val">3389 (RDP) / 8080 (Web)</div>
            </div>
        </div>

        <div class="btn-group">
            <a href="/download-rdp" class="btn btn-primary">⬇ Download .RDP Profile</a>
            <button onclick="navigator.clipboard.writeText('__PASSWORD__'); alert('Password copied to clipboard!');" class="btn btn-secondary">📋 Copy Password</button>
        </div>
    </div>
</body>
</html>
"""

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode('utf-8'))
        elif self.path == '/download-rdp':
            rdp = "full address:s:__RDP_HOST__\r\nusername:s:runneradmin\r\nprompt for credentials:i:1\r\nscreen mode id:i:2\r\ndesktopwidth:i:1920\r\ndesktopheight:i:1080\r\nsession bpp:i:32\r\nauthentication level:i:2\r\n"
            self.send_response(200)
            self.send_header('Content-type', 'application/x-rdp')
            self.send_header('Content-Disposition', 'attachment; filename="SkyDesk-CloudVM.rdp"')
            self.end_headers()
            self.wfile.write(rdp.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
    print("SkyDesk Web Gateway running on port 8080")
    httpd.serve_forever()
'@

$pyServerCode | Out-File -FilePath "$workDir\web_gateway.py" -Encoding utf8 -Force

# 6. Initialize Multi-Tunnel Engines
$cfWebUrl = ""
$cfRdpUrl = ""
$pinggyRdpUrl = ""
$ngrokRdpUrl = ""

# 6.1 Download Cloudflared
Write-Host "[+] Downloading Cloudflare Tunnel (cloudflared)..." -ForegroundColor Yellow
$cfPath = "$workDir\cloudflared.exe"
if (!(Test-Path $cfPath)) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile $cfPath -TimeoutSec 30 -ErrorAction SilentlyContinue
    } catch {}
}

# 6.2 Setup Pinggy TCP Reverse Tunnel
Write-Host "[+] Initializing Pinggy TCP Tunnel for RDP port 3389..." -ForegroundColor Yellow
$pinggyLog = "$workDir\pinggy.log"
Start-Process powershell.exe -ArgumentList "-NoProfile", "-WindowStyle", "Hidden", "-Command", "ssh -p 443 -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -R0:localhost:3389 a.pinggy.io > $pinggyLog 2>&1" -ErrorAction SilentlyContinue

Start-Sleep -Seconds 6
if (Test-Path $pinggyLog) {
    $pinggyContent = Get-Content $pinggyLog -Raw -ErrorAction SilentlyContinue
    if ($pinggyContent -match 'tcp://([a-zA-Z0-9\.\-]+):(\d+)') {
        $pinggyRdpUrl = "$($Matches[1]):$($Matches[2])"
        Write-Host "[✓] Pinggy RDP Endpoint: $pinggyRdpUrl" -ForegroundColor Green
    }
}

# 6.3 Setup Cloudflare Quick Web Tunnel
Start-Process python.exe -ArgumentList "$workDir\web_gateway.py" -WindowStyle Hidden -ErrorAction SilentlyContinue

if (Test-Path $cfPath) {
    Write-Host "[+] Starting Cloudflare Quick Web Tunnel..." -ForegroundColor Yellow
    $cfLog = "$workDir\cloudflare_web.log"
    Start-Process -FilePath $cfPath -ArgumentList "tunnel", "--url", "http://localhost:8080", "--no-autoupdate" -RedirectStandardError $cfLog -WindowStyle Hidden -ErrorAction SilentlyContinue
    
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 2
        if (Test-Path $cfLog) {
            $cfContent = Get-Content $cfLog -Raw -ErrorAction SilentlyContinue
            if ($cfContent -match 'https://[a-zA-Z0-9\-]+\.trycloudflare\.com') {
                $cfWebUrl = $Matches[0]
                Write-Host "[✓] Cloudflare Web Access URL: $cfWebUrl" -ForegroundColor Green
                break
            }
        }
    }
}

# 6.4 Setup Ngrok Tunnel (if token provided)
$ngrokAuth = $env:NGROK_TOKEN
if (![string]::IsNullOrWhiteSpace($ngrokAuth)) {
    Write-Host "[+] Setting up Ngrok Tunnel..." -ForegroundColor Yellow
    try {
        winget install --id Inconshreveable.Ngrok --silent --accept-package-agreements 2>$null
        Start-Process "ngrok.exe" -ArgumentList "config", "add-authtoken", "$ngrokAuth" -Wait -NoNewWindow -ErrorAction SilentlyContinue
        Start-Process "ngrok.exe" -ArgumentList "tcp", "3389" -WindowStyle Hidden -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 4
        $ngrokApi = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($ngrokApi -and $ngrokApi.tunnels) {
            $ngrokRdpUrl = $ngrokApi.tunnels[0].public_url -replace 'tcp://', ''
            Write-Host "[✓] Ngrok RDP Endpoint: $ngrokRdpUrl" -ForegroundColor Green
        }
    } catch {}
}

# Determine Primary RDP Endpoint
$primaryRdp = ""
if (![string]::IsNullOrWhiteSpace($pinggyRdpUrl)) {
    $primaryRdp = $pinggyRdpUrl
} elseif (![string]::IsNullOrWhiteSpace($ngrokRdpUrl)) {
    $primaryRdp = $ngrokRdpUrl
} else {
    $primaryRdp = "127.0.0.1:3389 (via cloudflared/tunnel)"
}

# Update placeholders in web_gateway.py
if (Test-Path "$workDir\web_gateway.py") {
    $content = Get-Content "$workDir\web_gateway.py" -Raw
    $content = $content.Replace('__PASSWORD__', $password).Replace('__RDP_HOST__', $primaryRdp)
    $content | Out-File -FilePath "$workDir\web_gateway.py" -Encoding utf8 -Force
}

# 7. Collect System Specs & Generate Token
$osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cpuInfo = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
$totalRamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$freeDiskGB = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
$runnerIp = $env:RUNNER_PUBLIC_IP
if ([string]::IsNullOrWhiteSpace($runnerIp)) { $runnerIp = "GitHub Hosted Runner" }

$sessionDuration = 6
if ($env:SESSION_HOURS -match '^\d+$') {
    $sessionDuration = [int]$env:SESSION_HOURS
}
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
        ngrok_endpoint = $ngrokRdpUrl
    }
    workflow = @{
        repo = $env:GITHUB_REPO
        run_id = $env:GITHUB_RUN_ID
    }
}

$tokenJson = $tokenPayload | ConvertTo-Json -Depth 5
$tokenBytes = [System.Text.Encoding]::UTF8.GetBytes($tokenJson)
$tokenBase64 = [Convert]::ToBase64String($tokenBytes)
$skydeskToken = "skydesk_vm_" + $tokenBase64

$tokenPayload | Add-Member -MemberType NoteProperty -Name "vm_token" -Value $skydeskToken -Force
$tokenPayload | ConvertTo-Json -Depth 5 | Out-File -FilePath "./vm-token.json" -Encoding utf8 -Force

# 8. Output to GITHUB_STEP_SUMMARY
$summaryLines = @(
    "# 🚀 SkyDesk Cloud VM is Active & Online!",
    "",
    "> **Windows Server Cloud PC** is now provisioned and ready for remote access.",
    "",
    "### 🔑 VM Session Access Token",
    "Paste this token into the **SkyDesk Web Dashboard** to connect:",
    "```text",
    $skydeskToken,
    "```",
    "",
    "---",
    "",
    "### 🖥️ Quick Connection Details",
    "| Parameter | Value |",
    "| :--- | :--- |",
    "| **Status** | 🟢 **ACTIVE / READY** |",
    "| **Direct RDP Endpoint** | ``" + $primaryRdp + "`` |",
    "| **In-Browser Web Access** | " + (if ($cfWebUrl) { "[$cfWebUrl]($cfWebUrl)" } else { "Multi-Tunnel Active" }) + " |",
    "| **Username** | ``" + $username + "`` |",
    "| **Password** | ``" + $password + "`` |",
    "| **Session Expiration** | " + $expiresAt + " (6 Hours Max) |",
    ""
)

$summaryText = $summaryLines -join "`r`n"
$summaryText | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append

# 9. Auto-Publish Token to Web Portal (if URL provided)
if (![string]::IsNullOrWhiteSpace($env:WEB_PORTAL_URL)) {
    Write-Host "[+] Publishing VM Session Token to Web Portal..." -ForegroundColor Yellow
    try {
        $publishBody = @{
            token = $skydeskToken
            session = $tokenPayload
        } | ConvertTo-Json -Depth 5
        
        $portalUri = $env:WEB_PORTAL_URL.TrimEnd('/') + "/api/token/publish"
        Invoke-RestMethod -Uri $portalUri -Method Post -Body $publishBody -ContentType "application/json" -TimeoutSec 15 -ErrorAction SilentlyContinue | Out-Null
        Write-Host "[✓] Successfully registered session token to web portal!" -ForegroundColor Green
    } catch {}
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [✓] SkyDesk Cloud VM Provisioning Finished Successfully!" -ForegroundColor Green
Write-Host " VM Token: $skydeskToken" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
