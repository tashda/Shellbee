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

Every entry in `skippedTests` is tech debt with a tracking reason. When the
underlying problem is fixed, the skip entry should be removed in the same PR
as the fix.

### Currently skipped

| Test | Reason |
|---|---|
| `Z2MIntegrationTests` (entire class) | Requires the docker z2m bridge on `localhost:8080`, which Fast CI does not start. Runs in Full CI instead. |
| `ConnectionHistoryTests` (entire class) | `setUp()` calls `MainActor.assumeIsolated { … }` from a nonisolated context; Xcode 26.3 turns this into a SIGABRT at runtime. Fix: migrate to `async throws setUp` and drop the assume-isolated call. |
| `HomeLayoutStoreTests` (entire class) | Test methods instantiate `HomeLayoutStore` (`@Observable` → implicit `@MainActor`) from a class that XCTest launches through a nonisolated bridge on Xcode 26.3, crashing the host app before the test body runs. Fix: restructure the class's isolation. |
| `NotificationPreferencesTests` (entire class) | Sync `setUp()` on a nonisolated class with `@MainActor` test methods — Xcode 26.3 fails to bridge isolation and crashes. Fix: mark the class `@MainActor` and migrate setUp/tearDown. |
| `ConnectionConfigTests/testSaveAndLoad()` | Reads a token from the Keychain that was just written. iOS simulator on GitHub runners has no provisioning profile, so `SecItem*` silently no-ops; the load returns nil. Fix: abstract the Keychain read/write so tests can inject an in-memory store. |
| `ConnectionConfigTests/testSecondLoadAfterLegacyMigrationStillReturnsToken()` | Same Keychain limitation. |

### How to remove an entry

Fix the underlying cause, run `-testPlan Shellbee-CI` locally to confirm it
passes, then delete the line from `skippedTests`. The next CI run validates
that nothing regressed.
