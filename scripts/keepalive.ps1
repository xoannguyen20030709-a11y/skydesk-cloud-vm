# SkyDesk OS - Session Heartbeat & Keepalive Engine (6 Hours)
$ErrorActionPreference = "Continue"

$sessionDurationHours = 6
if ($env:SESSION_HOURS -match '^d+$') { $sessionDurationHours = [int]$env:SESSION_HOURS }
$totalSeconds = $sessionDurationHours * 3600
if ($totalSeconds -gt 21300) { $totalSeconds = 21300 }

$startTime = Get-Date
$endTime = $startTime.AddSeconds($totalSeconds)
$interval = 60
$elapsedSeconds = 0

Write-Host "[SkyDesk Keepalive] Keeping Windows VM active for $sessionDurationHours hours..." -ForegroundColor Green

while ($elapsedSeconds -lt $totalSeconds) {
    Start-Sleep -Seconds $interval
    $elapsedSeconds = [int]((Get-Date) - $startTime).TotalSeconds
    $remainingSeconds = $totalSeconds - $elapsedSeconds
    $nowStr = (Get-Date).ToString("HH:mm:ss")
    $remMins = [math]::Floor($remainingSeconds / 60)
    Write-Host "[$nowStr] [HEARTBEAT] Time Remaining: $remMins minutes | Status: ONLINE | RDP Active" -ForegroundColor Cyan
    
    $rdpService = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
    if ($rdpService -and $rdpService.Status -ne 'Running') {
        Start-Service -Name "TermService" -ErrorAction SilentlyContinue
    }
}
