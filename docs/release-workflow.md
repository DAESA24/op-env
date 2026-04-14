# Release-First Pipeline

Production binaries come exclusively from GitHub Releases, not from the dev working tree.

## Workflow

```mermaid
flowchart TD
    subgraph DEV ["Development"]
        A[Feature branch<br/>feat: / fix: commits] -->|PR merged| B[main branch]
    end

    subgraph RP ["release.yml — runs on every push to main"]
        B --> C{release-please}
        C -->|No release needed| D[Updates or opens<br/>release PR]
        C -->|Release PR merged| E[Creates GitHub Release<br/>+ version tag]
    end

    D -->|Accumulates commits<br/>in release PR| C

    subgraph PB ["publish-binary job — only when release created"]
        E -->|release_created = true| F[Checkout at tag]
        F --> G[Copy bin/op-env<br/>bake version from tag]
        G --> H{Bake verification<br/>grep for unbaked pattern}
        H -->|Pattern found| I[FAIL: bake failed]
        H -->|Clean| J[Upload op-env asset<br/>to GitHub Release]
    end

    subgraph USER ["User Updates"]
        J --> K[op-env-update<br/>~/.local/bin/op-env-update]
        K --> L{Compare versions}
        L -->|Already current| M[Skip: up to date]
        L -->|New version| N[Download release asset]
        N --> O[Verify: --version check]
        O --> P[Atomic mv to<br/>~/.local/bin/op-env]
    end

    subgraph GUARD ["install.sh Guard"]
        Q[Run install.sh] --> R{Tagged release<br/>commit?}
        R -->|Yes: tag present| S[Install proceeds]
        R -->|No tag| T{--dev flag?}
        T -->|Yes| S
        T -->|No| U[EXIT 1: Warning<br/>points to releases page]
    end

    style E fill:#e8f5e9,stroke:#2e7d32
    style J fill:#e8f5e9,stroke:#2e7d32
    style P fill:#e8f5e9,stroke:#2e7d32
    style I fill:#ffebee,stroke:#c62828
    style U fill:#ffebee,stroke:#c62828
    style M fill:#fff3e0,stroke:#ef6c00
```

## What to Watch For

### After every merge to main
- **release-please** runs automatically and opens/updates a release PR (`chore(main): release vX.Y.Z`)
- Only `feat:` and `fix:` commits trigger a version bump
- `chore:`, `docs:`, `refactor:` commits are included in the changelog but don't bump the version on their own

### When you're ready to cut a release
1. Merge the release PR (e.g., `chore(main): release 0.7.0`)
2. release-please creates the GitHub Release + tag
3. `publish-binary` job fires automatically
4. Verify: check the release page for the `op-env` asset

### To update your local install
```bash
op-env-update
```

### If you need to install from dev (not a release)
```bash
./install.sh --dev
```
