# Citadel (`ctdl`)

Keep your AI skills, prompts, and MCP servers in one place.

Claude, Antigravity, and Cursor each expect configs in different folders. Citadel keeps your skills in `~/.citadel` and symlinks them into each tool. When you edit a skill, every assistant sees the edit immediately.

---

## The Problem

- **Antigravity** stores global skills in `~/.gemini/config/skills`, plugins in `~/.gemini/config/plugins`, and project configs in `.gemini/`.
- **Claude** stores CLI skills in `~/.claude/skills`, desktop MCPs in `~/Library/Application Support/Claude/claude_desktop_config.json`, and project configs in `.claude/`.
- **Cursor / Codex** use workspace prompt files.
- **Projects** often have local prompt folders checked into Git, so bug fixes in one project never reach your other projects.

Citadel stores your canonical skills and MCP configs in `~/.citadel`. It manages the symlinks and config generation for each tool.

---

## Installation

Citadel is written in Swift for macOS.

```bash
git clone https://github.com/kartik/citadel.git
cd citadel && make install
```

This installs `citadel` and `ctdl` into `/usr/local/bin`.

Initialize your central hub:
```bash
ctdl init
```

This creates `~/.citadel` with a Git repository to track your changes.

---

## Common Tasks

### List skills and tools
```bash
ctdl list
```
Shows installed skills in `~/.citadel/skills`, registered MCP servers in `~/.citadel/mcps`, and linked project folders.

### Add a skill
```bash
ctdl add skill ~/.gemini/config/skills/hallmark
```
Copies the skill into `~/.citadel/skills/hallmark`.

### Re-apply symlinks
```bash
ctdl sync
```
Symlinks all skills to `~/.gemini/config/skills/` and `~/.claude/skills/`, injects MCP servers into Claude Desktop, and commits the state to Git.

### Link a project repo
```bash
cd ~/Projects/my-app
ctdl portal .
```
Symlinks your skills into `my-app/.gemini/skills/` and `my-app/.claude/skills/`. Both tools can use your skills in that project, and any edits you make update the central copy in `~/.citadel`.

---

## Community Skills via npm

Citadel uses the npm registry to share skills. There is no custom backend.

```bash
# Search npm for packages tagged with 'citadel-skill'
ctdl search design

# Install an npm package into ~/.citadel/skills/ and link it
ctdl install @developer/citadel-skill-kubernetes
```

To publish a skill, add `"keywords": ["citadel-skill"]` to its `package.json` and run `npm publish`.

---

## Sync Across Machines

`~/.citadel` is a Git repository:

```bash
# Check status of local changes
ctdl status

# Push to your private GitHub repo
ctdl push

# On another Mac, pull and update all local symlinks
ctdl pull
```

---

## Protecting API Keys

Do not write real API tokens into MCP JSON files. Use `${VAR_NAME}` instead:

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

Citadel reads `$GITHUB_TOKEN` from your shell or macOS Keychain when generating tool configs. The Git repository in `~/.citadel` only stores the variable name.

---

## Documentation

View the local docs:
```bash
ctdl docs
```
Or open [docs/index.html](file:///Users/kartikarora/Projects/skills-manager/docs/index.html).
