# ===== AgentHeartbeat.Tests.ps1 =====
# Critical path 4: heartbeat evaluating and executing a scheduled task

BeforeAll {
    . "$PSScriptRoot\_Bootstrap.ps1"
    # Point heartbeat to temp paths
    $global:HeartbeatTasksPath = Join-Path $global:TestTempRoot 'config\agent-tasks.json'
    $global:HeartbeatLogPath = Join-Path $global:TestTempRoot 'logs\heartbeat.log'
}

AfterAll {
    Remove-TestTempRoot
}

Describe 'AgentHeartbeat — Offline' {

    Context 'Task CRUD' {
        It 'Get-AgentTaskList returns empty array when no file exists' {
            if (Test-Path $global:HeartbeatTasksPath) { Remove-Item $global:HeartbeatTasksPath -Force }
            $tasks = Get-AgentTaskList
            $tasks.Count | Should -Be 0
        }

        It 'Add-AgentTask creates a task entry' {
            Add-AgentTask -Id 'test-daily' -Task 'summarize git changes' -Schedule 'daily' -Time '09:00'
            $tasks = Get-AgentTaskList
            $tasks.Count | Should -Be 1
            $tasks[0].id | Should -Be 'test-daily'
            $tasks[0].schedule | Should -Be 'daily'
            $tasks[0].time | Should -Be '09:00'
            $tasks[0].enabled | Should -BeTrue
            $tasks[0].lastRun | Should -BeNullOrEmpty
        }

        It 'Rejects duplicate task ID' {
            # Should warn but not crash
            Add-AgentTask -Id 'test-daily' -Task 'duplicate' -Schedule 'daily' -Time '10:00'
            $tasks = Get-AgentTaskList
            $tasks.Count | Should -Be 1
        }

        It 'Add-AgentTask adds a second task' {
            Add-AgentTask -Id 'test-interval' -Task 'check disk space' -Schedule 'interval' -Interval '30m'
            $tasks = Get-AgentTaskList
            $tasks.Count | Should -Be 2
        }

        It 'Disable-AgentTask sets enabled to false' {
            Disable-AgentTask -Id 'test-daily'
            $tasks = Get-AgentTaskList
            $target = $tasks | Where-Object { $_.id -eq 'test-daily' }
            $target.enabled | Should -BeFalse
        }

        It 'Enable-AgentTask sets enabled back to true' {
            Enable-AgentTask -Id 'test-daily'
            $tasks = Get-AgentTaskList
            $target = $tasks | Where-Object { $_.id -eq 'test-daily' }
            $target.enabled | Should -BeTrue
        }

        It 'Remove-AgentTask removes by ID' {
            Remove-AgentTask -Id 'test-interval'
            $tasks = Get-AgentTaskList
            $tasks.Count | Should -Be 1
            ($tasks | Where-Object { $_.id -eq 'test-interval' }) | Should -BeNullOrEmpty
        }

        It 'Show-AgentTaskList does not throw' {
            { Show-AgentTaskList } | Should -Not -Throw
        }
    }

    Context 'Input Validation' {
        BeforeAll {
            # Clean task file for validation tests
            if (Test-Path $global:HeartbeatTasksPath) { Remove-Item $global:HeartbeatTasksPath -Force }
        }

        It 'Rejects invalid time format' {
            Add-AgentTask -Id 'bad-time' -Task 'test' -Schedule 'daily' -Time '25:99'
            $tasks = Get-AgentTaskList
            ($tasks | Where-Object { $_.id -eq 'bad-time' }) | Should -BeNullOrEmpty
        }

        It 'Rejects interval schedule without -Interval parameter' {
            Add-AgentTask -Id 'no-interval' -Task 'test' -Schedule 'interval'
            $tasks = Get-AgentTaskList
            ($tasks | Where-Object { $_.id -eq 'no-interval' }) | Should -BeNullOrEmpty
        }

        It 'Rejects invalid interval syntax' {
            Add-AgentTask -Id 'bad-interval' -Task 'test' -Schedule 'interval' -Interval 'xyz'
            $tasks = Get-AgentTaskList
            ($tasks | Where-Object { $_.id -eq 'bad-interval' }) | Should -BeNullOrEmpty
        }

        It 'Accepts valid interval with d unit' {
            Add-AgentTask -Id 'daily-interval' -Task 'test' -Schedule 'interval' -Interval '1d'
            $tasks = Get-AgentTaskList
            ($tasks | Where-Object { $_.id -eq 'daily-interval' }) | Should -Not -BeNullOrEmpty
        }

        It 'Rejects invalid day names for weekly schedule' {
            Add-AgentTask -Id 'bad-day' -Task 'test' -Schedule 'weekly' -Days 'Moonday'
            $tasks = Get-AgentTaskList
            ($tasks | Where-Object { $_.id -eq 'bad-day' }) | Should -BeNullOrEmpty
        }

        It 'Accepts full day names for weekly schedule' {
            Add-AgentTask -Id 'full-day' -Task 'test' -Schedule 'weekly' -Days 'Monday,Friday'
            $tasks = Get-AgentTaskList
            ($tasks | Where-Object { $_.id -eq 'full-day' }) | Should -Not -BeNullOrEmpty
        }

        AfterAll {
            if (Test-Path $global:HeartbeatTasksPath) { Remove-Item $global:HeartbeatTasksPath -Force }
        }
    }

    Context 'Atomic Save (Save-AgentTaskList)' {
        It 'Does not leave a .tmp file after saving' {
            Add-AgentTask -Id 'atomic-test' -Task 'test atomic write' -Schedule 'daily' -Time '08:00'
            $tmpPath = "$global:HeartbeatTasksPath.tmp"
            Test-Path $tmpPath | Should -BeFalse
            Test-Path $global:HeartbeatTasksPath | Should -BeTrue
        }

        It 'Task file content is valid JSON after save' {
            $raw = Get-Content $global:HeartbeatTasksPath -Raw
            { $raw | ConvertFrom-Json } | Should -Not -Throw
        }

        AfterAll {
            if (Test-Path $global:HeartbeatTasksPath) { Remove-Item $global:HeartbeatTasksPath -Force }
        }
    }

    Context 'Test-TaskDue Schedule Logic' {
        It 'Daily task with null lastRun is due' {
            $task = [pscustomobject]@{ enabled = $true; schedule = 'daily'; time = '00:00'; lastRun = $null }
            Test-TaskDue -Task $task | Should -BeTrue
        }

        It 'Daily task run today is not due' {
            $task = [pscustomobject]@{ enabled = $true; schedule = 'daily'; time = '00:00'; lastRun = (Get-Date).ToString('o') }
            Test-TaskDue -Task $task | Should -BeFalse
        }

        It 'Daily task run yesterday with past target time is due' {
            $yesterday = (Get-Date).AddDays(-1).ToString('o')
            $task = [pscustomobject]@{ enabled = $true; schedule = 'daily'; time = '00:01'; lastRun = $yesterday }
            Test-TaskDue -Task $task | Should -BeTrue
        }

        It 'Interval task 30m with lastRun 45m ago is due' {
            $old = (Get-Date).AddMinutes(-45).ToString('o')
            $task = [pscustomobject]@{ enabled = $true; schedule = 'interval'; interval = '30m'; lastRun = $old }
            Test-TaskDue -Task $task | Should -BeTrue
        }

        It 'Interval task 30m with lastRun 10m ago is not due' {
            $recent = (Get-Date).AddMinutes(-10).ToString('o')
            $task = [pscustomobject]@{ enabled = $true; schedule = 'interval'; interval = '30m'; lastRun = $recent }
            Test-TaskDue -Task $task | Should -BeFalse
        }

        It 'Interval task with null lastRun is due' {
            $task = [pscustomobject]@{ enabled = $true; schedule = 'interval'; interval = '1h'; lastRun = $null }
            Test-TaskDue -Task $task | Should -BeTrue
        }

        It 'Interval task supports d unit (days)' {
            $old = (Get-Date).AddDays(-2).ToString('o')
            $task = [pscustomobject]@{ enabled = $true; schedule = 'interval'; interval = '1d'; lastRun = $old }
            Test-TaskDue -Task $task | Should -BeTrue
        }

        It 'Interval task with d unit not yet due' {
            $recent = (Get-Date).AddHours(-12).ToString('o')
            $task = [pscustomobject]@{ enabled = $true; schedule = 'interval'; interval = '1d'; lastRun = $recent }
            Test-TaskDue -Task $task | Should -BeFalse
        }

        It 'Weekly task on wrong day is not due (after first run)' {
            $today = (Get-Date).DayOfWeek.ToString().Substring(0, 3)
            # Pick a day that is NOT today
            $allDays = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')
            $wrongDay = $allDays | Where-Object { $_ -ne $today } | Select-Object -First 1
            # Set lastRun to yesterday so the "never run" early-return doesn't trigger
            $yesterday = (Get-Date).AddDays(-1).ToString('o')
            $task = [pscustomobject]@{ enabled = $true; schedule = 'weekly'; time = '00:01'; days = $wrongDay; lastRun = $yesterday }
            Test-TaskDue -Task $task | Should -BeFalse
        }

        It 'Weekly task accepts full day names (Monday, Friday)' {
            $today = (Get-Date).DayOfWeek.ToString()
            $yesterday = (Get-Date).AddDays(-1).ToString('o')
            $task = [pscustomobject]@{ enabled = $true; schedule = 'weekly'; time = '00:01'; days = $today; lastRun = $yesterday }
            Test-TaskDue -Task $task | Should -BeTrue
        }

        It 'Disabled task is never due' {
            $task = [pscustomobject]@{ enabled = $false; schedule = 'daily'; time = '00:00'; lastRun = $null }
            Test-TaskDue -Task $task | Should -BeFalse
        }
    }

    Context 'Day Name Normalization' {
        It 'Normalizes full day names to 3-letter abbreviations' {
            ConvertTo-NormalizedDayName 'Monday'    | Should -Be 'Mon'
            ConvertTo-NormalizedDayName 'Wednesday'  | Should -Be 'Wed'
            ConvertTo-NormalizedDayName 'Sunday'     | Should -Be 'Sun'
        }

        It 'Passes through already-abbreviated names' {
            ConvertTo-NormalizedDayName 'Mon' | Should -Be 'Mon'
            ConvertTo-NormalizedDayName 'Fri' | Should -Be 'Fri'
        }

        It 'Is case-insensitive' {
            ConvertTo-NormalizedDayName 'monday'    | Should -Be 'Mon'
            ConvertTo-NormalizedDayName 'FRIDAY'    | Should -Be 'Fri'
        }
    }

    Context 'Interval Parsing' {
        It 'Parses minutes correctly' {
            $ts = ConvertTo-TimeSpanFromInterval '30m'
            $ts.TotalMinutes | Should -Be 30
        }

        It 'Parses hours correctly' {
            $ts = ConvertTo-TimeSpanFromInterval '2h'
            $ts.TotalHours | Should -Be 2
        }

        It 'Parses days correctly' {
            $ts = ConvertTo-TimeSpanFromInterval '1d'
            $ts.TotalDays | Should -Be 1
        }

        It 'Parses seconds correctly' {
            $ts = ConvertTo-TimeSpanFromInterval '45s'
            $ts.TotalSeconds | Should -Be 45
        }

        It 'Returns $null for invalid interval' {
            ConvertTo-TimeSpanFromInterval 'bad'  | Should -BeNullOrEmpty
            ConvertTo-TimeSpanFromInterval '30x'  | Should -BeNullOrEmpty
            ConvertTo-TimeSpanFromInterval ''      | Should -BeNullOrEmpty
        }
    }

    Context 'Invoke-AgentHeartbeat (mocked)' {
        BeforeAll {
            if (Test-Path $global:HeartbeatTasksPath) { Remove-Item $global:HeartbeatTasksPath -Force }
        }

        It 'Returns zero counts when no tasks exist' {
            $result = Invoke-AgentHeartbeat
            $result.TasksChecked | Should -Be 0
            $result.TasksRun     | Should -Be 0
        }

        It 'Returns zero TasksRun when no tasks are due' {
            Add-AgentTask -Id 'not-due' -Task 'test' -Schedule 'interval' -Interval '24h'
            # Set lastRun to now so it won't be due
            $tasks = Get-AgentTaskList
            $tasks[0].lastRun = (Get-Date).ToString('o')
            Save-AgentTaskList -Tasks $tasks

            $result = Invoke-AgentHeartbeat
            $result.TasksChecked | Should -Be 1
            $result.TasksRun     | Should -Be 0
        }

        It 'Does not write log when nothing ran' {
            if (Test-Path $global:HeartbeatLogPath) { Remove-Item $global:HeartbeatLogPath -Force }
            # Task is not due from previous test
            $result = Invoke-AgentHeartbeat
            $result.TasksRun | Should -Be 0
            # Log should not be created when nothing ran
            Test-Path $global:HeartbeatLogPath | Should -BeFalse
        }

        AfterAll {
            if (Test-Path $global:HeartbeatTasksPath) { Remove-Item $global:HeartbeatTasksPath -Force }
            if (Test-Path $global:HeartbeatLogPath) { Remove-Item $global:HeartbeatLogPath -Force }
        }
    }
}

Describe 'AgentHeartbeat — Live' -Tag 'Live' {

    Context 'Invoke-AgentHeartbeat' {
        BeforeAll {
            $script:LiveProvider = Find-ReachableProvider
            $script:HasProvider = [bool]$script:LiveProvider
            # Reset task file for live test
            $global:HeartbeatTasksPath = Join-Path $global:TestTempRoot 'config\agent-tasks-live.json'
            $global:HeartbeatLogPath = Join-Path $global:TestTempRoot 'logs\heartbeat-live.log'
        }

        It 'Executes a forced heartbeat with a simple task' {
            if (-not $script:HasProvider) { Set-ItResult -Skipped -Because 'No LLM provider configured'; return }
            Add-AgentTask -Id 'live-math' -Task 'What is 2+2? Use the calculator tool.' -Schedule 'daily' -Time '00:00'
            $result = Invoke-AgentHeartbeat -Force
            $result.TasksChecked | Should -BeGreaterOrEqual 1
            $result.TasksRun | Should -BeGreaterOrEqual 1

            $tasks = Get-AgentTaskList
            $ran = $tasks | Where-Object { $_.id -eq 'live-math' }
            $ran.lastRun | Should -Not -BeNullOrEmpty
            $ran.lastResult | Should -Not -BeNullOrEmpty
        }

        It 'Heartbeat log file is written' {
            if (-not $script:HasProvider) { Set-ItResult -Skipped -Because 'No LLM provider configured'; return }
            Test-Path $global:HeartbeatLogPath | Should -BeTrue
            $content = Get-Content $global:HeartbeatLogPath -Raw
            $content | Should -Match 'Heartbeat'
        }
    }
}

Describe 'AgentHeartbeat — Admin' -Tag 'Admin' {

    Context 'Scheduled Task Registration' {
        It 'Register-AgentHeartbeat creates a scheduled task' {
            $result = Register-AgentHeartbeat -IntervalMinutes 60
            $result.Success | Should -BeTrue
            $task = Get-ScheduledTask -TaskName 'Heartbeat' -TaskPath '\BildsyPS\' -ErrorAction SilentlyContinue
            $task | Should -Not -BeNullOrEmpty
        }

        It 'Unregister-AgentHeartbeat removes the scheduled task' {
            $result = Unregister-AgentHeartbeat
            $result.Success | Should -BeTrue
            $task = Get-ScheduledTask -TaskName 'Heartbeat' -TaskPath '\BildsyPS\' -ErrorAction SilentlyContinue
            $task | Should -BeNullOrEmpty
        }
    }
}
