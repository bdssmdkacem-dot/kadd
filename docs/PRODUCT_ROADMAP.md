# Kadd — Product & Engineering Roadmap

## Product goal

Kadd is an Android-first digital-wellbeing app that turns access to distracting apps into a deliberate action: the user chooses apps to lock, then earns temporary access through physical effort. A separate prayer mode can lock the selected apps around prayer times and unlock them after a prayer-rug verification step.

The product must remain privacy-first: app inventory, usage detection, camera frames, pose landmarks, and rug verification stay on-device unless a future feature explicitly requires otherwise.

## Current foundation

- Flutter Android application with Arabic RTL UI.
- Real installed-app picker using native Android package discovery.
- Usage Access based foreground-app detection.
- Native foreground locking service.
- Exercise repetition detection with ML Kit Pose Detection.
- Prayer-city selection and AlAdhan prayer-time integration.
- Prayer-time lock scheduling with AlarmManager.
- Prayer-rug verification pipeline using on-device image labeling.
- Local persistence with SharedPreferences.
- AdMob banner/interstitial integration with test identifiers.
- GitHub Actions release APK build.

## Phase 1 — Stabilization (current)

- [x] Remove fabricated home-screen repetition progress.
- [x] Persist daily earnings with a calendar-day boundary.
- [x] Persist activity dates and calculate a real current streak.
- [ ] Add automated unit/widget coverage for models and state transitions.
- [ ] Verify every native lock transition on a physical Android device.
- [ ] Verify prayer alarm scheduling across reboot and device idle modes.
- [ ] Verify camera orientation/pose thresholds on multiple Android devices.
- [ ] Add structured user-facing error states instead of silent initialization failures.

## Phase 2 — Complete core experience

- [ ] First-run onboarding explaining exactly how app locking works.
- [ ] Guided Usage Access permission flow with verification after returning from Settings.
- [ ] App picker search, installed-app refresh, locked/unlocked filtering, and empty/error states.
- [ ] Per-app exercise target preview and difficulty configuration.
- [ ] Reliable exercise session state: current reps, target, pause/retry, lost-tracking recovery, completion.
- [ ] Prayer setup: city, enabled prayers, delay, next prayer status, and clear active-lock state.
- [ ] Prayer verification flow with camera guidance and failure/retry handling.
- [ ] Statistics: daily, weekly, streak, total repetitions, earned minutes, and per-app history.
- [ ] Settings: reset data, diagnostics, privacy policy, permissions, ads/privacy controls.

## Phase 3 — Reliability & security

- [ ] Idempotent native lock/unlock state transitions.
- [ ] Safe handling of package removal/uninstall while an app is locked.
- [ ] Recovery after process death, reboot, force-stop, and app update.
- [ ] Prevent stale unlock windows and stale prayer locks.
- [ ] Validate all MethodChannel arguments defensively on the Kotlin side.
- [ ] Avoid logging package lists or other unnecessary user/device data.
- [ ] Add regression tests for every discovered production bug.

## Phase 4 — Production release

- [ ] Replace AdMob test IDs with production IDs.
- [ ] Configure Play App Signing/upload key outside the repository.
- [ ] Build signed AAB in CI.
- [ ] Complete Data Safety and sensitive-permission declarations.
- [ ] Host the privacy policy publicly.
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
