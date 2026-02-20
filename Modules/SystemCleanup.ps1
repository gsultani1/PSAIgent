# ===== SystemCleanup.ps1 =====
# System cleanup and maintenance utility
# Safe to dot-source — nothing runs on load

function Invoke-SystemCleanup {
    <#
    .SYNOPSIS
    Run system cleanup: flush DNS, restart Explorer, clear UWP brokers, trigger idle tasks
    
    .PARAMETER Force
    Skip confirmation prompt
    
    .EXAMPLE
    Invoke-SystemCleanup
    Invoke-SystemCleanup -Force
    cleanup
    #>
    param([switch]$Force)

    if (-not $Force) {
        Write-Host "`nSystem Cleanup will:" -ForegroundColor Yellow
        Write-Host "  1. Flush DNS cache" -ForegroundColor Gray
        Write-Host "  2. Restart Explorer (desktop will flicker)" -ForegroundColor Gray
        Write-Host "  3. Stop RuntimeBroker and SearchHost" -ForegroundColor Gray
        Write-Host "  4. Trigger Windows idle maintenance tasks" -ForegroundColor Gray
        $response = Read-Host "`nProceed? (y/n)"
        if ($response -notin @('y', 'yes', 'Y', 'YES')) {
            Write-Host "Cancelled." -ForegroundColor Yellow
            return @{ Success = $false; Output = "Cancelled by user" }
        }
    }

    Write-Host "Flushing DNS cache..." -ForegroundColor Cyan
    ipconfig /flushdns

    Write-Host "Restarting Explorer..." -ForegroundColor Cyan
    Stop-Process -Name explorer -Force
    Start-Process explorer.exe -WorkingDirectory $env:windir

    Write-Host "Stopping RuntimeBroker and SearchHost..." -ForegroundColor Cyan
    Get-Process -Name RuntimeBroker,SearchHost -ErrorAction SilentlyContinue | Stop-Process -Force

    Write-Host "Triggering idle maintenance tasks..." -ForegroundColor Cyan
    Start-Process -FilePath "C:\Windows\System32\rundll32.exe" -ArgumentList "advapi32.dll,ProcessIdleTasks"

    Write-Host "System cleanup complete." -ForegroundColor Green
    return @{ Success = $true; Output = "System cleanup completed" }
}

Set-Alias cleanup Invoke-SystemCleanup -Force
