# ===== AppBuilder.Tests.ps1 =====
# Critical path 2: prompt → .exe

BeforeAll {
    . "$PSScriptRoot\_Bootstrap.ps1"
}

AfterAll {
    Remove-TestTempRoot
}

Describe 'AppBuilder — Offline' {

    Context 'Framework Routing (Get-BuildFramework)' {
        It 'Routes "a calculator" to powershell' {
            Get-BuildFramework -Prompt 'a calculator' | Should -Be 'powershell'
        }

        It 'Routes "a simple notepad" to powershell' {
            Get-BuildFramework -Prompt 'a simple notepad app' | Should -Be 'powershell'
        }

        It 'Routes "tkinter GUI" to python-tk' {
            Get-BuildFramework -Prompt 'a tkinter GUI for file management' | Should -Be 'python-tk'
        }

        It 'Routes "a dashboard with charts" to python-web' {
            Get-BuildFramework -Prompt 'a dashboard with charts and drag and drop' | Should -Be 'python-web'
        }

        It 'Routes "python app" to python-tk for simple prompts' {
            Get-BuildFramework -Prompt 'a python app that shows a timer' | Should -Be 'python-tk'
        }

        It 'Explicit -Framework override wins' {
            Get-BuildFramework -Prompt 'a dashboard with charts' -Framework 'python-tk' | Should -Be 'python-tk'
        }

        It 'Explicit -Framework powershell overrides python keywords' {
            Get-BuildFramework -Prompt 'a python calculator' -Framework 'powershell' | Should -Be 'powershell'
        }

        It 'Invalid framework falls through to keyword detection' {
            Get-BuildFramework -Prompt 'a calculator' -Framework 'invalid-framework' | Should -Be 'powershell'
        }
    }

    Context 'Token Budget (Get-BuildMaxTokens)' {
        It 'PowerShell lane caps at 16000' {
            $result = Get-BuildMaxTokens -Framework 'powershell' -Model 'gpt-4o'
            $result | Should -BeLessOrEqual 16000
        }

        It 'Python-web floor is 8192' {
            # Small model context (e.g. 8192) should floor at 8192
            $result = Get-BuildMaxTokens -Framework 'python-web' -Model 'llama3'
            $result | Should -BeGreaterOrEqual 8192
        }

        It 'PowerShell floor is 4096' {
            $result = Get-BuildMaxTokens -Framework 'powershell' -Model 'llama3'
            $result | Should -BeGreaterOrEqual 4096
        }

        It 'Override returns exact value' {
            $result = Get-BuildMaxTokens -Framework 'powershell' -Model 'gpt-4o' -Override 32000
            $result | Should -Be 32000
        }

        It 'Zero override uses auto-detection' {
            $result = Get-BuildMaxTokens -Framework 'powershell' -Model 'gpt-4o' -Override 0
            $result | Should -BeGreaterThan 0
            $result | Should -BeLessOrEqual 16000
        }
    }

    Context 'Code Validation (Test-GeneratedCode)' {
        It 'Accepts valid PowerShell code' {
            $files = @{ 'app.ps1' = 'Add-Type -AssemblyName System.Windows.Forms; Write-Host "hello"' }
            $result = Test-GeneratedCode -Files $files -Framework 'powershell'
            $result.Success | Should -BeTrue
            $result.Errors.Count | Should -Be 0
        }

        It 'Catches PowerShell syntax errors' {
            $files = @{ 'app.ps1' = 'function Broken { Write-Host "missing close"' }
            $result = Test-GeneratedCode -Files $files -Framework 'powershell'
            $result.Success | Should -BeFalse
            $result.Errors.Count | Should -BeGreaterThan 0
            $result.Errors[0] | Should -Match 'Syntax error'
        }

        It 'Flags Invoke-Expression as dangerous' {
            $files = @{ 'app.ps1' = 'Invoke-Expression "Get-Process"' }
            $result = Test-GeneratedCode -Files $files -Framework 'powershell'
            $result.Success | Should -BeFalse
            ($result.Errors -join '`n') | Should -Match 'Invoke-Expression'
        }

        It 'Flags iex alias as dangerous' {
            $files = @{ 'app.ps1' = '$cmd = "dir"; iex $cmd' }
            $result = Test-GeneratedCode -Files $files -Framework 'powershell'
            $result.Success | Should -BeFalse
        }

        It 'Flags eval() in Python code' {
            $files = @{ 'app.py' = 'x = eval("2+2")' }
            $result = Test-GeneratedCode -Files $files -Framework 'python-tk'
            $result.Success | Should -BeFalse
            ($result.Errors -join '`n') | Should -Match 'eval'
        }
    }

    Context 'Branding Injection (Invoke-ShelixBranding)' {
        It 'Injects branding into PowerShell file missing it' {
            $files = @{
                'app.ps1' = @'
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object System.Windows.Forms.Form
[System.Windows.Forms.Application]::Run($form)
'@
            }
            $result = Invoke-ShelixBranding -Files $files -Framework 'powershell'
            $result['app.ps1'] | Should -Match 'Built with Shelix'
        }

        It 'Does not double-inject branding' {
            $code = 'Add-Type -AssemblyName System.Windows.Forms; # Built with Shelix already here'
            $files = @{ 'app.ps1' = $code }
            $result = Invoke-ShelixBranding -Files $files -Framework 'powershell'
            $brandCount = [regex]::Matches($result['app.ps1'], 'Built with Shelix').Count
            $brandCount | Should -Be 1
        }

        It 'NoBranding flag skips injection' {
            $files = @{ 'app.ps1' = 'Write-Host "no branding"' }
            $result = Invoke-ShelixBranding -Files $files -Framework 'powershell' -NoBranding
            $result['app.ps1'] | Should -Not -Match 'Built with Shelix'
        }

        It 'Injects footer into python-web HTML' {
            $files = @{ 'web/index.html' = '<html><body><h1>App</h1></body></html>' }
            $result = Invoke-ShelixBranding -Files $files -Framework 'python-web'
            $result['web/index.html'] | Should -Match 'Built with Shelix'
        }

        It 'Injects about function into python-tk code' {
            $files = @{ 'app.py' = "import tkinter\nroot = tkinter.Tk()\nroot.mainloop()" }
            $result = Invoke-ShelixBranding -Files $files -Framework 'python-tk'
            $result['app.py'] | Should -Match 'Built with Shelix'
        }
    }

    Context 'Build Tracking (SQLite)' {
        It 'Initialize-BuildsTable creates the builds table' {
            if (-not $global:ChatDbReady) { Set-ItResult -Skipped -Because 'SQLite not available' }
            $result = Initialize-BuildsTable
            $result | Should -BeTrue
        }

        It 'Save-BuildRecord + Get-AppBuilds round-trip' {
            if (-not $global:ChatDbReady) { Set-ItResult -Skipped -Because 'SQLite not available' }
            Save-BuildRecord -Name 'test-app' -Framework 'powershell' -Prompt 'a test app' `
                -Status 'completed' -ExePath 'C:\fake\test-app.exe' -SourceDir 'C:\fake\source' `
                -Provider 'ollama' -Model 'llama3' -Branded $true -BuildTime 5.2

            $conn = Get-ChatDbConnection
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT name, framework, status FROM builds WHERE name = 'test-app'"
            $reader = $cmd.ExecuteReader()
            $found = $reader.Read()
            $found | Should -BeTrue
            $reader['name'] | Should -Be 'test-app'
            $reader['framework'] | Should -Be 'powershell'
            $reader['status'] | Should -Be 'completed'
            $reader.Close(); $cmd.Dispose(); $conn.Close(); $conn.Dispose()
        }

        It 'Remove-AppBuild clears the DB record' {
            if (-not $global:ChatDbReady) { Set-ItResult -Skipped -Because 'SQLite not available' }
            Remove-AppBuild -Name 'test-app'
            $conn = Get-ChatDbConnection
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT COUNT(*) FROM builds WHERE name = 'test-app'"
            $count = $cmd.ExecuteScalar()
            $cmd.Dispose(); $conn.Close(); $conn.Dispose()
            $count | Should -Be 0
        }
    }
}

Describe 'AppBuilder — Live' -Tag 'Live' {

    Context 'Full Build Pipeline' {
        BeforeAll {
            $script:HasProvider = $false
            if ($global:ChatProviders -and $global:DefaultChatProvider) {
                $cfg = $global:ChatProviders[$global:DefaultChatProvider]
                if ($cfg) { $script:HasProvider = $true }
            }
            $script:HasPs2exe = $null -ne (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue) -or
                                $null -ne (Get-Module -ListAvailable -Name ps2exe)
            $script:CanBuild = $script:HasProvider -and $script:HasPs2exe
        }

        It 'New-AppBuild generates a .exe from a simple prompt' -Skip:(-not $script:CanBuild) {
            $result = New-AppBuild -Prompt 'a simple counter app with plus and minus buttons' -Framework 'powershell' -Name 'test-counter'
            $result.Success | Should -BeTrue
            $result.ExePath | Should -Not -BeNullOrEmpty
            Test-Path $result.ExePath | Should -BeTrue
            $result.SourceDir | Should -Not -BeNullOrEmpty
            $result.Framework | Should -Be 'powershell'
            $result.AppName | Should -Be 'test-counter'
        }

        It 'Source code contains Shelix branding' -Skip:(-not $script:CanBuild) {
            $sourceFile = Join-Path $global:AppBuilderPath 'test-counter\source\app.ps1'
            if (Test-Path $sourceFile) {
                $content = Get-Content $sourceFile -Raw
                $content | Should -Match 'Built with Shelix'
            }
        }

        It 'Build record exists in SQLite' -Skip:(-not $script:CanBuild) {
            if (-not $global:ChatDbReady) { Set-ItResult -Skipped -Because 'SQLite not available' }
            $conn = Get-ChatDbConnection
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT status FROM builds WHERE name = 'test-counter' ORDER BY created_at DESC LIMIT 1"
            $status = $cmd.ExecuteScalar()
            $cmd.Dispose(); $conn.Close(); $conn.Dispose()
            $status | Should -Be 'completed'
        }

        AfterAll {
            if ($script:CanBuild) {
                Remove-AppBuild -Name 'test-counter' -ErrorAction SilentlyContinue
            }
        }
    }
}
