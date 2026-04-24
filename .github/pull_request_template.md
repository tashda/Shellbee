## Summary

<!-- 1-3 bullets: what changed and why. Link any tracked issue. -->

## Scope

<!-- Which modules/files this touches. Helps reviewers spot accidental overlap
     with other in-flight PRs. -->

## Testing

- [ ] `xcodebuild test` passes locally
- [ ] Tested against the mock Z2M bridge (`docker-compose up`) if the change
      affects WebSocket, state, or bridge interactions
- [ ] Manual UI verification on a simulator for any user-visible change

## Release notes

<!-- One user-facing sentence, or `n/a` for internal-only changes. -->

## Checklist

- [ ] Branch is rebased on latest `main`
- [ ] No trailing ellipsis in UI copy
- [ ] No `Stepper` added for numeric inputs
- [ ] `DesignTokens` used instead of hard-coded spacing/sizing
- [ ] Public-facing copy (if any) still consistent with `PRIVACY.md`
