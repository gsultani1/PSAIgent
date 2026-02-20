# Shelix Setup Guide

## Quick Start

### 1. Install Ollama (Local LLM - Recommended)

```powershell
# Install via winget
winget install Ollama.Ollama

# Or download from: https://ollama.com/download/windows
```

After installation, Ollama runs as a service. Pull a model:

```powershell
# Pull a model (choose one)
ollama pull llama3.2        # Default, good balance
ollama pull mistral         # Fast, good for coding
ollama pull codellama       # Specialized for code
ollama pull phi3            # Small and fast

# Verify it's running
ollama list
```

Ollama runs on `http://localhost:11434` - no API key needed.

---

### 2. Install Required PowerShell Modules

```powershell
# Required for AI execution (timeout protection)
Install-Module ThreadJob -Scope CurrentUser

# Optional but recommended
Install-Module PSReadLine -Scope CurrentUser -Force
Install-Module Terminal-Icons -Scope CurrentUser
Install-Module posh-git -Scope CurrentUser
```

---

### 3. Configure API Keys (for Cloud Providers)

Edit `ChatConfig.json` in your PowerShell profile directory:

```json
{
  "apiKeys": {
    "ANTHROPIC_API_KEY": "sk-ant-api03-your-key-here",
    "OPENAI_API_KEY": "sk-your-openai-key-here"
  }
}
```

**Or** set via terminal (persists across sessions):
```powershell
Set-ChatApiKey -Provider anthropic -ApiKey "sk-ant-api03-..."
Set-ChatApiKey -Provider openai -ApiKey "sk-..."
```

---

### 4. Install Terminal Tools (Optional but Recommended)

```powershell
# Syntax-highlighted file viewing
winget install sharkdp.bat

# Markdown rendering
winget install charmbracelet.glow

# File explorer
winget install Canop.broot

# Fuzzy finder
winget install fzf

# Fast search
winget install BurntSushi.ripgrep.MSVC

# Data viewer (requires Python)
pip install visidata
```

Check what's installed:
```powershell
tools
```

---

## Usage

### Start a Chat Session

```powershell
# Default (Ollama)
chat

# Specific providers
chat-ollama          # Local Ollama
chat-local           # Local LM Studio
chat-anthropic       # Claude API (needs key)

# With options
chat -Provider ollama -Model llama3.2 -Stream
```

### In-Chat Commands

| Command | Action |
|---------|--------|
| `exit` | End session (auto-saves) |
| `clear` | Reset conversation (saves previous) |
| `save` / `save <name>` | Save session |
| `resume` / `resume <name>` | Load a saved session |
| `sessions` | Browse all saved sessions |
| `search <keyword>` | Search across sessions |
| `rename <name>` | Rename current session |
| `export` / `export <name>` | Export session to markdown |
| `budget` | Show token usage breakdown |
| `folder` | Inject current directory context |
| `folder <path>` | Inject a specific directory |
| `switch` | Change AI provider |
| `model <name>` | Change model |
| `agent <task>` or `/agent <task>` | Run autonomous agent task |
| `/agent` | Interactive agent mode (follow-up tasks) |
| `/tools` | List agent tools |
| `/steps` | Show steps from last agent run |
| `/memory` | Show agent working memory |
| `/plan` | Show agent's last plan |

### AI Can Execute Commands

The AI can run PowerShell commands using:
- `EXECUTE: get-process`
- `{"action":"execute","command":"get-process"}`
- `{"intent":"open_word"}`

All executions are logged and require confirmation for non-read-only commands.

### Autonomous Agent

The agent reasons, plans, and uses tools autonomously:

```powershell
# One-shot task
agent "check AAPL stock price and calculate 10% of it"

# Interactive mode — follow-up tasks with shared memory
agent -Interactive "research PowerShell automation"

# Pre-seed working memory
agent -Memory @{ budget = "5000" } "calculate 8% tax on the budget"

# Inspect last run
agent-steps    # Show what the agent did
agent-memory   # Show stored values
agent-plan     # Show the agent's plan
agent-tools    # List all available tools
```

---

## File Structure

```
Shelix/
├── Microsoft.PowerShell_profile.ps1  # Main profile (loads modules)
├── ChatConfig.json                    # API keys & settings
├── NaturalLanguageMappings.json       # Command translations
├── UserSkills.json                    # Your custom intents (JSON)
├── UserAliases.ps1                    # Your custom aliases
├── Modules/                           # 25+ focused modules
│   ├── IntentAliasSystem.ps1          # Intent routing (30+ intents)
│   ├── UserSkills.ps1                 # JSON user skill loader
│   ├── PluginLoader.ps1              # Plugin system (deps, config, hooks, tests)
│   ├── ChatSession.ps1                # Chat loop + session persistence
│   ├── ChatProviders.ps1              # LLM backends
│   ├── FolderContext.ps1              # Folder awareness for AI
│   ├── ToastNotifications.ps1         # BurntToast/.NET alerts
│   └── ...                            # See README for full list
└── Plugins/                           # Drop-in plugin directory
    ├── _Example.ps1                   # Reference template
    ├── _Pomodoro.ps1                  # Timer plugin
    └── _QuickNotes.ps1                # Note-taking plugin
```

---

## Troubleshooting

### "Ollama not responding"
```powershell
# Check if Ollama is running
ollama list

# Restart Ollama service
Stop-Process -Name ollama -Force
ollama serve
```

### "API key not found"
1. Check `ChatConfig.json` has your key
2. Or run: `Set-ChatApiKey -Provider anthropic -ApiKey "your-key"`
3. Reload: `. $PROFILE`

### "Command not in safe actions list"
The AI can only run whitelisted commands. View them:
```powershell
actions
actions -Category FileOperations
```

### Profile won't load
```powershell
# Check for errors
powershell -NoProfile
. $PROFILE
```

---

## Package Manager

### Health Check
```powershell
health            # Check status of all tools
```

### Install Missing Tools
```powershell
install-tools              # Install all missing enabled tools
install-tools -Force       # Install without prompting
Install-Tool bat           # Install specific tool
```

### Configure Preferences
Edit `ToolPreferences.json` to:
- Enable/disable auto-install
- Choose which tool categories to enable
- Disable specific tools

### Migration Helpers
```powershell
bash-help         # Bash to PowerShell command guide
zsh-help          # Zsh/Oh-My-Zsh to PowerShell guide
```

---

## Quick Reference

```powershell
# General
tips              # Show all commands
providers         # Show chat providers
intent-help       # Show AI intents
actions           # Show safe commands
tools             # Show terminal tools
health            # Tool health check
profile-timing    # Show load performance

# Plugins
plugins           # List active & disabled plugins
new-plugin 'Name' # Scaffold a new plugin
test-plugin -All  # Run plugin self-tests
watch-plugins     # Auto-reload on file save
plugin-config X   # View plugin configuration

# User Skills
skills            # List user-defined skills
new-skill 'Name'  # Create a skill interactively
reload-skills     # Reload from UserSkills.json

# Agent
agent "task"      # Run autonomous agent task
agent-tools       # List agent tools
agent-steps       # Show last run steps
agent-memory      # Show working memory
agent-plan        # Show last plan

# Workflows & Sessions
workflows         # List available workflows
session-info      # Show current session
sessions          # Browse saved sessions
```

---

## Development Notes

### Linter Warnings

You may see PSScriptAnalyzer warnings like:
```
The cmdlet 'chat-ollama' uses an unapproved verb.
```

**These are intentional.** PowerShell prefers formal `Verb-Noun` naming (like `Get-Process`), but these are convenience aliases designed for quick daily use, not formal cmdlets. They work correctly and can be safely ignored.

Affected functions: `chat-ollama`, `chat-anthropic`, `chat-local`, `chat-llm`, `profile-edit`, `pwd-full`, `pwd-short`
