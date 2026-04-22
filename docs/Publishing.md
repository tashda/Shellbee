# Publishing

This repository is set up so the public source can be pushed to GitHub without
including Apple account-specific signing configuration.

## Public Repository Rules

- Do not commit `Config/BuildSettings.local.xcconfig`.
- Do not commit Zigbee2MQTT server tokens or personal server URLs in sample data.
- Keep generated Docker backups and migration logs out of git.
- Keep production signing values local to your machine.

## Local Signing For Device Builds And App Store Archives

1. Copy `Config/BuildSettings.local.example.xcconfig` to `Config/BuildSettings.local.xcconfig`.
2. Set:
   `APP_DEVELOPMENT_TEAM`
   `APP_BUNDLE_ID`
   `APP_WIDGET_BUNDLE_ID`
   `APP_TESTS_BUNDLE_ID`
   `APP_UI_TESTS_BUNDLE_ID`
3. Open `Shellbee.xcodeproj`.
4. Confirm the shared `Shellbee` scheme is selected.
5. Build on device or archive with those local values.

## Pre-GitHub Checklist

1. Confirm `git status` does not include local override files or generated Docker artifacts.
2. Run the relevant simulator tests.
3. Review README and sample configs for local paths or personal values.
4. Push only after the working tree contains intentional source changes.

## Pre-App-Store Checklist

1. Use your local signing override file with your production team and bundle IDs.
2. Increment `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
3. Verify app icons, display name, and privacy strings.
4. Run the unit and integration test suites you depend on for release confidence.
5. Archive the `Shellbee` scheme in Release configuration.
