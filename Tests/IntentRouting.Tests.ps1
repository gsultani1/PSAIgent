# ===== IntentRouting.Tests.ps1 =====
# Critical path 6: NL command → safety checks → execution

BeforeAll {
    . "$PSScriptRoot\_Bootstrap.ps1"
}

AfterAll {
    Remove-TestTempRoot
}

Describe 'Intent Routing — Offline' {

    Context 'Intent Lookup' {
        It 'Routes a known intent successfully' {
            $result = Invoke-IntentAction -Intent 'list_files' -AutoConfirm
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
        }

        It 'Rejects an unknown intent' {
            $result = Invoke-IntentAction -Intent 'nonexistent_intent_xyz' -AutoConfirm
            $result.Success | Should -BeFalse
            $result.Reason | Should -Be 'IntentNotFound'
        }
    }

    Context 'Parameter Validation' {
        It 'Rejects missing required parameters' {
            $result = Invoke-IntentAction -Intent 'web_search' -AutoConfirm
            $result.Success | Should -BeFalse
            $result.Reason | Should -Be 'MissingParameters'
        }

        It 'Rejects unknown parameters' {
            $result = Invoke-IntentAction -Intent 'web_search' -Payload @{ query = 'test'; bogus = 'x' } -AutoConfirm
            $result.Success | Should -BeFalse
            $result.Reason | Should -Be 'UnknownParameters'
        }

        It 'Accepts valid parameters via Payload' {
            $result = Invoke-IntentAction -Intent 'clipboard_read' -AutoConfirm
            $result | Should -Not -BeNullOrEmpty
            # clipboard_read has no required params, should execute
        }
    }

    Context 'Safety Tier Enforcement' {
        It 'RequiresConfirmation intent prompts even with AutoConfirm' {
            # run_code has Safety = RequiresConfirmation
            # Mock Read-Host to return 'no' so it cancels
            Mock Read-Host { return 'no' }
            $result = Invoke-IntentAction -Intent 'run_code' -Payload @{ code = 'echo hi'; language = 'powershell' } -AutoConfirm
            $result.Success | Should -BeFalse
            $result.Reason | Should -Be 'UserCancelled'
        }

        It 'RequiresConfirmation proceeds when user confirms' {
            Mock Read-Host { return 'yes' }
            $result = Invoke-IntentAction -Intent 'run_code' -Payload @{ code = 'Write-Output "hello"'; language = 'powershell' }
            $result.Success | Should -BeTrue
        }

        It 'Force flag bypasses confirmation' {
            $result = Invoke-IntentAction -Intent 'list_files' -Force
            $result.Success | Should -BeTrue
        }
    }

    Context 'Result Structure' {
        It 'Returns required fields' {
            $result = Invoke-IntentAction -Intent 'list_files' -AutoConfirm
            $result.Keys | Should -Contain 'Success'
            $result.Keys | Should -Contain 'IntentId'
            $result.Keys | Should -Contain 'ExecutionTime'
        }

        It 'ExecutionTime is a positive number' {
            $result = Invoke-IntentAction -Intent 'list_files' -AutoConfirm
            $result.ExecutionTime | Should -BeGreaterOrEqual 0
        }
    }
}

Describe 'Command Validation — Offline' {

    Context 'Whitelist Check' {
        It 'Validates a whitelisted read-only command' {
            $v = Test-PowerShellCommand 'Get-Process'
            $v.IsValid | Should -BeTrue
            $v.SafetyLevel | Should -Be 'ReadOnly'
        }

        It 'Rejects a non-whitelisted command' {
            $v = Test-PowerShellCommand 'format'
            $v.IsValid | Should -BeFalse
        }
    }

    Context 'Invoke-AIExec' {
        It 'Executes a whitelisted read-only command with AutoConfirm' {
            $result = Invoke-AIExec -Command 'Get-Date' -AutoConfirm
            $result.Success | Should -BeTrue
            $result.Output | Should -Not -BeNullOrEmpty
        }

        It 'Rejects a non-whitelisted command' {
            $result = Invoke-AIExec -Command 'Invoke-WebRequest http://evil.com' -AutoConfirm
            $result.Success | Should -BeFalse
        }

        It 'DryRun flag prevents actual execution' {
            $result = Invoke-AIExec -Command 'Get-Date' -DryRun
            $result.Success | Should -BeTrue
            $result.DryRun | Should -BeTrue
        }
    }

    Context 'Confirmation Prompt' {
        It 'Show-CommandConfirmation returns true for ReadOnly' {
            $result = Show-CommandConfirmation -Command 'Get-Process' -SafetyLevel 'ReadOnly'
            $result | Should -BeTrue
        }

        It 'Show-CommandConfirmation prompts for RequiresConfirmation' {
            Mock Read-Host { return 'yes' }
            $result = Show-CommandConfirmation -Command 'Remove-Item' -SafetyLevel 'RequiresConfirmation'
            $result | Should -BeTrue
        }

        It 'Show-CommandConfirmation denies on no' {
            Mock Read-Host { return 'no' }
            $result = Show-CommandConfirmation -Command 'Remove-Item' -SafetyLevel 'RequiresConfirmation'
            $result | Should -BeFalse
        }
    }
}
