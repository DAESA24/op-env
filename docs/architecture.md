# Secret Management for AI Coding Agents: The `op-env` Pattern

> A practical architecture for injecting 1Password secrets into interactive CLI tools like Claude Code — without writing secrets to disk or breaking terminal interactivity.

## Summary

This architecture was built for [PAI](https://github.com/danielmiessler/PAI) users, but the underlying pattern — a bash wrapper that resolves 1Password secrets and `exec`s an interactive command with TTY preserved — is general enough to adapt to any framework or AI coding agent workflow. If you're not using PAI, the `op-env` script and template format work with anything.

This document describes `op-env`, a 17-line bash wrapper script that solves a specific problem: injecting 1Password secrets into AI coding agents that require an interactive terminal (TTY). The core idea is simple — resolve all `op://` secret references in a single 1Password API call, export them as environment variables, then `exec` the target command so the process inherits the terminal directly. Secrets exist only in process memory for the duration of the session. No `.env` files are written to disk, ever.

The architecture currently manages 7 API keys across 2 1Password vaults (OpenAI, Google, Replicate, Apify, RemoveBG, YouTube, and GitHub) using UUID-based `op://` references for stability. It includes shell aliases for one-command PAI session launches, a conditional `gh` CLI integration that eliminates per-command biometric prompts, and a clear security model that explicitly states what it does and doesn't protect against. The number of secrets and vaults is not fixed — `op-env` resolves whatever is in the template file, so it scales to any number of keys across any number of vaults.

The document covers the full architecture (how it works step-by-step), the security model (threat analysis with explicit trade-offs), design decisions (why alternatives were rejected), a complete setup guide (reproducible from scratch), and troubleshooting for common issues.

## Table of Contents

- [Secret Management for AI Coding Agents: The `op-env` Pattern](#secret-management-for-ai-coding-agents-the-op-env-pattern)
  - [Summary](#summary)
  - [Table of Contents](#table-of-contents)
  - [Who This Is For](#who-this-is-for)
  - [The Problem](#the-problem)
  - [Architecture Overview](#architecture-overview)
  - [How It Works](#how-it-works)
    - [1. Shell alias expands](#1-shell-alias-expands)
    - [2. `pai update` checks for updates](#2-pai-update-checks-for-updates)
    - [3. `op-env` starts](#3-op-env-starts)
    - [4. One `op run` call resolves all secrets](#4-one-op-run-call-resolves-all-secrets)
    - [5. Secrets exported to current shell](#5-secrets-exported-to-current-shell)
    - [6. `exec` replaces the process (TTY preserved)](#6-exec-replaces-the-process-tty-preserved)
    - [7. Session ends, secrets disappear](#7-session-ends-secrets-disappear)
  - [Security Model](#security-model)
    - [What `op-env` Protects Against](#what-op-env-protects-against)
    - [What `op-env` Does NOT Protect Against](#what-op-env-does-not-protect-against)
  - [GitHub CLI Integration](#github-cli-integration)
  - [Design Decisions](#design-decisions)
    - [Why not `op run` directly?](#why-not-op-run-directly)
    - [Why not just export secrets in `.zshrc`?](#why-not-just-export-secrets-in-zshrc)
    - [Why not per-key `op read` calls?](#why-not-per-key-op-read-calls)
    - [Evolution of the approach](#evolution-of-the-approach)
  - [What Is TTY?](#what-is-tty)
  - [Setup Guide](#setup-guide)
    - [Prerequisites](#prerequisites)
    - [Step 1: Install 1Password CLI](#step-1-install-1password-cli)
    - [Step 2: Create the secret template](#step-2-create-the-secret-template)
    - [Step 3: Create the `op-env` wrapper script](#step-3-create-the-op-env-wrapper-script)
    - [Step 4: Create a launch alias](#step-4-create-a-launch-alias)
    - [Step 5: Verify it works](#step-5-verify-it-works)
  - [File Reference](#file-reference)
  - [Troubleshooting](#troubleshooting)
    - [1Password not authenticated](#1password-not-authenticated)
    - [TTY errors or non-interactive mode](#tty-errors-or-non-interactive-mode)
    - ["pai: command not found"](#pai-command-not-found)
    - [Secrets not resolving](#secrets-not-resolving)
    - [Adding new secrets](#adding-new-secrets)

## Who This Is For

Anyone using an AI coding agent (Claude Code, Cursor, Aider, etc.) and 1Password that needs API keys at runtime. If you're using PAI, this was built specifically for that workflow. If you're not, the underlying pattern (`op-env`) is general enough to adapt.

The problem it solves: you're not a security expert, but you want secrets managed properly — not hardcoded, not in dotfiles, not in plaintext `.env` files that end up in git history — but your tool needs a real terminal to run interactively, which breaks most secret injection approaches. 

## The Problem

AI coding agents create a secret management challenge that's different from traditional server-side apps:

1. **The agent can read environment variables.** Claude Code has access to `process.env`. Any secret loaded as an env var is readable by the agent and any tool it invokes.
2. **Dotenv files persist on disk.** A `.env` file with plaintext API keys can get committed to git, included in backups, or read by other processes.
3. **The agent runs interactively.** Unlike a web server, Claude Code needs a real terminal (TTY) for its interactive UI. Many secret injection tools spawn subprocesses that don't preserve TTY, causing the app to fail silently or drop into non-interactive mode.

The third point is the non-obvious one. Most documentation assumes your target process is a daemon or build script — not an interactive TUI application.

## Architecture Overview

![The op-env Architecture](images/op-env-architecture.jpg)

## How It Works

Here's what happens when you type `ccc` (my alias for "Claude Code, current directory") in your terminal:

### 1. Shell alias expands

```zsh
alias ccc='pai update && op-env pai --local'
```

This single alias chains three things together:
1. **`pai update`** — checks for Claude Code updates and installs if available
2. **`op-env`** — resolves all 1Password secrets and exports them as env vars (the focus of this doc)
3. **`pai --local`** — launches PAI, which loads all the PAI infrastructure (skills, hooks, context) and starts Claude Code

The result: one command gets you an up-to-date, secret-injected, fully configured PAI session. You could adapt this alias to any workflow — the `op-env <command>` pattern works with anything.

### 2. `pai update` checks for updates

A quick check for Claude Code updates. If an update is available, it installs before launching. If not, it returns immediately.

### 3. `op-env` starts

The wrapper script at `~/.local/bin/op-env` begins execution. It reads the template file to discover which secrets are needed:

```bash
TPL="${HOME}/.claude/.env.tpl"
KEYS=$(grep -v '^#' "$TPL" | grep -v '^$' | cut -d= -f1 | tr '\n' '|' | sed 's/|$//')
```

This extracts just the key names (like `OPENAI_API_KEY`, `GOOGLE_API_KEY`) from the template, ignoring comments and blank lines.

### 4. One `op run` call resolves all secrets

```bash
op run --no-masking --env-file "$TPL" -- env 2>/dev/null | grep -E "^($KEYS)="
```

This is the key line. `op run` contacts 1Password, resolves every `op://` reference in the template, and runs `env` to print all environment variables. The `grep` filters to only the keys we defined. The `--no-masking` flag ensures values aren't redacted (they're going into env vars, not stdout).

**Why one call matters:** Each `op` invocation has latency (biometric prompt, API round-trip). Resolving all secrets in a single `op run` means you authenticate once regardless of how many secrets you have.

### 5. Secrets exported to current shell

```bash
while IFS='=' read -r key value; do
  export "$key=$value"
done < <(...)
```

Each resolved key-value pair is exported as an environment variable in the current process. No file is written. The secrets exist only in this process's memory.

### 6. `exec` replaces the process (TTY preserved)

```bash
exec "$@"
```

This is the line that makes the whole thing work. `exec` replaces the current process (op-env) with the target command (`pai --local`). Because it's a process replacement — not a subprocess spawn — the new process inherits the terminal's TTY directly. Claude Code sees a real terminal and launches interactively.

### 7. Session ends, secrets disappear

When you exit Claude Code, the process terminates. The environment variables existed only in that process tree. Nothing persists on disk.

## Security Model

![op-env Security Model](images/op-env-security-model.jpg)

This architecture makes specific trade-offs. Here's a direct accounting of what it does and doesn't protect.

### What `op-env` Protects Against

| Threat | How It's Mitigated |
|--------|-------------------|
| Secrets committed to git | No `.env` file exists to commit. Template has `op://` references, not values. |
| Secrets in backups | Nothing to back up. Secrets are ephemeral — they exist only in process memory. |
| Secrets found by other tools | No file on disk means no accidental reads by linters, editors, or indexers. |
| Stale credentials | Each session resolves fresh values from 1Password. Rotate in 1Password and the next session picks it up automatically. |
| Secrets surviving reboot | Process memory is cleared on exit. No persistence mechanism exists. |
| Unauthorized access at rest | 1Password requires biometric authentication before resolving any `op://` reference. |

### What `op-env` Does NOT Protect Against

| Threat | Why It's Not Mitigated |
|--------|----------------------|
| Agent reads env vars at runtime | Claude Code can access `process.env` during a session. This is by design — the agent needs the keys to call APIs. |
| Secrets printed to stdout | If a tool or the agent runs `printenv` or `echo $KEY`, values appear in terminal output. |
| MCP servers inherit env vars | MCP servers spawned by Claude Code run in the same process tree and inherit all exported variables. |
| Memory forensics | A sufficiently privileged attacker could read process memory while the session is running. |
| Shoulder surfing | Someone watching your screen could see secrets if they're printed or logged. |

**The principle:** `op-env` protects secrets at rest (nothing on disk, ever). It does not and cannot protect secrets at runtime — the agent needs them to function. The threat model is "reduce blast radius and eliminate persistence," not "prevent all access."

## GitHub CLI Integration

The `gh` CLI (GitHub's official command-line tool) has its own authentication mechanism that conflicts with `op-env`'s approach. By default, `gh` uses 1Password's shell plugin, which prompts for biometric authentication on every `gh` command. Inside a PAI session — where the agent makes many `gh` calls (checking PRs, pushing code, reading issues) — this creates constant biometric interrupts.

The fix is a conditional unalias in `.zshrc`:

```zsh
# When GITHUB_TOKEN is already in env (via op-env), use gh directly
[[ -n "$GITHUB_TOKEN" ]] && unalias gh 2>/dev/null
```

This works because:

1. **Outside a PAI session:** `GITHUB_TOKEN` is not set, so the 1Password shell plugin alias for `gh` stays active. You get per-command biometric auth as normal.
2. **Inside a PAI session:** `op-env` has already resolved `GITHUB_TOKEN` from 1Password and exported it. The `gh` CLI detects `GITHUB_TOKEN` in the environment and uses it automatically — no per-command auth needed. The conditional `unalias` removes the 1Password shell plugin's wrapper so `gh` runs directly.

The result: one biometric prompt per session (when `op-env` resolves secrets), then uninterrupted `gh` access for the entire session. The agent can run `gh pr create`, `gh issue list`, etc. without triggering auth prompts.

## Design Decisions

### Why not `op run` directly?

The first instinct is:

```bash
op run --env-file ~/.claude/.env.tpl -- claude
```

This fails for interactive applications. `op run` spawns `claude` as a subprocess, and that subprocess doesn't get a TTY. Claude Code detects the missing terminal and either errors out or falls back to non-interactive `--print` mode.

### Why not just export secrets in `.zshrc`?

You could hardcode `export OPENAI_API_KEY=sk-...` in your shell config. Problems:

- Shell config files get committed to dotfiles repos
- Secrets persist across all terminal sessions, not just the ones that need them
- No automatic rotation — you manually update values when keys change
- Every process you launch inherits the secrets, not just the target app

### Why not per-key `op read` calls?

```bash
export OPENAI_API_KEY=$(op read "op://vault/item/field")
export GOOGLE_API_KEY=$(op read "op://vault/item/field")
# ... one call per key
```

This works but scales poorly. Each `op read` is a separate 1Password API call with its own latency. With 6+ keys, startup becomes noticeably slow. The `op run --env-file` approach resolves all keys in a single authenticated call.

### Evolution of the approach

| Version | Method | Problem |
|---------|--------|---------|
| v1 | `op inject` hook writes `.env` at session start | Secrets on disk (violates at-rest protection) |
| v2 | `op run --env-file ... -- claude` | No TTY passthrough (Claude Code can't run interactively) |
| v3 | `op-env` wrapper with `exec` | Current solution — secrets in memory only, TTY preserved |

## What Is TTY?

TTY stands for "teletypewriter" — a historical term for terminal devices. In modern systems, a TTY is the interface between your terminal emulator (iTerm2, Terminal.app) and the process running inside it.

When a process has a TTY:
- It can read keyboard input interactively
- It can render full-screen UIs (like Claude Code's interface)
- It knows the terminal dimensions (rows and columns)
- It can handle signals like Ctrl+C

When a process does **not** have a TTY:
- It's running in "pipe mode" — it can only read stdin and write stdout
- No interactive UI is possible
- Prompts and key bindings don't work

The issue with `op run` is that it spawns commands as non-TTY subprocesses. The `exec` approach in `op-env` avoids this by replacing the wrapper process entirely, so the target command inherits the original terminal's TTY.

## Setup Guide

### Prerequisites

- macOS (tested on Sequoia)
- [Homebrew](https://brew.sh)
- [1Password](https://1password.com) desktop app with biometric unlock enabled
- [1Password CLI](https://developer.1password.com/docs/cli) (`op`)
- Claude Code (or any interactive CLI tool you want to inject secrets into)
- zsh (default macOS shell)

### Step 1: Install 1Password CLI

```bash
brew install --cask 1password-cli
```

Verify it's working:

```bash
op --version
op account list
```

Make sure the CLI is connected to your 1Password account. The desktop app must be running for biometric authentication.

### Step 2: Create the secret template

Create `~/.claude/.env.tpl` (or wherever makes sense for your tool):

```bash
mkdir -p ~/.claude
cat > ~/.claude/.env.tpl << 'EOF'
# PAI API Keys — 1Password Secret References
# Used by: op run --env-file ~/.claude/.env.tpl -- claude
# Secrets are injected as env vars at runtime, never written to disk.
# To add a new key: add KEY_NAME=op://vault-uuid/item-uuid/field
# To rotate a key: just rotate in 1Password — next session picks it up.
# NOTE: Use UUIDs (not names) for vault/item — names break on rename.

# Vault: Credentials-Workflow Tools
OPENAI_API_KEY=op://<vault-uuid>/<item-uuid>/credential
GOOGLE_API_KEY=op://<vault-uuid>/<item-uuid>/credential
REPLICATE_API_TOKEN=op://<vault-uuid>/<item-uuid>/credential
APIFY_TOKEN=op://<vault-uuid>/<item-uuid>/credential
REMOVEBG_API_KEY=op://<vault-uuid>/<item-uuid>/credential
YOUTUBE_API_KEY=op://<vault-uuid>/<item-uuid>/credential

# Vault: Private
GITHUB_TOKEN=op://<vault-uuid>/<item-uuid>/token
EOF
```

This template holds 7 keys across 2 vaults — all the API keys PAI's skills and tools need at runtime (OpenAI, Google, Replicate, Apify, RemoveBG, YouTube, and GitHub).

**Important: Use UUIDs, not names.** Early versions of this template used human-readable vault and item names (`op://My Vault/OpenAI Key/credential`). This caused intermittent failures: renaming a vault or item in 1Password silently broke the reference, and names with special characters or whitespace produced hard-to-debug resolution errors. Switching to UUIDs eliminates this class of problem entirely — UUIDs are stable, unambiguous, and survive renames.

To find your UUIDs:

```bash
# List vaults with UUIDs
op vault list --format=json | jq '.[] | {id, name}'

# List items in a vault with UUIDs
op item list --vault <vault-uuid> --format=json | jq '.[] | {id, title}'
```

### Step 3: Create the `op-env` wrapper script

```bash
cat > ~/.local/bin/op-env << 'SCRIPT'
#!/bin/bash
# op-env: Load 1Password secrets and exec command with TTY preserved
# Usage: op-env <command> [args...]

TPL="${HOME}/.claude/.env.tpl"

# Get key names from template (skip comments and blank lines)
KEYS=$(grep -v '^#' "$TPL" | grep -v '^$' | cut -d= -f1 | tr '\n' '|' | sed 's/|$//')

# Resolve all secrets in one op call, extract only our keys, export them
while IFS='=' read -r key value; do
  export "$key=$value"
done < <(op run --no-masking --env-file "$TPL" -- env 2>/dev/null | grep -E "^($KEYS)=")

exec "$@"
SCRIPT

chmod +x ~/.local/bin/op-env
```

Make sure `~/.local/bin` is in your PATH:

```bash
# Add to ~/.zshrc if not already present
export PATH="$HOME/.local/bin:$PATH"
```

### Step 4: Create a launch alias

Add to your `~/.zshrc`:

```zsh
# PAI launch aliases — each chains: update check → secret injection → PAI launch
alias ccc='pai update && op-env pai --local'   # current directory
alias ccp='pai update && cd ~/projects && op-env pai --local'  # ~/projects
alias cch='pai update && cd ~/.claude && op-env pai --local'   # ~/.claude (PAI home)
```

The primary alias is `ccc` ("Claude Code, current directory"). The others (`ccp`, `cch`) follow the same pattern but `cd` into a specific directory first, so you can launch a PAI session in a common workspace with a single command. All three share the same structure: `pai update && op-env pai --local`. The key piece is `op-env <your-command>`, which wraps any command with 1Password secret injection. Everything before and after that is up to you.

### Step 5: Verify it works

```bash
source ~/.zshrc
ccc
```

If 1Password prompts for biometric authentication and Claude Code launches with its interactive UI, it's working. You can verify secrets are available inside the session:

```bash
# Inside Claude Code, check that env vars are set (don't print values!)
echo "OPENAI_API_KEY is ${OPENAI_API_KEY:+set}"
```

## File Reference

| File | Purpose |
|------|---------|
| `~/.local/bin/op-env` | Wrapper script — resolves secrets, exports, exec's with TTY |
| `~/.claude/.env.tpl` | Template with `op://` UUID references (no actual secrets) |
| `~/.zshrc` | Launch aliases (`ccc`, `ccp`, `cch`) and conditional `gh` unalias |
| `~/.local/bin/pai` | Bash-to-bun bridge — `exec`s `bun ~/.claude/PAI/Tools/pai.ts` (must be a real executable, not a shell alias, because `exec` doesn't resolve aliases) |

## Troubleshooting

### 1Password not authenticated

**Symptom:** `op-env` hangs or Claude Code launches without secrets.

**Fix:** Make sure the 1Password desktop app is running and unlocked. The CLI authenticates through the desktop app's biometric unlock. Run `op account list` to verify connectivity.

### TTY errors or non-interactive mode

**Symptom:** Claude Code says "No terminal detected" or drops into `--print` mode.

**Fix:** Make sure you're using `exec` in the wrapper, not running the command as a subprocess. The `exec` line must be the last line of the script. Also verify you're running from a real terminal — not from a script or cron job.

### "pai: command not found"

**Symptom:** `op-env pai --local` fails with command not found.

**Fix:** `exec` doesn't use shell aliases — it needs a real executable in PATH. Make sure `pai` exists as a script at `~/.local/bin/pai` (not just a shell alias). Check with `which pai`.

### Secrets not resolving

**Symptom:** Claude Code launches but API calls fail with auth errors.

**Fix:** Check that your `op://` references are correct. Common issues:
- If you're still using vault/item names instead of UUIDs, rename operations in 1Password will silently break references. Switch to UUIDs (see Step 2 above).
- Field name is usually `credential` for API keys, but some items use `token` or other field names. Check in 1Password.
- Test a single reference: `op read "op://<vault-uuid>/<item-uuid>/credential"`.
- List items with UUIDs to verify: `op item list --vault <vault-uuid> --format=json | jq '.[] | {id, title}'`.

### Adding new secrets

Add a new line to `~/.claude/.env.tpl` using UUIDs:

```
NEW_API_KEY=op://<vault-uuid>/<item-uuid>/credential
```

No script changes needed. The next session will pick it up automatically. Use `op vault list --format=json` and `op item list --vault <vault-uuid> --format=json` to find the UUIDs.

---

*Built on macOS Sequoia with 1Password 8 and Claude Code. The `op-env` pattern works for any interactive CLI tool that needs secrets from 1Password.*
