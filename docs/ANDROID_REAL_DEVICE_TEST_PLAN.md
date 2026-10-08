# Kadd — Android real-device release test plan

Run this checklist on a physical Android 13+ device before the first production
rollout. CI validates the APK/AAB and Flutter logic; these cases validate
behavior that GitHub Actions cannot reliably prove without a real device.

## Lock lifecycle
- [ ] Grant Usage Access.
- [ ] Select one launchable app and enable its lock.
- [ ] Open the target app: Kadd LockActivity appears.
- [ ] Complete exercise: the target app opens for the configured minutes.
- [ ] Wait for expiry: the target app is blocked again.
- [ ] Configure two locked apps and verify no duplicate lock screens.
- [ ] Disable/remove a locked app while the service is running.

## Reboot and process recovery
- [ ] Reboot with at least one lock configured.
- [ ] Verify lock enforcement recovers after boot.
- [ ] Force-stop Kadd from Android Settings, then open a locked app.
- [ ] Verify the service restarts when required by persisted lock configuration.
- [ ] Update/reinstall Kadd over the existing installation and verify state.

## Package removal
- [ ] Lock an app.
- [ ] Uninstall that app.
- [ ] Verify the removed package disappears from Kadd.
- [ ] Confirm no stale lock activity is launched.

## Clock and timezone
- [ ] Configure one prayer lock.
- [ ] Change timezone and resume Kadd.
- [ ] Change system time across a prayer boundary.
- [ ] Verify alarms rebuild without duplicates.
- [ ] Disable exact-alarm access and verify a recoverable limitation.
- [ ] Re-enable exact-alarm access and verify alarms rebuild.

## Prayer lock
- [ ] Select a Moroccan city manually.
- [ ] Enable one prayer and use a short test delay.
- [ ] Verify the native alarm activates the lock at the expected time.
- [ ] Verify exercise unlock is rejected while prayer lock is active.
- [ ] Complete visual rug verification and confirm only the active prayer lock clears.
- [ ] Reboot during an active prayer lock and verify it remains protected.
- [ ] Confirm a second prayer alarm does not create duplicate lock activity.

## Camera and permissions
- [ ] Deny camera permission and verify a recoverable verification error.
- [ ] Grant camera permission and verify pose detection.
- [ ] Deny notification permission and verify the app remains stable with clear disclosure.
- [ ] Revoke Usage Access and verify Kadd detects the change after resume.

## Billing
- [ ] Install from a Play internal-test track.
- [ ] Verify the Premium product loads.
- [ ] Purchase with a license tester.
- [ ] Kill/relaunch and verify Premium remains active.
- [ ] Restore purchases and verify Premium returns.
- [ ] Cancel/expire the test subscription and verify entitlement follows Google Play state.

## Release gate
Production AAB is not ready until the above boxes are checked on a current
Android device and the Play Console policy declarations are accepted.
