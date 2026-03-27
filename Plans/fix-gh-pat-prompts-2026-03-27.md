---
title: Fix GitHub CLI PAT Repeated Authorization Prompts
status: planned
created: 2026-03-27
author: Daesa (PAI)
priority: high
scope: op-env gh CLI integration, .zshrc alias management
github-issue: https://github.com/DAESA24/op-env/issues/25
---

# Fix GitHub CLI PAT Repeated Authorization Prompts

## Problem

During Claude Code sessions, every `gh` CLI command triggers a 1Password authorization prompt. This happens because:

1. `.zshrc` sources `~/.config/op/plugins.sh` which sets `alias gh="op plugin run -- gh"`
2. The 1Password plugin resolves the GitHub PAT from 1Password on EVERY invocation
3. Each resolution triggers a biometric/authorization prompt

The existing mitigation (`.zshrc` line 14: `[[ -n "$GITHUB_TOKEN" ]] && unalias gh`) fails because:
- **In non-op-env sessions:** GITHUB_TOKEN is never set, so the alias persists
- **In op-env sessions:** Evidence shows GITHUB_TOKEN does not propagate into Claude Code's Bash tool environment (possibly sandboxed), so the alias persists there too

## Root Cause (First Principles)

The current design fights the 1Password plugin system. The alias wraps every `gh` call through `op plugin run`, and the only defense is removing the alias — which depends on a fragile chain of env var propagation and shell sourcing order.

**Key insight:** gh CLI has its own secure credential store (macOS Keychain). Instead of fighting the alias, we should feed gh its token through gh's native auth mechanism at session start. This makes the alias irrelevant.

## Recommended Fix: Option A — `gh auth login` at Session Start

### How It Works

Add a post-resolution step to op-env that runs `gh auth login --with-token` after resolving secrets. This stores the PAT in gh's native credential store (macOS Keychain).

```bash
# In op-env, after secret resolution and before exec:
if [ -n "$GITHUB_TOKEN" ]; then
  echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null
fi
```

### Why This Works

1. **No alias dependency:** gh uses Keychain auth regardless of whether the alias is present
2. **No env propagation dependency:** The token is in Keychain, not in env vars
3. **Session-fresh:** Each op-env session refreshes the Keychain token from 1Password
4. **Secure:** macOS Keychain is encrypted, not plaintext
5. **Works everywhere:** All processes on the system can use `gh` without prompts after session start

### Changes Required

**op-env (`bin/op-env`):**
- Add `gh auth login --with-token` step after secret resolution, before `exec`
- Gate behind `GITHUB_TOKEN` being resolved (skip if not in template)
- Silent failure (don't abort if gh isn't installed)

**.zshrc:**
- Remove the fragile unalias logic (lines 12-14)
- Optionally remove `source plugins.sh` entirely if gh is the only 1Password plugin
- OR: keep plugins.sh but the gh plugin becomes harmless (Keychain auth takes precedence)

**Tests (`test/test-op-env.sh`):**
- Add test: op-env calls `gh auth login` when GITHUB_TOKEN is resolved
- Add test: op-env skips `gh auth login` when GITHUB_TOKEN is not in template
- Add test: op-env doesn't fail if `gh` binary is missing

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| gh not installed | Silent skip — `gh auth login` fails, op-env continues |
| No GITHUB_TOKEN in template | Skip — only runs when GITHUB_TOKEN is resolved |
| Multiple concurrent sessions | Safe — Keychain handles concurrent writes |
| PAT rotated in 1Password | Refreshed on next session start (op-env re-resolves) |
| Non-op-env gh usage | Falls back to Keychain auth (from last op-env session) or plugin |

## Alternative Options (Considered, Not Recommended)

### Option B: Remove 1Password gh Plugin Entirely
- **Pro:** Simplest possible fix — no alias, no conflict
- **Con:** Breaks `gh` usage outside op-env sessions (no auth at all unless manually configured)
- **Verdict:** Too aggressive — Drew may want to use `gh` outside Claude Code

### Option C: Fix Env Var Propagation
- **Pro:** Makes the current design work as intended
- **Con:** Claude Code's Bash tool env behavior may be intentional/unfixable from our side
- **Con:** Even if fixed, the alias/unalias dance remains fragile
- **Verdict:** Treating symptoms, not the root cause

### Option D: Replace Alias with Function
- **Pro:** Functions take precedence over aliases and can check env vars dynamically
- **Con:** Still depends on GITHUB_TOKEN being in env (same propagation problem)
- **Verdict:** Slightly better than current, but same fundamental fragility

## Test Strategy

### Unit Tests (in test-op-env.sh)
1. When GITHUB_TOKEN is resolved, `gh auth login --with-token` is called
2. When GITHUB_TOKEN is NOT resolved, `gh auth login` is not called
3. When `gh` binary is missing, op-env doesn't fail
4. The `gh auth login` call happens BEFORE `exec "$@"` (not after)

### Functional Tests (manual)
1. Start session via `ccc` → run `gh auth status` → should show PAT in keyring (not just env)
2. Run `gh pr list` → no 1Password prompt
3. Run `gh issue create` → no 1Password prompt
4. Outside op-env: run `gh auth status` → keyring auth still available from last session

### CI Tests
- Mock `gh` binary in test helpers (like mock `op`)
- Verify the `gh auth login` call receives the correct token on stdin

## Implementation Order

1. Add mock `gh` to test helpers
2. Write tests for `gh auth login` integration
3. Modify `bin/op-env` to call `gh auth login --with-token` after resolution
4. Update `.zshrc` to remove fragile unalias logic
5. Run through CI via PR
6. Manual functional testing after merge
