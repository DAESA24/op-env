# Changelog

## 2026-03-23

- `--help` / `-h` flag with full usage documentation (PR #18, Issue #13)
- `--version` / `-v` flag, starting at v0.2.0 (PR #17, Issue #14)
- Functional test suite: 56 tests, mock op, CI integration (PR #16, Issue #15)
- Fixed bash 3.2 compatibility: replaced `mapfile` with `while-read` loops (production bugfix)
- Fixed PR review B1 check: scoped to added code lines only (was matching comments)
- Fixed PR review B2 check: scoped to `bin/op-env` only (companion scripts end with `exit`, not `exec`)

## 2026-03-20

- Fail-closed validation: aborts if any secrets fail to resolve, `--partial` to override (PR #12, Issue #1)
- Dry-run status check via `--check` flag with safe 2-char previews (PR #8, Issue #2)
- Pre-commit secret scanning via `op-env-scan` companion script (PR #11, Issue #3)
- Configurable template path via `--tpl` flag and `OP_ENV_TPL` env var (PR #6, Issue #4)
- Secret count reporting on launch, `--quiet` to suppress (PR #9, Issue #5)
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
