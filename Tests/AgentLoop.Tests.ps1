# ===== AgentLoop.Tests.ps1 =====
# Critical path 1: agent loop completing a multi-step task

BeforeAll {
    . "$PSScriptRoot\_Bootstrap.ps1" -SkipHeartbeat -SkipAppBuilder
}

AfterAll {
    Remove-TestTempRoot
}

Describe 'AgentLoop — Offline' {

    Context 'System Prompt Assembly' {
        It 'Get-AgentSystemPrompt returns a non-empty string' {
            $prompt = Get-AgentSystemPrompt
            $prompt | Should -Not -BeNullOrEmpty
            $prompt.Length | Should -BeGreaterThan 100
        }

        It 'Prompt contains TOOLS section' {
            $prompt = Get-AgentSystemPrompt
            $prompt | Should -Match 'TOOLS'
        }

        It 'Prompt contains INTENTS section' {
            $prompt = Get-AgentSystemPrompt
            $prompt | Should -Match 'INTENTS'
        }

        It 'Prompt contains RESPONSE FORMAT section' {
            $prompt = Get-AgentSystemPrompt
            $prompt | Should -Match 'RESPONSE FORMAT'
        }

        It 'Prompt lists all registered tools' {
            $prompt = Get-AgentSystemPrompt
            foreach ($toolName in $global:AgentTools.Keys) {
                $prompt | Should -Match $toolName
            }
        }

        It 'Working memory appears in prompt when populated' {
            $global:AgentMemory = @{ 'test_key' = 'test_value_123' }
            $prompt = Get-AgentSystemPrompt -Memory $global:AgentMemory
            $prompt | Should -Match 'test_key'
            $prompt | Should -Match 'test_value_123'
            $global:AgentMemory = @{}
        }

        It 'Empty memory shows placeholder text' {
            $global:AgentMemory = @{}
            $prompt = Get-AgentSystemPrompt -Memory $global:AgentMemory
            $prompt | Should -Match 'empty'
        }
    }

    Context 'Agent Tool Registry' {
        It 'AgentTools registry is populated' {
            $global:AgentTools.Count | Should -BeGreaterOrEqual 12
        }

        It 'Calculator tool is registered' {
            $global:AgentTools.Contains('calculator') | Should -BeTrue
        }

        It 'Store and recall tools exist for working memory' {
            $global:AgentTools.Contains('store') | Should -BeTrue
            $global:AgentTools.Contains('recall') | Should -BeTrue
        }

        It 'Invoke-AgentTool runs calculator correctly' {
            $result = Invoke-AgentTool -Name 'calculator' -Params @{ expression = '2 + 3' }
            $result.Success | Should -BeTrue
            $result.Output | Should -Match '5'
        }

        It 'Invoke-AgentTool runs datetime tool' {
            $result = Invoke-AgentTool -Name 'datetime' -Params @{}
            $result.Success | Should -BeTrue
            $result.Output | Should -Not -BeNullOrEmpty
        }

        It 'Invoke-AgentTool store/recall round-trips' {
            $global:AgentMemory = @{}
            Invoke-AgentTool -Name 'store' -Params @{ key = 'mykey'; value = 'myvalue' }
            $result = Invoke-AgentTool -Name 'recall' -Params @{ key = 'mykey' }
            $result.Success | Should -BeTrue
            $result.Output | Should -Be 'myvalue'
            $global:AgentMemory = @{}
        }

        It 'Invoke-AgentTool rejects unknown tool' {
            $result = Invoke-AgentTool -Name 'nonexistent_tool_xyz' -Params @{}
            $result.Success | Should -BeFalse
        }
    }

    Context 'Agent Configuration' {
        It 'AgentMaxSteps is a positive integer' {
            $global:AgentMaxSteps | Should -BeGreaterThan 0
        }

        It 'AgentMaxTokenBudget is set' {
            $global:AgentMaxTokenBudget | Should -BeGreaterThan 0
        }
    }

    Context 'Format-AgentObservation' {
        It 'Produces OBSERVATION format' {
            $obs = Format-AgentObservation -StepNumber 1 -MaxSteps 5 `
                -ActionName 'calculator' -ActionType 'tool' `
                -Result @{ Success = $true; Output = '42' }
            $obs | Should -Match 'OBSERVATION'
            $obs | Should -Match '1/5'
        }
    }

    Context 'Inspection Functions' {
        It 'Show-AgentSteps does not throw with no prior run' {
            $global:AgentLastResult = $null
            { Show-AgentSteps } | Should -Not -Throw
        }

        It 'Show-AgentMemory does not throw with empty memory' {
            $global:AgentMemory = @{}
            { Show-AgentMemory } | Should -Not -Throw
        }

        It 'Show-AgentPlan does not throw with no plan' {
            $global:AgentLastPlan = $null
            { Show-AgentPlan } | Should -Not -Throw
        }
    }
}

Describe 'AgentLoop — Live' -Tag 'Live' {

    Context 'Multi-Step Task' {
        BeforeAll {
            $script:HasProvider = $false
            if ($global:ChatProviders -and $global:DefaultChatProvider) {
                $cfg = $global:ChatProviders[$global:DefaultChatProvider]
                if ($cfg) { $script:HasProvider = $true }
            }
        }

        It 'Completes a calculator task with Success' -Skip:(-not $script:HasProvider) {
            $result = Invoke-AgentTask -Task 'What is 25 * 48 plus 100? Use the calculator tool.' -AutoConfirm -MaxSteps 5
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
            $result.Summary | Should -Match '1300'
            $result.StepCount | Should -BeGreaterOrEqual 1
        }

        It 'Result object has expected structure' -Skip:(-not $script:HasProvider) {
            $result = $global:AgentLastResult
            $result.Keys | Should -Contain 'Success'
            $result.Keys | Should -Contain 'Summary'
            $result.Keys | Should -Contain 'Steps'
            $result.Keys | Should -Contain 'StepCount'
            $result.Keys | Should -Contain 'TotalTime'
            $result.Keys | Should -Contain 'Memory'
        }

        It 'Show-AgentSteps renders after a completed run' -Skip:(-not $script:HasProvider) {
            { Show-AgentSteps } | Should -Not -Throw
        }

        It 'Multi-tool task uses datetime and store' -Skip:(-not $script:HasProvider) {
            $result = Invoke-AgentTask -Task 'Get the current date and time using the datetime tool, then store the result in memory with key "current_time"' -AutoConfirm -MaxSteps 5
            $result.Success | Should -BeTrue
            $result.Memory.Keys | Should -Contain 'current_time'
        }
    }
}
