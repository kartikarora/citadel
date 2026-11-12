# Citadel 🏰

> **The Council of Skills & MCPs**: Keep your AI skills, prompts, and MCP servers in one place across Antigravity, Claude, Cursor, and your project repositories.

Citadel is primarily a **native macOS frontend application** designed with Liquid Glass styling, deep directory inspection, live multiverse discovery, and cryptographically signed Git synchronization.

---

## 🖥️ Native macOS Frontend vs. Opt-In CLI

Citadel is built with a **frontend-first architecture**:

1. **Native Desktop Application (`Citadel.app`)**:
   - The primary way to run Citadel on macOS.
   - Self-contained `.dmg` download: no terminal, no build steps, and no PATH configuration required.
   - Provides visual Chamber navigation: Armory, Project Portals, Discovery & Ingestion, NPM Skills Manager, and Encrypted Sync.
   - [Download latest macOS DMG](https://citadel.kartikarora.me/#downloads)

2. **Opt-In CLI (`citadel` / `ctdl`)**:
   - The CLI is completely optional.
   - If you use the frontend, you can install the CLI with one click inside **Settings > CLI Integration** (installs `citadel` and `ctdl` to `~/.local/bin` with autocompletions for Zsh, Bash, and Fish).
   - If you prefer the terminal, you can install the standalone CLI on its own.

3. **Install Frontend from CLI (`citadel app --install`)**:
   - If you have the standalone CLI and want the desktop frontend, you don't need to hunt for browser links:
     ```bash
     # Launch UI if installed, or download & mount the latest DMG release
     citadel app --install
     ```

---

## 🔒 Security & Privacy Verification

Citadel is built for zero-trust local development:

- **Audited by Gitleaks**: Scanned across repository history with **0 secrets, 0 private keys, and 0 tokens** committed.
- **Audited by Code-VulnScan**: Flow-aware AST analysis across Python, Swift, Shell, and Actions verifies **0 critical, 0 high vulnerability patterns**.
- **Hardware-Bound Commit Signing**: All Git synchronization in `~/.citadel` is automatically signed with SSH Ed25519 keys isolated inside your **macOS Keychain** (`sh.citadel.signing`).
- **No Cloud Exfiltration**: Citadel does not host an intermediary backend. Synchronization runs directly between your device and your own private GitHub or GitLab repository.
- **Safe Decoupling & Materialization**: You can eject from Citadel at any time using **Settings > Materialize All Symlinks** or running the auto-generated standalone recovery script at `~/.citadel/rollback.sh`.

---

## The Problem Citadel Solves

Every AI coding assistant expects configs in its own siloed directory:
- **Antigravity** stores global skills in `~/.gemini/config/skills`, plugins in `~/.gemini/config/plugins`, and project configs in `.gemini/`.
- **Claude Code / Desktop** stores skills in `~/.claude/skills`, desktop MCPs in `~/Library/Application Support/Claude/claude_desktop_config.json`, and project configs in `.claude/`.
- **Matilda, Cursor, Android Studio, Copilot, Junie & 75+ other agents** (tracked via Citadel's centralized `AgentRegistry`, aligned with `vercel-labs/skills`) store skills in tool-specific paths such as `~/.matilda/skills`, `~/.cursor/skills`, `~/.android-studio/skills`, `~/.copilot/skills`, `~/.junie/skills`, and project folders like `.matilda/` or `.agents/`.
- **Projects** frequently have local prompt folders checked into Git, meaning bug fixes or updates in one project never reach your other projects.

Citadel stores your canonical skills and MCP configs in `~/.citadel` and manages live symlinks across all dimensions. When you edit a skill, every assistant sees the edit immediately.

---

## Quick Start

### 1. Download the Native Frontend
Grab the latest release from [citadel.kartikarora.me](https://citadel.kartikarora.me/):
- Download `Citadel-0.1.0-macOS-arm64.dmg`
- Drag `Citadel.app` to `/Applications`
- Run the 5-step onboarding wizard to set up your directory, SSH signing key, theme, and initial scan.

### 2. Install Standalone CLI (Curl One-Liner)
Install `citadel` and `ctdl` into `~/.local/bin` with autocompletions for Zsh, Bash, and Fish:
```bash
curl -fsSL https://citadel.kartikarora.me/install.sh | bash
```

### 3. Or Install via Homebrew (Cask & Tap)
Install the native macOS desktop app via Homebrew Cask:
```bash
brew install --cask kartikarora/tap/citadel
```
Or install the standalone CLI binary:
```bash
brew install kartikarora/tap/citadel
```

### 4. Or Build CLI from Source
```bash
git clone https://github.com/kartikarora/citadel.git
cd citadel
swift build -c release
```

Initialize your central hub:
```bash
citadel init
```

---

## Common CLI Commands

| Command | Action |
| :--- | :--- |
| `citadel app` | Launch the native macOS desktop application |
| `citadel app --install` | Download and install the latest Citadel.app DMG if not installed |
| `citadel list` | View installed skills, registered MCP servers, and linked workspace portals |
| `citadel sync` | Synchronize all symlinks across Antigravity, Claude, and workspaces |
| `citadel discover` | Scan filesystem for untracked skills and MCPs across existing tools |
| `citadel search <query>` | Search npm for community agent skills |
| `citadel install <pkg>` | Install an npm package in the background using `npx` |
| `citadel portal <dir>` | Symlink skills into a project repository |
| `citadel status` | Check Git status of the central `~/.citadel` repository |
| `citadel docs` | Open local web documentation in default browser |

---

## Protecting API Keys in MCP Configs

Never hardcode raw API tokens into MCP JSON files. Use environment variable expansion `${VAR_NAME}`:

```json
{
  "name": "github",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
  }
}
```

Citadel resolves `${GITHUB_TOKEN}` from your shell environment or macOS Keychain when generating client tool configs. The central Git repository in `~/.citadel` only stores the variable reference.

---

## Documentation & Live Preview

- Web Documentation: [https://citadel.kartikarora.me/](https://citadel.kartikarora.me/)
- Open local docs: `citadel docs` or inspect `docs/index.html`.
