# Debugging Missing Q4-Q6 Answers Issue

## Problem Statement
Users report that questionnaire answers for questions 4-6 (q4, q5, q6) are not being sent in API payloads, even though the user can proceed through the questionnaire and submit it.

## Recent Improvements (Latest Commit)

### 1. **Review Dialog Before Submission**
When the user clicks "Submit", they now see a dialog showing all 6 answers:
- q1: [value]
- q2: [value]
- q3: [value]
- q4: [value]
- q5: [value]
- q6: [value]

**This is critical for debugging**: If q4, q5, q6 show as **0**, it means they were never captured by the sliders on page 2.

### 2. **Console Logging**
Added detailed logging that prints:
```
=== QUESTIONNAIRE SUBMISSION ===
Total questions: 6
All answers captured: [true/false]
q1: [value] (changed: [true/false])
q2: [value] (changed: [true/false])
...
q6: [value] (changed: [true/false])
=======================
```

**To view logs**:
- Run: `flutter run`
- Open Chrome DevTools or your device's debugger
- Look for the pattern `=== QUESTIONNAIRE SUBMISSION ===` in the console

### 3. **Slider Interaction Logging**
Added `DEBUG_SLIDER` logging:
```
DEBUG_SLIDER: index=3, value=45.0
DEBUG_SLIDER: index=4, value=60.0
...
```

This tells us whether sliders on page 2 (indices 3, 4, 5) are firing their `onChanged` callbacks.

### 4. **Enhanced Error Handling**
- `toPayload()` now validates that answers array has exactly 6 items and throws a clear error if not
- `syncPending()` catches payload creation errors and logs them
- All service errors are printed to console for diagnosis

## How to Debug

### Step 1: Test with Logging
1. Run the app: `flutter run`
2. Complete a meditation session
3. Answer all questionnaire questions
4. Watch the console for:
   - `DEBUG_SLIDER` messages for each question adjustment
   - The `=== QUESTIONNAIRE SUBMISSION ===` block when you click Submit

### Step 2: Check the Review Dialog
1. Before clicking final "Submit" in the review dialog
2. Look at the displayed values for q4, q5, q6
3. If they show 0, the sliders on page 2 didn't fire

### Step 3: Verify Local Storage
```bash
# Check what was actually stored locally:
# On Android: /data/data/com.example.meditative_clarity_hub/shared_prefs/
# On iOS: ~/Library/Containers/...
```

Look for the latest session JSON to see if answers[3], [4], [5] have values.

## Possible Root Causes

### Cause 1: Sliders on Page 2 Not Fireing onChanged
**Symptoms**:
- q4, q5, q6 show as 0 in review dialog
- DEBUG_SLIDER logs for indices 3, 4, 5 are missing
- "changed" flags are false for indices 3, 4, 5

**Solution**: Likely a Flutter/Platform-specific Slider issue on page 2. May need to:
- Verify Slider widget is rendering correctly
- Check if ListView inside PageView is causing layout issues
- Test on different devices/Flutter versions

### Cause 2: Page 2 Sliders Are Firing, But Values Are Lost
**Symptoms**:
- DEBUG_SLIDER logs show indices 3, 4, 5 being updated
- But review dialog shows 0 for q4, q5, q6
- Console shows correct values at submission time

**Solution**: Issue in state persistence. Check:
- If QuestionnairePage state is being recreated
- If _answers list is being reset somewhere
- PageView builder lifecycle

### Cause 3: Values Captured But Lost in Sync
**Symptoms**:
- Review dialog shows correct values
- Answers are stored locally (verify in localStorage JSON)
- But APIs don't receive q4, q5, q6

**Solution**: Issue in sync process. Check:
- Google Apps Script is receiving the full payload
- Network inspection to see actual POST body
- JSON serialization of the answers array

## Code Changes Made

### File: `lib/main.dart`

#### New Method: `_allAnswersComplete()`
```dart
bool _allAnswersComplete() {
  // Check that all answers have been marked as changed
  return _answers.every((answer) => answer.changed);
}
```

#### Enhanced: `_finish()` Method
- Added validation to ensure all 6 answers are marked as `changed`
- Shows review dialog with all 6 answers before submission
- Added console logging with clear formatting

#### Enhanced: `_updateAnswer()` Method
- Added `DEBUG_SLIDER` logging to track slider interactions

#### Enhanced: `toPayload()` Method
- Added validation that answers array has exactly 6 items
- Throws `StateError` if array is too short

#### Enhanced: `syncPending()` Method
- Added try-catch around payload creation
- Logs any errors when converting sessions to payloads

## Next Steps

1. **Run the app and test the questionnaire**
2. **Look for DEBUG_SLIDER messages in the console**
3. **Check the review dialog for q4, q5, q6 values**
4. **Report the console output back**

This will help narrow down where the issue is occurring.
