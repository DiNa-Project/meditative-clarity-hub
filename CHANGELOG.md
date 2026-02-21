# Changelog

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
