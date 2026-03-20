# PR Review Criteria

Decision framework for evaluating changes to op-env. Every PR is evaluated against three tiers of criteria.

## Tier 1 — BLOCKING

Any single failure in this tier rejects the PR. These protect op-env's core properties.

| ID | Criterion | Threshold | Automated |
|----|-----------|-----------|-----------|
| **B1** | No secret exfiltration | Change must not write, log, or transmit resolved secret values via any channel — disk, stdout, stderr, or network | Yes — grep for file-write operators, network commands, and unmasked value references in diff |
| **B2** | TTY preservation | `exec "$@"` must remain the final action on the happy path of every script in `bin/` | Yes — verify last non-comment, non-blank line |
| **B3** | Shellcheck clean | All scripts in `bin/` must pass `shellcheck` with no errors | Yes — `shellcheck bin/*` |

**Why these three:** op-env exists to do two things — keep secrets out of files and preserve TTY for interactive tools. B1 and B2 protect those properties. B3 catches real bash bugs (unquoted variables, word splitting) that could cause silent failures or security issues.

## Tier 2 — FLAGGED

Automated detection with human judgment. CI flags these as warnings; the reviewer decides if the violation is justified.

| ID | Criterion | What's Flagged | Automated |
|----|-----------|---------------|-----------|
| **F1** | Complexity growth | Lines added exceed 50% of the current script's size | Yes — diffstat comparison |
| **F2** | New external commands | Commands in the diff that aren't in the allowlist | Yes — diff parsed for new command names |

**Allowlist (F2):** `bash`, `sh`, `op`, `git`, `grep`, `sed`, `cut`, `tr`, `echo`, `printf`, `env`, `exec`, `wc`, `read`, `test`, `exit`, `shift`, `getopts`, `getopt`, `local`, `return`, `source`, `true`, `false`, `set`, `unset`, `export`, `eval`, `cat`, `head`, `tail`, `sort`, `awk`, `tput`, `mkdir`, `chmod`, `cp`, `ln`, `rm`, `ls`, `diff`, `basename`, `dirname`, `realpath`, `readlink`, `date`, `sleep`, `wait`, `kill`, `trap`, `ulimit`

This is intentionally broad — most standard bash/coreutils commands are allowed. The check catches truly external additions (e.g., `python`, `node`, `jq`, `curl`).

## Tier 3 — REVIEW

Human or agent evaluates. These appear as a checklist in the PR template.

| ID | Criterion | Question |
|----|-----------|----------|
| **R1** | Fail-closed | Does every new error path exit before reaching `exec "$@"`? |
| **R2** | Backwards compatible | Does existing `op-env <cmd>` usage work identically without new flags? |
| **R3** | Proportionate | Is the complexity added justified by the problem it solves? |
| **R4** | No chezmoi conflict | Does this change introduce files that would conflict with dotfiles management? |

## How to Use This

**As a contributor:** Before opening a PR, mentally check B1-B3. CI will catch mechanical violations, but understanding the criteria helps you design changes that pass naturally.

**As a reviewer:** CI handles B1-B3 and flags F1-F2. Your job is the R1-R4 checklist in the PR template. If all BLOCKING checks pass and you're satisfied with R1-R4, approve. If a FLAGGED item fires, use your judgment — the flag is information, not a veto.

**Scoring:**
- All B checks pass + R checklist complete → **Approve**
- Any B check fails → **Request changes** (non-negotiable)
- F checks flagged → **Reviewer decides** (warning, not blocking)
- R checklist items unchecked → **Reviewer explains why** (either check it or note the justification)
