# =========================================================================
# SkyDesk OS - Session Heartbeat & Keepalive Engine (6 Hours)
# =========================================================================

$ErrorActionPreference = "Continue"

$sessionHours = 6
if ($env:SESSION_HOURS -match '^\d+$') {
    $sessionHours = [int]$env:SESSION_HOURS
}

$totalSeconds = $sessionHours * 3600
# GitHub Actions runner limit is 360 minutes (6h). Reserve 5 minutes for clean artifact upload
if ($totalSeconds -gt 21300) { $totalSeconds = 21300 }

$startTime = Get-Date
$endTime = $startTime.AddSeconds($totalSeconds)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [SkyDesk Keepalive Engine] Session Active for $sessionHours Hours" -ForegroundColor Green
Write-Host " Started at: $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) UTC" -ForegroundColor Yellow
Write-Host " Will close at: $($endTime.ToString('yyyy-MM-dd HH:mm:ss')) UTC" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

$interval = 60
$elapsedSeconds = 0

while ($elapsedSeconds -lt $totalSeconds) {
    Start-Sleep -Seconds $interval
    $elapsedSeconds = [int]((Get-Date) - $startTime).TotalSeconds
    $remainingSeconds = $totalSeconds - $elapsedSeconds
    
    $elapsedHours = [math]::Floor($elapsedSeconds / 3600)
    $elapsedMins = [math]::Floor(($elapsedSeconds % 3600) / 60)
    
    $remHours = [math]::Floor($remainingSeconds / 3600)
    $remMins = [math]::Floor(($remainingSeconds % 3600) / 60)
    
    $nowStr = (Get-Date).ToString("HH:mm:ss")
    Write-Host "[$nowStr] [HEARTBEAT] Elapsed: ${elapsedHours}h ${elapsedMins}m | Remaining: ${remHours}h ${remMins}m | Status: ONLINE | RDP Port 3389 Active" -ForegroundColor Cyan
    
    # Check TermService
    $rdpService = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
    if ($rdpService -and $rdpService.Status -ne 'Running') {
        Start-Service -Name "TermService" -ErrorAction SilentlyContinue
    }
}

Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host " [SkyDesk Keepalive Engine] Session Completed." -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Yellow
