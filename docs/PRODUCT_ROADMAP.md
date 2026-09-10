# Kadd — Product & Engineering Roadmap

## Product goal

Kadd is an Android-first digital-wellbeing app that turns access to distracting apps into a deliberate action: the user chooses apps to lock, then earns temporary access through physical effort. A separate prayer mode can lock the selected apps around prayer times and unlock them after a prayer-rug verification step.

The product must remain privacy-first: app inventory, usage detection, camera frames, pose landmarks, and rug verification stay on-device unless a future feature explicitly requires otherwise.

## Current foundation

- [x] Flutter Android application with Arabic RTL UI.
- [x] Real installed-app picker using native Android package discovery.
- [x] Usage Access based foreground-app detection.
- [x] Native foreground locking service.
- [x] Exercise repetition detection with ML Kit Pose Detection.
- [x] Prayer-city selection and AlAdhan prayer-time integration.
- [x] Prayer-time lock scheduling with AlarmManager.
- [x] Persistent next-prayer alarms restored after reboot/app update.
- [x] Prayer-rug verification flow with multi-capture, retry, and fail-closed policy.
- [x] Local persistence with SharedPreferences.
- [x] AdMob integration with consent flow.
- [x] GitHub Actions release APK build.

## Phase 1 — Stabilization

- [x] Remove fabricated home-screen repetition progress.
- [x] Persist daily earnings with a calendar-day boundary.
- [x] Persist activity dates and calculate a real current streak.
- [x] Make weekly repetition totals reset at the calendar-week boundary.
- [x] Add automated unit/widget coverage for the core model and exercise state machine.
- [ ] Verify every native lock transition on a physical Android device.
- [ ] Verify prayer alarm scheduling across reboot and device idle modes.
- [ ] Verify camera orientation/pose thresholds on multiple Android devices.
- [x] Add structured user-facing app-discovery error/diagnostic states.

## Phase 2 — Complete core experience

- [x] First-run onboarding explaining exactly how app locking works.
- [x] Guided Usage Access permission flow with verification after returning from Settings.
- [x] App picker search, installed-app refresh, locked/unlocked filtering, and empty/error states.
- [x] Per-app exercise target and unlock-duration configuration.
- [x] Defensive persistence and validation of per-app configuration.
- [x] Independent initialization of app discovery and prayer refresh so network failure does not block the app.
- [x] Reliable exercise session state: current reps, target, lost-tracking recovery, camera failure/retry, completion, and duplicate-completion protection.
- [x] Prayer setup: city, enabled prayers, delay, next prayer status, exact-alarm permission state, and active-lock state.
- [ ] Production-grade prayer-rug verification using a validated dedicated model or stronger verification design.
- [x] Statistics: daily, weekly, streak, total repetitions, earned minutes, prayer unlocks, and per-app history.
- [x] Settings: reset data, diagnostics, privacy information, permissions, and ads/privacy controls.

## Phase 3 — Reliability & security

- [x] Idempotent native lock/unlock state transitions.
- [x] Safe handling of package removal/uninstall while an app is locked.
- [x] Recovery after reboot for persisted app locks and known prayer alarms.
- [x] Recovery after app update through the boot/update receiver; service uses sticky restart semantics for process death.
- [x] Prevent stale exercise unlock windows and stale prayer locks.
- [x] Validate persisted MethodChannel/app configuration data defensively.
- [x] Avoid logging package lists or other unnecessary user/device data in normal operation.
- [x] Add regression tests for the discovered navigation and exercise-state bugs.

## Phase 4 — Production release

- [ ] Replace AdMob test IDs with production IDs.
- [ ] Configure Play App Signing/upload key outside the repository.
- [ ] Build signed AAB in CI.
- [ ] Complete Data Safety and sensitive-permission declarations.
- [ ] Host the privacy policy publicly and keep its wording aligned with the actual SDK/data flows.
- [ ] Verify foreground-service and package-visibility declarations against the current Google Play policy before submission.
- [ ] Internal test → closed test → production rollout.
- [ ] Crash/ANR monitoring and release checklist.

## Definition of done

A Kadd release is considered production-ready only when:

1. A fresh install can complete onboarding without developer intervention.
2. The user can select a real installed app and reliably trigger its lock.
3. Exercise completion grants exactly the configured temporary unlock.
4. Prayer locks activate at the scheduled time and are recoverable after reboot/process death.
5. No camera image, pose data, installed-app inventory, or usage history is uploaded by Kadd itself.
6. Core flows have automated tests and have been verified on physical Android hardware.
7. CI produces a signed release AAB using a production signing setup that is not committed to GitHub.

## Important production caveat

The current prayer-rug verifier uses generic on-device ML Kit image labels (`rug`, `carpet`, `mat`, etc.) plus a multi-capture confidence policy. This is a fail-closed verification flow, but generic image labels are not equivalent to a dedicated prayer-rug classifier. A production-quality release should either ship a validated custom on-device model or use a stronger verification design before claiming high-confidence prayer-rug authentication.
