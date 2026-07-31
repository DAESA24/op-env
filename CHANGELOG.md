# Changelog

## [0.7.0](https://github.com/DAESA24/op-env/compare/v0.6.0...v0.7.0) (2026-07-31)


### Features

* **scan:** detect key material by shape, not only by known value ([ae01427](https://github.com/DAESA24/op-env/commit/ae01427d39c0206e1bf543463706ddafef3d3559))
* **scan:** detect key material by shape, not only by known value ([3b4f5b4](https://github.com/DAESA24/op-env/commit/3b4f5b4d2b3bb9dd07529a4e3c87f0bf3bc583c5)), closes [#39](https://github.com/DAESA24/op-env/issues/39)

## [0.6.0](https://github.com/DAESA24/op-env/compare/v0.5.0...v0.6.0) (2026-04-14)


### Features

* release workflow binary publishing ([803a502](https://github.com/DAESA24/op-env/commit/803a502c8852c9ec7bd7bf892a27b589bbd20940))
* **release:** add publish-binary job to release workflow ([1c52c6c](https://github.com/DAESA24/op-env/commit/1c52c6c080d2c1f158485ff3b2fe5684651b18dc))
* update mechanism via standalone update.sh ([e059f4e](https://github.com/DAESA24/op-env/commit/e059f4e471ef6312bb43948d3a70440720d92644))
* **update:** add update.sh and install to PATH as op-env-update ([0e41dbb](https://github.com/DAESA24/op-env/commit/0e41dbbec0bcd9ee65e0d1103efa91339fa9387f))

## [0.5.0](https://github.com/DAESA24/op-env/compare/v0.4.2...v0.5.0) (2026-04-14)


### Features

* install.sh release guard with --dev bypass ([3be08c4](https://github.com/DAESA24/op-env/commit/3be08c477c5c3472f4080b8bab4102866831d948))
* **install:** add release guard requiring --dev for untagged commits ([064c3fc](https://github.com/DAESA24/op-env/commit/064c3fcc95081ee6f207ba090aa9722b10242a7a))

## [0.4.2](https://github.com/DAESA24/op-env/compare/v0.4.1...v0.4.2) (2026-04-14)


### Bug Fixes

* **auth:** export GH_TOKEN to bypass 1Password plugin biometric prompts ([7e8d1ee](https://github.com/DAESA24/op-env/commit/7e8d1ee2750e288196d7a3c582d479743aa04e7c))
* **auth:** export GH_TOKEN to bypass 1Password plugin biometric prompts ([bb993ec](https://github.com/DAESA24/op-env/commit/bb993ec512e43fbc524bf51b14959a3a32230fc7)), closes [#29](https://github.com/DAESA24/op-env/issues/29)

## [0.4.1](https://github.com/DAESA24/op-env/compare/v0.4.0...v0.4.1) (2026-03-27)


### Bug Fixes

* **auth:** store GitHub PAT in Keychain via gh auth login at session start ([241c89f](https://github.com/DAESA24/op-env/commit/241c89f8c7f1dc58cd115c3a42c291eb53a80f7a))

## [0.4.0](https://github.com/DAESA24/op-env/compare/v0.3.1...v0.4.0) (2026-03-27)


### Features

* **install:** harden install.sh and add installation test suite ([eea17cc](https://github.com/DAESA24/op-env/commit/eea17cc0d9af0d42aeff701aa504f6ed52c6cc5a))
* **install:** harden install.sh and add installation test suite ([4ddf495](https://github.com/DAESA24/op-env/commit/4ddf495ce1ec5084f8e5bfa7217d480dc88891fd))

## [0.3.1](https://github.com/DAESA24/op-env/compare/v0.3.0...v0.3.1) (2026-03-23)


### Bug Fixes

* release-please config to update VERSION file using plain-text updater ([f07346d](https://github.com/DAESA24/op-env/commit/f07346d894873b2dfc1df0f4cad96ad31e194bde))
* use PAT for release-please to trigger PR checks on release PRs ([8ecfe7e](https://github.com/DAESA24/op-env/commit/8ecfe7eb867cb0843b3030348a1b262a843e031e))
* use version.txt for release-please simple type compatibility ([81f20ec](https://github.com/DAESA24/op-env/commit/81f20ec669dd3acf0a0d4bb6182fce4fe405ee8c))

## [0.3.0](https://github.com/DAESA24/op-env/compare/v0.2.0...v0.3.0) (2026-03-23)


### Features

* add --check flag for dry-run status reporting ([#8](https://github.com/DAESA24/op-env/issues/8)) ([d6f8d8c](https://github.com/DAESA24/op-env/commit/d6f8d8cf3d8ecff748b407ad3ab61d38074e63dc)), closes [#2](https://github.com/DAESA24/op-env/issues/2)
* add --help / -h flag with usage documentation ([#18](https://github.com/DAESA24/op-env/issues/18)) ([30f8228](https://github.com/DAESA24/op-env/commit/30f8228c24e9f10f67968981a11b4ae954034083)), closes [#13](https://github.com/DAESA24/op-env/issues/13)
* add --version / -v flag ([#17](https://github.com/DAESA24/op-env/issues/17)) ([dbec053](https://github.com/DAESA24/op-env/commit/dbec0535fce68db8b3fe805ee95b9f1fd487b446)), closes [#14](https://github.com/DAESA24/op-env/issues/14)
* add functional test suite with 47 tests ([#16](https://github.com/DAESA24/op-env/issues/16)) ([be6299a](https://github.com/DAESA24/op-env/commit/be6299af026b8ed1997ad445954ef9d0836d332f)), closes [#15](https://github.com/DAESA24/op-env/issues/15)
* add op-env-scan for pre-commit secret leak detection ([#11](https://github.com/DAESA24/op-env/issues/11)) ([b057833](https://github.com/DAESA24/op-env/commit/b057833f49fe12cf516a4156f6b3dab48ad083cc)), closes [#3](https://github.com/DAESA24/op-env/issues/3)
* add PR review framework v1.1 ([4166142](https://github.com/DAESA24/op-env/commit/4166142b7dd3cd85d0eecbdf254296fae9385703))
* automated release workflow with release-please and docs-sync CI ([#20](https://github.com/DAESA24/op-env/issues/20)) ([e0a5159](https://github.com/DAESA24/op-env/commit/e0a51599b742c528d9707d706f6dce6aadf186ad)), closes [#19](https://github.com/DAESA24/op-env/issues/19)
* configurable template path via --tpl flag and OP_ENV_TPL env var ([#6](https://github.com/DAESA24/op-env/issues/6)) ([9932b16](https://github.com/DAESA24/op-env/commit/9932b16b5973874cf57b0bb3cec0e8122239454b)), closes [#4](https://github.com/DAESA24/op-env/issues/4)
* initial release of op-env ([a0ca62d](https://github.com/DAESA24/op-env/commit/a0ca62dd36516995641204fc88d1602c595cb129))
* post PR review results as comment on every run ([7ba8662](https://github.com/DAESA24/op-env/commit/7ba8662010291233ccc3ff6604c0a2b2bb632865))
* report secret resolution count on launch ([#9](https://github.com/DAESA24/op-env/issues/9)) ([01e7b67](https://github.com/DAESA24/op-env/commit/01e7b67bd9027d329bdb9cf67ec6e054c412fe3b)), closes [#5](https://github.com/DAESA24/op-env/issues/5)
* validate all secrets resolved before launch ([#12](https://github.com/DAESA24/op-env/issues/12)) ([07c17e6](https://github.com/DAESA24/op-env/commit/07c17e653334e34cc5b74b66daa856770fb2b173)), closes [#1](https://github.com/DAESA24/op-env/issues/1)


### Bug Fixes

* B1 check now scans only added code lines, not comments or diff headers ([f1973b7](https://github.com/DAESA24/op-env/commit/f1973b71417c75b02524bc044f36c39a49b8b2e5))
* replace mapfile with while-read loops for macOS bash 3.2 compat ([e76cd60](https://github.com/DAESA24/op-env/commit/e76cd60e6c36b04f235a15c3e08a147f6c85a98f))
* scope B2 TTY check to bin/op-env only ([c67bf47](https://github.com/DAESA24/op-env/commit/c67bf474a5f52c74523ea7bc71ad18f3fcb0cf02))

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
