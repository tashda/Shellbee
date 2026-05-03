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

`ci-full.yml` uses the default `Shellbee.xctestplan` but mirrors the same
skip set on the `xcodebuild` command line via `-skip-testing` flags — the
same root causes apply on Full CI too because it's the same runner image.
The exception is `Z2MIntegrationTests`, which Full CI runs because it starts
the mock z2m bridge first (one method that hits the keychain still has to
be skipped — see the table below). If you add or remove a skip in this plan,
mirror the change in `.github/workflows/ci-full.yml`.

Every entry in `skippedTests` is tech debt with a tracking reason. When the
underlying problem is fixed, the skip entry should be removed in the same PR
as the fix.

### Currently skipped

| Test | Reason |
|---|---|
| `Z2MIntegrationTests` (entire class) | Requires the docker z2m bridge on `localhost:8080`, which Fast CI does not start. Runs in Full CI instead. |
| `BridgeRegistryTests` (entire class) | Each `registry.connect(...)` spawns a real network Task; on the GitHub macOS runner (no real bridge reachable) those Tasks race deallocation when the test class tears down between cases, producing intermittent `pointer being freed was not allocated` malloc crashes. Substance is covered by `MultiBridgeIntegrationTests` against the dual mock-bridge stack in Full CI. Fix: add a controller-injection seam so tests can construct a `BridgeSession` without dialing the network. Tracked in #83. |
| `ConnectionConfigTests/testSaveAndLoad()` | Reads a token from the Keychain that was just written. iOS simulator on GitHub runners has no provisioning profile, so `SecItem*` silently no-ops; the load returns nil. Fix: abstract the Keychain read/write so tests can inject an in-memory store. |
| `ConnectionConfigTests/testSecondLoadAfterLegacyMigrationStillReturnsToken()` | Same Keychain limitation. |
| `Z2MIntegrationTests/testReloadedPersistedConfigConnectsAndReceivesBridgeInfo()` | Skipped by Full CI only (this plan still runs the rest of `Z2MIntegrationTests`). Same Keychain limitation — it calls `ConnectionConfig.save()` then `.load()`. |

### Recently un-skipped

`ConnectionHistoryTests`, `HomeLayoutStoreTests`, and `NotificationPreferencesTests` were previously skipped due to Xcode 26.3 isolation bugs in their `setUp()` paths. Resolved by marking the classes `@MainActor` and converting setUp/tearDown to `async throws`. Tracked in #83.

### How to remove an entry

Fix the underlying cause, run `-testPlan Shellbee-CI` locally to confirm it
passes, then delete the line from `skippedTests`. The next CI run validates
that nothing regressed.
