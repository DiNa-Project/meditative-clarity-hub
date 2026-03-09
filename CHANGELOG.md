# Changelog

## 2026.02.21+7

- **Refactor:** Modularize app structure into `models/`, `services/`, and `pages/` with a thin `main.dart` entrypoint.
- **Change:** Keep app open after submission and return to main screen instead of closing.
- **Fix:** Enforce cooldown immediately after returning to main page from questionnaire flow.
- **Change:** Move session queue storage to SQLite (`sqflite`) with legacy migration support from `SharedPreferences`.
- **Add:** Queue retry metadata (`retry_count`, `next_retry_at`, `last_error`) with self-healing schema checks for older local DBs.
- **Fix:** Improve sync reliability for Google Apps Script redirects (`POST /exec` then follow redirect) and require explicit JSON success response before marking sessions synced.
- **Change:** Remove 10-day sync send window; allow syncing all unsynced sessions.
- **Add:** Connectivity/lifecycle-triggered sync retries and immediate retry path for active user sessions.
- **Change:** Meditation reminder now repeats daily until 10 recorded sessions, then auto-cancels.
- **Change:** Lab reminder is scheduled for the next day after the 10th recorded meditation session.
- **Fix:** Use inexact Android alarm mode to avoid `exact_alarms_not_permitted` submission failures.
- **Fix:** Harden questionnaire submit flow to avoid stuck `Submitting...` state on runtime failures.

## 2026.02.21+6

- **Fix:** Investigate and address missing q4-q6 questionnaire answers issue.
- **Add:** Review dialog showing all 6 answers before final submission.
- **Add:** Comprehensive console logging for debugging answer submissions.
- **Add:** Slider interaction logging (DEBUG_SLIDER) for diagnosing page 2 issues.
- **Add:** Enhanced error handling in sync service with detailed error messages.
- **Add:** Widget state stability improvements (ValueKeys for sliders and pages).
- **Add:** Answer completeness validation preventing incomplete submissions.
- **Add:** Detailed debugging guides (DEBUGGING_Q4_Q6_ISSUE.md, Q4_Q6_FIXES_SUMMARY.md).

## 2026.02.19+5

- Update live countdown timer in MM:SS format (e.g., "59:30").

## 2026.02.19+4

- Implement 1-hour meditation cooldown (replaces once-per-day limit).
- Add live countdown timer showing remaining time until next meditation.
- Auto-unlock meditation button when cooldown expires.
- Upgrade to timestamp-based tracking for precise cooldown management.
- Maintain offline-first sync pattern for data reliability.

## 2026.02.13+3

- Disable practice button during active meditation.

## 2026.02.13+2

- Update app display name to BSR.
- Add launcher icons for iOS and Android.
- Add Android network permissions for API sync.

## 2026.02.08+1

- Initial release.
- Onboarding for user name and start date.
- Meditation playback with completion flow.
- Practice mode (no data saved or synced).
- Questionnaire with 6 items and info dialogs.
- Local storage for sessions and profile.
- Sync to Google Apps Script endpoint.
- Daily meditation reminders (NZ time) and lab reminder.
