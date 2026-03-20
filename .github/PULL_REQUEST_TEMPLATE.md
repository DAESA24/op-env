## Summary

<!-- Brief description of what this PR does and which issue it addresses -->

Closes #

## Review Checklist

Automated checks (B1-B3, F1-F2) run in CI. The following require manual review:

- [ ] **R1 Fail-closed:** Every new error path exits before reaching `exec "$@"`
- [ ] **R2 Backwards compatible:** Existing `op-env <cmd>` usage works identically without new flags
- [ ] **R3 Proportionate:** The complexity added is justified by the problem it solves
- [ ] **R4 No chezmoi conflict:** This change does not introduce files that would conflict with dotfiles management

## Testing

<!-- How did you verify this works? -->
