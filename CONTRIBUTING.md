# Contributing to PSAigent

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Issues
- Use GitHub Issues to report bugs or request features
- Include your PowerShell version (`$PSVersionTable.PSVersion`)
- Include error messages and steps to reproduce
- Specify which AI provider you're using (Ollama, Anthropic, OpenAI, etc.)

### Submitting Changes
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test on PowerShell 5.1 (for Windows compatibility)
5. Commit with clear messages (`git commit -m "Add: new intent for X"`)
6. Push to your fork (`git push origin feature/my-feature`)
7. Open a Pull Request

## Code Style

### PowerShell Guidelines
- Use approved PowerShell verbs (`Get-`, `Set-`, `New-`, `Invoke-`, etc.)
- Use PascalCase for function names and parameters
- Use `$camelCase` for local variables
- Add comment-based help for public functions
- Maintain PowerShell 5.1 compatibility

### Example Function
```powershell
function Get-ExampleData {
    <#
    .SYNOPSIS
    Brief description of what the function does
    
    .PARAMETER Name
    Description of the parameter
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    # Implementation
}
```

### Intent Guidelines
When adding new intents to `IntentAliasSystem.ps1`:
- Return a hashtable with `Success`, `Output`, and optionally `Error`
- Validate required parameters early
- Handle errors gracefully
- Keep intents focused on a single task

```powershell
"my_intent" = {
    param($requiredParam)
    if (-not $requiredParam) {
        return @{ Success = $false; Output = "Error: requiredParam is required"; Error = $true }
    }
    # Do work...
    @{ Success = $true; Output = "Result here" }
}
```

## Project Structure

```
├── Microsoft.PowerShell_profile.ps1  # Main entry point
├── ChatProviders.ps1                 # AI provider implementations
├── IntentAliasSystem.ps1             # Intent routing and definitions
├── Modules/
│   ├── SafetySystem.ps1              # Command validation
│   ├── TerminalTools.ps1             # External tool integration
│   ├── NavigationUtils.ps1           # Navigation helpers
│   ├── WebTools.ps1                  # Web search APIs
│   ├── ProductivityTools.ps1         # Clipboard, Git, Calendar
│   └── MCPClient.ps1                 # MCP protocol client
└── ChatConfig.json                   # User configuration (not tracked)
```

## Testing

Before submitting a PR:
1. Reload your profile: `. $PROFILE`
2. Test the chat function: `chat` or `chat-anthropic`
3. Test any new intents you've added
4. Verify existing functionality still works

## Adding New Features

### New AI Provider
1. Add provider config to `$global:ChatProviders` in `ChatProviders.ps1`
2. Implement API handler if format differs from OpenAI/Anthropic
3. Add to README documentation
4. Test with `Test-ChatProvider <name>`

### New Intent
1. Add to `$global:IntentAliases` in `IntentAliasSystem.ps1`
2. Add metadata to `$global:IntentMetadata` if needed
3. Update system prompt in `Get-SafeCommandsPrompt` if AI should know about it
4. Document in README

### New Module
1. Create `Modules/YourModule.ps1`
2. Add dot-source to profile: `. "$global:ModulesPath\YourModule.ps1"`
3. Export any global variables or aliases

## Questions?

Open an issue or start a discussion on GitHub.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
