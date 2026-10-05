# Test Plans

Two plans ship with the Shellbee scheme. Both are used by Xcode (pick from the
test plan selector in the scheme editor) and by CI via `xcodebuild -testPlan`.

## `Shellbee.xctestplan` — default

Runs everything. Used locally in Xcode and by the nightly/full CI workflow
(`ci-full.yml`). New tests automatically run here; nothing is skipped.

## `Shellbee-CI.xctestplan` — Fast CI gate

Runs unit tests only and skips a small set of tests that are known to fail
or crash specifically under the conditions of the GitHub macOS runner
(Xcode 26.3 strict concurrency, simulator without a provisioning profile for
Keychain, etc.). Used by `ci-fast.yml` to gate PRs.

`ci-full.yml` uses the default `Shellbee.xctestplan`. It runs the unit tests
first, then the four live-bridge suites against the dual mock z2m bridge it
starts, with one retry for WebSocket timing only.

Every entry in `skippedTests` needs a reason below. When the reason goes
away, delete the entry in the same PR.

### Currently skipped (Fast CI only)

| Test | Reason |
|---|---|
| `Z2MIntegrationTests` | Needs the mock bridge on `localhost:8080`; Fast CI doesn't start one. Runs in Full CI. |
| `MultiBridgeIntegrationTests` | Needs both mock bridges (`8080`, `8082`). Runs in Full CI. |
| `GroupDropIntegrationTests` | Needs both mock bridges. Runs in Full CI. |
| `NetworkMapIntegrationTests` | Needs both mock bridges; the paced scan takes about 26 s per bridge. Runs in Full CI. |

### History: the "Xcode 26.3 runner" skips (removed 2026-09-30)

Until 2.0.0 this plan skipped about 90 more tests as "crashes on the GitHub
runner, passes locally". They were two real problems, both fixed:

- **Isolated deinits.** The app defaults to `@MainActor`, so the compiler
  gave its classes isolated deinits. Before iOS 26.4 the Swift runtime
  aborts ("pointer being freed was not allocated") when one isolated deinit
  releases another. CI's simulator ran iOS 26.2; local simulators ran 26.4+.
  The app classes now declare `nonisolated deinit {}`, and Fast CI fails if
  a new isolated deinit appears (`.github/scripts/check-isolated-deinits.sh`).
- **Keychain.** CI built with `CODE_SIGNING_ALLOWED=NO`, so the test host had
  no entitlements and `SecItem*` returned nothing. CI now signs simulator
  builds ad hoc (`CODE_SIGN_IDENTITY=-`).

Use Full CI's `audit_skipped` dispatch input to run whatever this plan
still skips on the CI runner.

### How to remove an entry

Fix the underlying cause, confirm with the `audit_skipped` dispatch (or
`-testPlan Shellbee-CI` locally), then delete the line from `skippedTests`.
