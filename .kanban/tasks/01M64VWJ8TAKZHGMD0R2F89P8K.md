---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m64wg7d6efmcs66nqkz27s35
  text: |-
    For the Examples XCUITest tier (Scripts/test-examples.sh, ACPTabEndToEndTests etc.), from TestudoApp's profile, relayed by EditorKit; the full table is on Testudo ^j7xtywv. 95 tests took 2026 s, nearly all of it fixed per-action floors, not capture:
    - waitForExistence costs at least 1 s even when the element exists. Check `.exists` first (~400 s saved).
    - activate() before every typed key costs ~220 s. Only activate when the app isn't already frontmost.
    - Launching the app per test costs 3.6 s each, half of it terminating the previous app. Launch once per class.
    - Wait-for-idle costs at least 0.45 s per action, so the app's main loop never goes quiet. Look for repeating timers or animations in the demo app.
    Screenshots cost under 10 s in total.
  timestamp: 2026-10-29T22:29:15.814295+00:00
position_column: todo
position_ordinal: b380
title: Capture tests and the review gallery move to a nested IntegrationTests package; root swift test is unit-only; capture is fast and parallel
---
User directive, relayed by EditorKit (2026-10-29): screenshot galleries and every screen-capture test are integration tests.

- Move them into a nested `IntegrationTests/` SwiftPM package, following TestudoApp/IntegrationTests and the FoundationModels packages; it runs with `swift test --package-path IntegrationTests`.
- The root `swift test` is unit-only, with no capture. That is the per-card gate. Capture runs once per batch, at the end.
- Capture must be fast: a 20–45 minute capture tier is unacceptable. Find why AVK's is slow and fix it, ideally capturing several windows at once in one process rather than several processes fighting over the lock.
- Use EditorKit's capture API; don't fork it. EditorKit ^kssta7w (WindowCapture profiling) and ^yr0xx8d (moving EditorKit's captures) bring speed-ups for free.

- [ ] Inventory of every test that opens a window or captures, with an estimate of its run time
- [ ] IntegrationTests/Package.swift, depending on the root package by path
- [ ] Hosted, snapshot, pixel, focus-ring and gallery suites moved; root swift test opens no window (a structure test guards it)
- [ ] Slowness causes fixed (settle waits, per-test windows, .serialized); parallel capture where EditorKit's API allows
- [ ] Scripts and docs updated (test-examples.sh, ARCHITECTURE.md); timings before and after #cross-repo