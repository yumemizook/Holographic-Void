# Music & Gameplay Screen Overhaul Plan
A focused plan to enhance music selection UX (chart clarity, preview, rates up to 3.0x) and gameplay HUD adjustments aligned with requested features.

## Goals
- Surface current chart selection, MSD/grade visibility, and chart metadata on the wheel.
- Add chart preview (Space) with counts, skillset/difficulty, timeline + graph.
- Show personal best details in song info; add fine-grained rate control (EffectUp/Down, reset with both, 0.05x–3.0x with simultaneous press reset).
- Keep design consistent with Holographic Void styling and existing prefs (HV_ShowMSD, MSD colors).

## Scope & Constraints
- Target screens: ScreenSelectMusic (overlay + decorations) and ScreenGameplay overlays.
- Respect existing theme prefs (HV_ShowMSD, MSD color scale); ensure fallback when data absent.
- Input bindings: Space = preview toggle; EffectUp/EffectDown = ±0.05x rate; both = reset to 1x; clamp 0.05x–3.0x and ensure MSD/duration recompute on change.

## Implementation Steps
1) **Chart Selection UI**: Add clear indicator for current chart and dedicated difficulty selector near song info (supports autogen/fallback). Ensure keyboard/hover navigation matches existing input flow.
2) **Music Wheel Enhancements**: Display MSD and grade for the selected difficulty type on wheel items (grade uses local best); show artist + subtitle. For pack rows, left-align pack name and right-align progress/count with smaller size. Honor HV_ShowMSD and color scaling.
3) **Chart Preview (Space key)**: Implement preview panel with note counts (per type), selected skillset/difficulty display, timeline scrub + difficulty graph; ensure positioning doesn’t occlude wheel and supports toggle/close; recompute stats (MSD/duration) on rate change.
4) **Song Info Panel**: Add personal best block (score, grade, acc, rate, date/clear if available); degrade gracefully when no PB.
5) **Rate Adjustment Controls**: Bind EffectUp/EffectDown to change rate in 0.05x increments, clamp to 0.05x–3.0x, detect simultaneous press to reset to 1.00x; update displayed rate and propagate to MSD/duration/preview.
6) **Gameplay Screen Touchpoints**: 
   - Clean legacy life bar; keep single life bar with % counter updating with life changes.
   - Update score% and combo per note (not per second); add real-time accuracy tracker (4-digit precision) tied to per-note updates.
   - Move progress bar above; move song title to bottom of screen.
   - Compact judgment tally and include OK/NG counters; add real-time grade display (with mid-grades/colors if enabled); reuse existing theme colors for grades/OK-NG unless unavailable.
   - Center combo; remove duplicate judgment display/animations.
7) **Testing & Polish**: Sanity-check navigation, messaging commands, and edge cases (no chart, packs, rate limits). Tune layout for readability with theme fonts/colors.
8) **Difficulty Graph Research**: Review local themes and available online references to choose an implementation approach for the preview difficulty graph (prefer existing MSD curve if suitable).
9) **Results Screen Leaderboards**: Merge local and online leaderboards into a single view with a toggle button; verify leaderboard API calls and data validity, and ensure merged list renders correctly.
10) **Results Screen Left Panel**: Show chart name, author, selected rate; score% and WifeDP float; clear type and grade; compact judgment tally with MA/PA ratio; note-type hits; mean/std dev/largest offset metrics.
11) **Results Testing**: Confirm toggle behavior, data fetch, and layout for merged leaderboards; validate left-panel stats and formatting.

## Rough ASCII Mockup (Results Screen)
```
┌────────────────────────────────────────────────────────┬──────────────────────────────────────────────┐
│ CHART INFO (left)                                     │  LEADERBOARD (right)                         │
│────────────────────────────────────────────────────────│  ┌─────────────── Toggle ───────────────┐    │
│ Title: Song Name (Subtitle)                           │  │ [ LOCAL ]   [ ONLINE ]                │    │
│ Artist: Artist Name                                   │  └───────────────────────────────────────┘    │
│ Rate: 1.05x                                           │  Rank  Player        Score%   WifeDP   Grade   │
│                                                        │  1     AAAplayer     99.12    12.34    AAA    │
│ Score: 98.45%   WifeDP: 11.87                         │  2     BBuser        97.02    11.10    AA+    │
│ Clear: PFC   Grade: AAA                                │  3     CCuser        95.55    10.42    AA     │
│                                                        │  ...                                       │
│ Judgments: M:1234 P:56 G:3 B:1 Miss:0  OK:12  NG:0     │                                              │
│ MA/PA: 95.7%                                           │                                              │
│ Note Hits: Tap 1300  Hold 200  Mine 0  Lift 2  Roll 0  │                                              │
│ Offsets (ms): Mean +3.2  StdDev 12.5  Max +28/-31      │                                              │
└────────────────────────────────────────────────────────┴──────────────────────────────────────────────┘
```

## Open Questions
- None pending.
