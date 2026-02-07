# Meditative Clarity Hub

Meditation flow with onboarding, daily session, questionnaire, local storage, and Google Apps Script sync.

## Features

- **Onboarding**: capture user name + study start date.
- **Meditation**: main circular button plays `assets/meditation.mp3`.
- **Practice mode**: bottom-left mini button plays `assets/meditation_try.mp3` and opens the questionnaire without storing/syncing data.
- **Questionnaire**: 6 questions, two pages, info dialog for full wording.
- **Local storage**: device UUID, user profile, and session answers stored in `SharedPreferences`.
- **Sync**: unsent sessions are POSTed to a Google Apps Script endpoint and marked as synced after success.
- **Notifications**: daily reminders for start date through start date + 9; lab reminder on start date + 10 (New Zealand time).

## Data model (per session)

- `uuid`
- `username`
- `start_date`
- `time_start_meditation`
- `q1` … `q6`

## Notifications

- **Meditation reminders**: 8:00 PM NZ time, day 0–9 (start date inclusive).
- **Lab reminder**: 10:00 AM NZ time, day 10.

## Run

```bash
flutter pub get
flutter run
```

### Android notes

- Requires JDK 17 (Gradle).
- Core library desugaring is enabled in [android/app/build.gradle.kts](android/app/build.gradle.kts).

### iOS notes

- Apps cannot close themselves; the “Thank you” screen remains visible.

## Sync endpoint

The current endpoint is set in [lib/main.dart](lib/main.dart). Update `MeditationSyncService._endpoint` to your server if needed.

## Google Apps Script payload

The app posts JSON with a `data` array, where each item is a session payload. See your script for parsing and storage.
