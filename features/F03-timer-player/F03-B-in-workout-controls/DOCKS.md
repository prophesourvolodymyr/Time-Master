# F03-B — In-Workout Controls & Media

Rest preview of next exercise, full-screen media overlay during workout, and mid-workout rest adjustment.

## 1. Rest Preview
- During rest: next exercise photo/video appears centered in a rounded card at ~50% opacity
- "Next: [Exercise Name]" below preview
- Smooth crossfade transition from active to rest
- Tap preview → opens full-screen viewer (see #2)

## 2. Full Media Preview During Workout
- Tap exercise photo during active workout → full-screen overlay opens (scale + fade animation)
- Timer visible in corner, continues running
- If video: play/pause/seek controls
- Tap/gesture dismisses overlay, returns to player
- Section end triggers normal transition even with overlay open

## 3. Mid-Workout Rest Adjustment
- "+15s" and "+30s" buttons during rest phase
- Tapping extends current rest timer
- Multiple taps stack; max 120s total rest per period
- Long-press timer → quick picker (15s, 30s, 60s, custom)

## Files
- `TimeMaster/Views/Player/WorkoutPlayerView.swift`
- `TimeMaster/Views/WorkoutDetail/MediaPreviewSheet.swift` (reuse)

## Verification
- [ ] Rest shows next exercise preview with name
- [ ] Tap during workout opens full-screen overlay, timer continues
- [ ] Overlay dismisses on tap/gesture, video playback works
- [ ] +15s/+30s buttons visible only during rest, extend timer correctly
- [ ] Max 120s enforced, section advances normally after rest ends
