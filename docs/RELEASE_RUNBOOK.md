# Kadd — Production Release Runbook

This runbook is the final release path for Kadd. It deliberately separates CI artifact validation from a real Google Play production release.

## 1. CI release configuration

The release workflow supports production AdMob configuration through GitHub Actions secrets while retaining Google's test IDs when production values are not configured. The workflow also supports an external production keystore; without that keystore, the release artifact is a CI validation build and is **not** a Play production upload.

Configure these repository secrets only when the corresponding production configuration is ready:

- `KADD_ADMOB_APP_ID`
- `KADD_ADMOB_BANNER_ID`
- `KADD_ADMOB_INTERSTITIAL_ID`
- `KADD_RELEASE_KEYSTORE_PATH`
- `KADD_RELEASE_STORE_PASSWORD`
- `KADD_RELEASE_KEY_ALIAS`
- `KADD_RELEASE_KEY_PASSWORD`

Never commit the keystore, passwords, or AdMob credentials to Git.

## 2. AdMob gate

Before a production build:

1. Create the Kadd app in AdMob.
2. Create the production banner and interstitial ad units.
3. Store the production application ID and ad-unit IDs in the CI secrets above.
4. Run the release workflow.
5. Confirm the build log shows the production configuration was supplied through CI secrets.
6. Confirm the resulting app uses production IDs; do not submit an artifact built only with Google's test IDs.

The application keeps its existing ad behavior; this release configuration only supplies production identifiers.

## 3. Android signing gate

For Google Play:

1. Generate/obtain the Play upload keystore outside the repository.
2. Enable Google Play App Signing.
3. Store the upload keystore securely and provide its CI path/passwords through the release secrets.
4. Build the AAB from CI.
5. Verify the AAB is signed with the intended upload key before upload.

The debug-key fallback exists for CI build validation only. It must not be treated as the production Play signing configuration.

## 4. Play policy gate

Before submission, review the final manifest and complete the applicable Play declarations for:

- `QUERY_ALL_PACKAGES`
- Usage Access (`PACKAGE_USAGE_STATS`)
- Camera access used for exercise/prayer verification
- Exact alarms (`SCHEDULE_EXACT_ALARM`)
- `specialUse` foreground service
- Notifications and reboot recovery where applicable

The declarations must describe the actual user-facing purpose of Kadd. Do not claim capabilities the application does not provide.

## 5. Privacy and Data Safety gate

Kadd's privacy policy draft is maintained at `docs/PRIVACY_POLICY.md`.

Before production:

1. Publish the policy at a stable public HTTPS URL.
2. Add that URL to Google Play Console.
3. Complete Data Safety using the final production SDK configuration.
4. Re-check AdMob/UMP disclosures after production AdMob identifiers are configured.
5. Confirm the app's local-only camera/pose/rug processing statements match the shipped implementation.

## 6. Prayer-rug release gate

The current verifier uses generic ML Kit image labels plus conservative multi-capture policy. This is a safety-oriented verification mechanism, not a dedicated prayer-rug authentication model.

Until a validated dedicated model or stronger verification design is shipped, product copy must not describe the rug check as high-confidence authentication.

## 7. Final functional gate

Only after the codebase is frozen:

1. Fresh install.
2. Complete onboarding.
3. Grant/deny Usage Access and verify safe behavior.
4. Discover and select a real installed app.
5. Lock the app.
6. Complete exercise unlock and verify the exact configured duration.
7. Verify automatic relock after expiry.
8. Configure prayer lock and verify scheduling.
9. Verify recovery after process death/reboot.
10. Verify package removal handling.
11. Verify reset clears lock/alarm state.
12. Verify camera/pose/rug processing remains local.
13. Run the final physical-device regression matrix once.

Do not use an intermediate device test as a substitute for completing the release hardening work.

## 8. Release artifact rule

A successful GitHub Actions build proves that the project compiles, tests pass, and CI can produce APK/AAB artifacts. It does **not** by itself prove that the artifact is ready for Google Play production.

Production readiness requires all of the following:

- production AdMob identifiers configured
- production upload key configured outside Git
- Play App Signing configured
- signed AAB validated
- Play permission declarations completed
- public privacy policy published
- Data Safety completed
- final functional/device regression passed
- prayer-rug product claims kept within the actual verification capability
