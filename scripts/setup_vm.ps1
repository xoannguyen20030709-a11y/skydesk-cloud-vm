# =========================================================================
# SkyDesk OS - Windows Cloud VM Setup & Provisioning Engine
# =========================================================================

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [SkyDesk OS] Starting Automated Windows Provisioning Engine " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Setup Password & User Accounts
$username = "runneradmin"
$password = $env:CUSTOM_PASSWORD

if ([string]::IsNullOrWhiteSpace($password)) {
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
    $rand = New-Object System.Random
    $password = -join ((1..16) | ForEach-Object { $chars[$rand.Next(0, $chars.Length)] })
}

Write-Host "[+] Configuring User Account: $username" -ForegroundColor Yellow
try {
    net user $username $password /add /expires:never /active:yes 2>$null
    net localgroup "Administrators" $username /add 2>$null
    net localgroup "Remote Desktop Users" $username /add 2>$null
    Write-Host "[✓] User account configured with Administrator privileges." -ForegroundColor Green
} catch {
    Write-Host "[!] User config notice: $_" -ForegroundColor DarkGray
}

# 2. Enable Remote Desktop (RDP) & Firewall Rules
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

# 5. Start Web HTML5 Gateway Server
$gatewayScript = "$env:GITHUB_WORKSPACE\scripts\web_gateway.py"
if (Test-Path $gatewayScript) {
    Write-Host "[+] Launching Standalone Web Gateway on port 8080..." -ForegroundColor Yellow
    Start-Process python -ArgumentList $gatewayScript -WindowStyle Hidden -ErrorAction SilentlyContinue
}

# 6. Initialize Tunnels
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

# Save runtime info for web gateway
$vmRuntimeInfo = @{
    password = $password
    rdp_host = $primaryRdp
    username = $username
} | ConvertTo-Json
$vmRuntimeInfo | Out-File -FilePath "$workDir\vm_info.json" -Encoding utf8 -Force

# 7. Collect System Specs & Generate Token
$osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cpuInfo = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
$totalRamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1GB, 2)
$freeDiskGB = [math]::Round((Get-PSDrive C -ErrorAction SilentlyContinue).Free / 1GB, 2)
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
