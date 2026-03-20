# Changelog

## 2026-03-20

- Configurable template path via `--tpl` flag and `OP_ENV_TPL` env var (PR #6)
- File-existence guard exits with clear error if template not found
- Added PR review framework v1.1: shellcheck + exfiltration checks + TTY verification in CI
- PR review results posted as comments on every PR (pass and fail)
- Formalized as tracked project with git repo and GitHub mirror
- Standardized on UUIDs for vault/item references (names break on rename)
- Added GitHub CLI conditional unalias integration for uninterrupted `gh` access in PAI sessions
- Added `ccp` and `cch` aliases alongside `ccc`
- Architecture document expanded: executive summary, table of contents, UUID rationale, GitHub token handling

## 2026-02-27

- Initial architecture document written and shared
- op-env v3: `exec`-based wrapper with TTY preservation (current design)

## Earlier iterations (pre-documentation)

- v2: `op run --env-file ... -- claude` — no TTY passthrough, Claude Code fell back to non-interactive mode
- v1: `op inject` hook writing `.env` at session start — secrets on disk, violated at-rest protection goal
