# Changelog

## [0.2.0](https://github.com/DAESA24/op-env/releases/tag/v0.2.0) (2026-03-23)

### Features

* `--help` / `-h` flag with full usage documentation ([#18](https://github.com/DAESA24/op-env/pull/18))
* `--version` / `-v` flag ([#17](https://github.com/DAESA24/op-env/pull/17))
* Functional test suite: 56 tests, mock op, CI integration ([#16](https://github.com/DAESA24/op-env/pull/16))
* Fail-closed validation: aborts if any secrets fail to resolve, `--partial` to override ([#12](https://github.com/DAESA24/op-env/pull/12))
* Dry-run status check via `--check` flag with safe 2-char previews ([#8](https://github.com/DAESA24/op-env/pull/8))
* Pre-commit secret scanning via `op-env-scan` companion script ([#11](https://github.com/DAESA24/op-env/pull/11))
* Configurable template path via `--tpl` flag and `OP_ENV_TPL` env var ([#6](https://github.com/DAESA24/op-env/pull/6))
* Secret count reporting on launch, `--quiet` to suppress ([#9](https://github.com/DAESA24/op-env/pull/9))
* PR review framework v1.1: shellcheck + exfiltration checks + TTY verification in CI
* PR review results posted as comments on every PR (pass and fail)
* GitHub CLI conditional unalias integration for uninterrupted `gh` access in PAI sessions
* `ccp` and `cch` launch aliases alongside `ccc`

### Bug Fixes

* bash 3.2 compatibility: replaced `mapfile` with `while-read` loops ([e76cd60](https://github.com/DAESA24/op-env/commit/e76cd60))
* PR review B1 check: scoped to added code lines only (was matching comments)
* PR review B2 check: scoped to `bin/op-env` only (companion scripts end with `exit`, not `exec`)

## 0.1.0 (2026-02-27)

### Features

* Initial `op-env` wrapper with `exec`-based TTY preservation
* Architecture document written and shared
* Standardized on UUIDs for vault/item references (names break on rename)

### Earlier iterations (pre-release)

* v2: `op run --env-file ... -- claude` — no TTY passthrough
* v1: `op inject` hook writing `.env` at session start — secrets on disk
