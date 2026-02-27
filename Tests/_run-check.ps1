$r = Invoke-Pester -Path './Tests' -PassThru -Output None
foreach ($f in $r.Failed) {
    Write-Host "FAIL: $($f.ExpandedPath)"
    Write-Host "  ERR: $($f.ErrorRecord.Exception.Message)"
}
Write-Host "Passed: $($r.PassedCount) Failed: $($r.FailedCount) Skipped: $($r.SkippedCount)"
