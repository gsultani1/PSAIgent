# Shelix Vision

> Shell + Helix. A shell environment with interconnected, spiraling capability.

---

## What Shelix Is Today

Shelix is an AI shell environment for PowerShell. It gives your terminal a brain — one that understands your context, executes commands on your behalf, remembers your conversations, and connects to external tools through MCP.

Today it does things like:

- **"Create a doc called Q1 Review"** → creates and opens a Word document
- **"What's changed in git since yesterday?"** → runs `git log` and summarizes it
- **"Search the web for PowerShell async patterns and save the results"** → searches, fetches, creates a notes doc
- **"Schedule the daily standup workflow to run every morning at 8am"** → registers a Windows Task Scheduler job
- **"What's in this folder?"** → reads your directory structure, git state, and notable files into the AI's context
- **"Deploy staging"** → runs a user-defined skill (JSON config, no code) that chains git commands + intents
- **Plugins** → drop a `.ps1` file into `Plugins/` and it registers new intents, categories, and workflows automatically
- **`agent "check AAPL and MSFT and calculate the difference"`** → the agent searches stock prices, runs the math, and reports back — no orchestration from you
- **`agent -Interactive "research async patterns"`** → multi-turn agent session with shared working memory across follow-up tasks
- **`Invoke-Workflow -Name daily_standup -StopOnError`** → halt a workflow on first failure rather than running all steps regardless

All of it runs locally. Nothing phones home. The AI can only run commands you've explicitly whitelisted.

As of v1.2.0, the codebase has been fully audited: security hardened, parse errors eliminated, duplicate code removed, and intent ordering made deterministic. The foundation is clean.

---

## What Shelix Is Becoming

The terminal is just the first surface.

The long-term vision is **mission control for your entire computer** — an AI layer that sits between you and everything your machine can do, understands what you're working on, and acts as a continuous collaborator rather than a one-shot tool.

### The layers, in order:

**1. Shell orchestrator** *(✅ complete)*
The AI understands your terminal context — current directory, git state, running processes, file structure — and can execute actions through a safety-gated intent system with 77+ built-in intents. Security hardened: calculator sandboxed to `[math]::` only, file reads validated against allowed roots, `RequiresConfirmation` intents always prompt even in agent mode.

**2. Extensibility layer** *(✅ complete)*
Drop-in plugin architecture with dependency resolution, per-plugin configuration, lifecycle hooks, self-tests, and hot-reload. User-defined skills via JSON config for non-programmers. Community contributions without merge conflicts.

**3. Context engine** *(✅ complete)*
Persistent memory across sessions. The AI recalls what you worked on yesterday, what files you've touched, what decisions you made. Conversation history stored locally, searchable. Token budget management with intelligent context trimming.

**4. Computer awareness** *(next)*
Vision model support for screenshots and images. Browser tab awareness. OCR for documents and scanned PDFs. The AI sees what you see.

**5. Agent architecture** *(✅ complete)*
Dynamic multi-step task planning via the ReAct (Reason + Act) loop. The agent has 12 built-in tools (calculator, web search, stock quotes, Wikipedia, datetime, JSON parsing, regex, file reading, shell execution, working memory), unified tool+intent dispatch, an ASK protocol for mid-task user input, PLAN display, and interactive multi-turn sessions with shared memory.

**6. Mission control GUI** *(future)*
A dashboard layer over the shell. Not a replacement — an amplifier. The terminal stays the engine; the GUI surfaces context, history, running tasks, and agent state in a way that's faster to scan than a command line.

---

## Design Principles

**Local-first.** Your data stays on your machine. No cloud sync, no telemetry, no accounts. The AI providers you connect to are your choice.

**Nothing runs unless you tell it to.** The safety system isn't an afterthought — it's structural. Commands are whitelisted. Destructive actions require confirmation. The AI cannot execute anything outside the approved set without explicit user approval.

**Shell as the foundation.** The terminal isn't a legacy interface to be replaced. It's the most powerful general-purpose computer interface ever built. Shelix extends it rather than abstracting it away.

**Modular by design.** Every capability is a drop-in module. Adding a new intent, provider, or tool doesn't require touching core code. The plugin architecture makes this explicit — drop a `.ps1` file in `Plugins/` or add a skill to `UserSkills.json` and it's live.

**Open.** MIT licensed. The goal is a community of people building their own intents, workflows, and integrations on top of a shared foundation.

---

## Why Not Just Use an Existing AI Tool?

There are more AI agent tools now than there were six months ago. Most of them have real tradeoffs:

- **Provider lock-in.** Many tools are built by AI companies, for their own models. Switching providers means switching tools.
- **Subscription walls.** The most capable features sit behind monthly fees. Your automation budget scales with your usage.
- **Security exposure.** Tools that run in the cloud or require broad system permissions create attack surface. Some require you to hand over filesystem access to a remote service.
- **Narrow scope.** Most agent tools are scoped to development — code generation, PR review, terminal commands. They don't touch your calendar, your documents, your clipboard, your browser, your scheduled tasks.
- **No memory.** Most tools treat every conversation as a fresh start. There's no continuity between sessions, no awareness of what you worked on yesterday.

Shelix is different on all five:

**Provider-agnostic.** Claude, GPT, Ollama, LM Studio, or any llm CLI plugin. Swap models mid-session. Run entirely local if you want.

**Free and open.** MIT licensed. No subscription, no account, no telemetry. The only costs are the API calls you choose to make.

**Safety-first by design.** The safety system isn't a setting — it's structural. Commands are whitelisted. Destructive actions require confirmation. The AI cannot execute anything outside the approved set. Everything runs on your machine, under your control.

**Scoped to your entire machine.** Files, git, calendar, clipboard, browser, scheduled tasks, running processes, documents. Not just your code.

**Persistent context.** Sessions survive restarts. The AI recalls what you worked on, what decisions you made, what files you touched. Conversation history is stored locally, searchable, and will be RAG-ready.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add intents, providers, and modules.

The highest-leverage contributions right now:
- **Plugins** — Drop `.ps1` files into `Plugins/` with `$PluginIntents`, config, hooks, and tests
- **Agent tools** — Register custom tools via `Register-AgentTool` in a plugin
- **User skills** — Add JSON-defined command sequences to `UserSkills.json`
- **Provider integrations** — New LLM APIs, local model formats
- **Cross-platform testing** — macOS/Linux via PowerShell 7
- **Vision + OCR** — Multimodal model support, Tesseract integration
- **RAG layer** — SQLite conversation storage, embedding-ready schema (stub exists in ChatSession.ps1)

---

The closest analogy isn't a chatbot. It's closer to having a personal operations layer — one that knows your files, your schedule, your tools, and your workflow, and can actually act on them. Not just for developers. For anyone who uses a computer and has more to do than time to do it.
