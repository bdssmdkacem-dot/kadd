# Kadd — Google Play Release Checklist

## A. Build and signing

- [x] CI analyzer passes.
- [x] Flutter tests pass.
- [x] CI produces an installable release APK.
- [ ] Configure a real Play upload key outside the repository.
- [ ] Configure Play App Signing.
- [ ] Build and validate a signed AAB.
- [ ] Keep the upload keystore and passwords out of Git.

## B. AdMob

- [ ] Create the production AdMob app and ad units.
- [ ] Replace the Google test application ID in `android/app/src/main/AndroidManifest.xml`.
- [ ] Replace the test banner/interstitial IDs in `lib/services/ads_service.dart`.
- [ ] Verify UMP consent behavior for applicable regions.
- [ ] Never ship a production release with Google's test IDs.

## C. Sensitive permissions

### QUERY_ALL_PACKAGES

Kadd uses broad app visibility because its core user-facing feature is selecting installed apps to lock and enforcing those locks. Google Play treats installed-app inventory as sensitive and restricts `QUERY_ALL_PACKAGES`; the permission must be justified through the Play Console declaration process and the app description must clearly explain the core functionality.

Before submission:

- [ ] Complete the Play Console Permissions Declaration Form for `QUERY_ALL_PACKAGES`.
- [ ] Explain why broad visibility is required for the app picker and enforcement flow.
- [ ] Confirm that installed-app inventory is not sold, shared, or used for advertising/analytics monetization.
- [ ] Keep the privacy disclosure consistent with the actual implementation.

### Usage Access

- [ ] Explain the Usage Access requirement prominently before sending the user to Android Settings.
- [ ] Confirm the app still works safely when access is denied.

### Camera

- [ ] Explain that camera processing is used only for exercise/prayer verification.
- [ ] Confirm frames are not uploaded by Kadd.

### Exact alarms

- [ ] Explain why exact alarms are required for prayer-lock timing.
- [ ] Verify behavior when exact-alarm access is denied.

## D. Foreground service

Kadd uses `specialUse` because its enforcement service does not map cleanly to the standard location/media/camera/data-sync types. Google Play requires foreground-service declarations to match the real user-facing use case and subjects `specialUse` to review.

- [ ] Complete the Play Console foreground-service declaration.
- [ ] Provide an accurate description of the user-initiated app-lock enforcement use case.
- [ ] Verify the persistent notification is clear and accurate.
- [ ] Verify the service stops when there are no configured locks.
- [ ] Prepare a short review/demo video showing the user enabling a lock and the service enforcing it.

## E. Privacy / Data Safety

- [x] Draft privacy policy: `docs/PRIVACY_POLICY.md`.
- [ ] Publish the privacy policy at a stable public HTTPS URL.
- [ ] Add the final public URL to Google Play Console.
- [ ] Complete the Data Safety form based on the final production SDK configuration.
- [ ] Re-check AdMob/UMP data disclosures after production IDs are configured.
- [ ] Re-check all permissions after the final manifest is frozen.

## F. Functional release gates

- [ ] Fresh install → onboarding → Usage Access → app picker.
- [ ] Select a real installed app and lock it.
- [ ] Verify exercise completion grants exactly the configured minutes.
- [ ] Verify expired unlocks relock automatically.
- [ ] Verify prayer lock activates at the scheduled time.
- [ ] Verify prayer lock survives app process death/reboot.
- [ ] Verify package removal does not crash or leave an impossible lock.
- [ ] Verify reset removes app-lock and prayer-alarm state.
- [ ] Verify all camera/pose/rug data remains local.
- [ ] Perform the final physical-device regression pass only after the codebase is frozen.

## G. Current known release blocker

The prayer-rug verifier currently uses generic ML Kit image labels with a conservative multi-capture policy. It should not be advertised as high-confidence prayer-rug authentication until a validated dedicated model or stronger verification design is shipped.
