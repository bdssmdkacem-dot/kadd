# Kadd — Google Play permission declarations

## QUERY_ALL_PACKAGES
Kadd's core user-facing function is allowing the user to choose any installed
launchable app and place that app under Kadd's lock. Broad package visibility is
required to present the selectable app inventory and keep the lock configuration
synchronized when apps are installed or removed.

Kadd does not upload, sell, or share installed-app inventory for advertising or
analytics monetization. It is used on-device for the user's selected app locks.

Play Console action: submit the required Permissions Declaration Form and
describe app locking / app selection as the core functionality. If Play rejects
broad visibility, redesign discovery around targeted package visibility before
production publication.

## SCHEDULE_EXACT_ALARM
Kadd uses SCHEDULE_EXACT_ALARM, not USE_EXACT_ALARM. Exact alarms activate a
user-configured prayer lock at the selected prayer time. The user can grant or
deny this special app access. Kadd checks canScheduleExactAlarms() and recovers
gracefully when access is unavailable.

Play Console action: declare the timed prayer-lock use case. Do not replace it
with USE_EXACT_ALARM, which is more restricted.

## FOREGROUND_SERVICE / FOREGROUND_SERVICE_SPECIAL_USE
Kadd uses one foreground service to enforce the user's selected app locks while
the user is actively using other apps. The service is user-visible through an
ongoing notification and is stopped when there are no configured locks.

Play Console action: complete the Android 14+ foreground-service declaration for
the specialUse type, including a short demonstration video showing app
selection, enabling the lock, opening the selected app, and Kadd intercepting it.

## CAMERA
Camera access is used only for exercise pose checks and visual prayer-rug
verification. It is requested at runtime when the relevant verification screen
is opened. The rug classifier is a visual verification signal, not proof of
prayer.

## POST_NOTIFICATIONS
Used for the visible foreground-service notification on Android 13+.

## Usage Stats
Kadd uses PACKAGE_USAGE_STATS to identify the foreground application so it can
enforce locks without an AccessibilityService. The user explicitly enables
Usage Access in Android Settings.

## Privacy constraint
Installed-app inventory and Usage Stats are sensitive device information.
Kadd must not send this information to AdMob, analytics, or unrelated servers.
Future telemetry must exclude these datasets by default.
