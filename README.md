# Meditative Clarity Hub

Meditation flow with onboarding, daily session, questionnaire, local storage, and Google Apps Script sync.

## Features

- **Onboarding**: capture user name + study start date.
- **Meditation**: main circular button plays `assets/meditation.mp3`.
- **Practice mode**: bottom-left mini button plays `assets/meditation_try.mp3` and opens the questionnaire without storing/syncing data.
- **Questionnaire**: 6 questions, two pages, info dialog for full wording.
- **Local storage**: device UUID + user profile in `SharedPreferences`; session answers in local SQLite (`sqflite`) for robust queued sync.
- **Sync**: unsent sessions are POSTed to a Google Apps Script endpoint and marked as synced after success.
- **Notifications**: daily meditation reminder at 8:00 PM NZ time until 10 meditation records are saved; lab reminder is scheduled for the next day after the 10th record.

## Data model (per session)

- `uuid`
- `username`
- `start_date`
- `time_start_meditation`
- `q1` … `q6`

## Notifications

- **Meditation reminders**: 8:00 PM NZ time every day, automatically stopped after 10 recorded meditation sessions.
- **Lab reminder**: 10:00 AM NZ time, scheduled the next day after the 10th recorded meditation session.

## Run

```bash
flutter pub get
flutter run
```

### Android notes

- Requires JDK 17 (Gradle).
- Core library desugaring is enabled in [android/app/build.gradle.kts](android/app/build.gradle.kts).

### iOS notes

- After submission, the app returns to the main page (it does not close itself).

## Sync endpoint

The current endpoint is set in [lib/services/meditation_sync_service.dart](lib/services/meditation_sync_service.dart). Update `MeditationSyncService._endpoint` to your server if needed.

## Google Apps Script payload

The app posts JSON with a `data` array, where each item is a session payload. See your script for parsing and storage.
