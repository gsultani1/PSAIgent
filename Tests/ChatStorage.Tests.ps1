# ===== ChatStorage.Tests.ps1 =====
# Critical path 3: FTS5 search returning results across sessions

BeforeAll {
    . "$PSScriptRoot\_Bootstrap.ps1"
}

AfterAll {
    Remove-TestTempRoot
}

Describe 'ChatStorage — Offline' {

    Context 'Database Initialization' {
        It 'Initialize-ChatDatabase returns true' {
            # DB was initialized during bootstrap via ChatStorage.ps1 load
            $global:ChatDbReady | Should -BeTrue
        }

        It 'Sessions table exists' {
            $conn = Get-ChatDbConnection
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name='sessions'"
            $result = $cmd.ExecuteScalar()
            $cmd.Dispose(); $conn.Close(); $conn.Dispose()
            $result | Should -Be 'sessions'
        }

        It 'Messages table exists' {
            $conn = Get-ChatDbConnection
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name='messages'"
            $result = $cmd.ExecuteScalar()
            $cmd.Dispose(); $conn.Close(); $conn.Dispose()
            $result | Should -Be 'messages'
        }

        It 'FTS5 virtual table exists' {
            $conn = Get-ChatDbConnection
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name='messages_fts'"
            $result = $cmd.ExecuteScalar()
            $cmd.Dispose(); $conn.Close(); $conn.Dispose()
            $result | Should -Be 'messages_fts'
        }

        It 'FTS triggers exist' {
            $conn = Get-ChatDbConnection
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND name LIKE 'messages_%'"
            $count = $cmd.ExecuteScalar()
            $cmd.Dispose(); $conn.Close(); $conn.Dispose()
            $count | Should -BeGreaterOrEqual 3
        }
    }

    Context 'CRUD Operations' {
        It 'Save-ChatToDb creates a session and returns an ID' {
            $messages = @(
                @{ role = 'user'; content = 'Hello world' }
                @{ role = 'assistant'; content = 'Hi there' }
            )
            $id = Save-ChatToDb -Name 'test-session-alpha' -Messages $messages -Provider 'ollama' -Model 'llama3'
            $id | Should -BeGreaterThan 0
        }

        It 'Get-ChatSessionsFromDb lists the saved session' {
            $sessions = Get-ChatSessionsFromDb
            $sessions.Count | Should -BeGreaterOrEqual 1
            $match = $sessions | Where-Object { $_.Name -eq 'test-session-alpha' }
            $match | Should -Not -BeNullOrEmpty
            $match.MessageCount | Should -Be 2
        }

        It 'Resume-ChatFromDb returns messages in order' {
            $session = Resume-ChatFromDb -Name 'test-session-alpha'
            $session | Should -Not -BeNullOrEmpty
            $session.Messages.Count | Should -Be 2
            $session.Messages[0].role | Should -Be 'user'
            $session.Messages[0].content | Should -Be 'Hello world'
            $session.Messages[1].role | Should -Be 'assistant'
        }

        It 'Rename-ChatSessionInDb renames the session' {
            $result = Rename-ChatSessionInDb -OldName 'test-session-alpha' -NewName 'test-session-renamed'
            $result | Should -BeTrue
            $session = Resume-ChatFromDb -Name 'test-session-renamed'
            $session | Should -Not -BeNullOrEmpty
            $session.Messages.Count | Should -Be 2
        }

        It 'Remove-ChatSessionFromDb deletes the session' {
            $result = Remove-ChatSessionFromDb -Name 'test-session-renamed'
            $result | Should -BeTrue
            $session = Resume-ChatFromDb -Name 'test-session-renamed'
            $session | Should -BeNullOrEmpty
        }
    }

    Context 'Cross-Session FTS5 Search' {
        BeforeAll {
            # Seed two sessions with distinct searchable content
            $msgs1 = @(
                @{ role = 'user'; content = 'Tell me about quantum entanglement in physics' }
                @{ role = 'assistant'; content = 'Quantum entanglement is a phenomenon where particles become correlated' }
            )
            $msgs2 = @(
                @{ role = 'user'; content = 'Explain quantum computing basics' }
                @{ role = 'assistant'; content = 'Quantum computing uses qubits that leverage superposition and entanglement' }
            )
            $msgs3 = @(
                @{ role = 'user'; content = 'What is the weather today?' }
                @{ role = 'assistant'; content = 'I cannot check live weather data.' }
            )
            Save-ChatToDb -Name 'fts-session-physics' -Messages $msgs1
            Save-ChatToDb -Name 'fts-session-computing' -Messages $msgs2
            Save-ChatToDb -Name 'fts-session-weather' -Messages $msgs3
        }

        It 'FTS5 search for "quantum" returns results from both sessions' {
            $results = Search-ChatFTS -Query 'quantum'
            $results.Count | Should -BeGreaterOrEqual 2
            $sessionNames = $results | ForEach-Object { $_.SessionName } | Sort-Object -Unique
            $sessionNames | Should -Contain 'fts-session-physics'
            $sessionNames | Should -Contain 'fts-session-computing'
        }

        It 'FTS5 results include expected fields' {
            $results = Search-ChatFTS -Query 'quantum'
            $first = $results[0]
            $first.Keys | Should -Contain 'SessionName'
            $first.Keys | Should -Contain 'Role'
            $first.Keys | Should -Contain 'Snippet'
            $first.Keys | Should -Contain 'Timestamp'
            $first.Keys | Should -Contain 'SessionId'
        }

        It 'FTS5 search for "weather" returns only the weather session' {
            $results = Search-ChatFTS -Query 'weather'
            $results.Count | Should -BeGreaterOrEqual 1
            $sessionNames = $results | ForEach-Object { $_.SessionName } | Sort-Object -Unique
            $sessionNames | Should -Contain 'fts-session-weather'
            $sessionNames | Should -Not -Contain 'fts-session-physics'
        }

        It 'FTS5 search respects Limit parameter' {
            $limited = Search-ChatFTS -Query 'quantum' -Limit 1
            @($limited).Count | Should -Be 1
        }

        It 'Deleting a session removes its messages from FTS' {
            Remove-ChatSessionFromDb -Name 'fts-session-physics'
            $results = Search-ChatFTS -Query 'entanglement'
            # Only computing session has "entanglement" now
            $sessionNames = $results | ForEach-Object { $_.SessionName } | Sort-Object -Unique
            $sessionNames | Should -Not -Contain 'fts-session-physics'
        }
    }

    Context 'Export' {
        It 'Export-ChatSessionFromDb writes a markdown file' {
            $outPath = Join-Path $global:TestTempRoot 'export-test.md'
            $result = Export-ChatSessionFromDb -Name 'fts-session-computing' -OutputPath $outPath
            $result | Should -Not -BeNullOrEmpty
            Test-Path $outPath | Should -BeTrue
            $content = Get-Content $outPath -Raw
            $content | Should -Match 'quantum computing'
        }
    }
}
