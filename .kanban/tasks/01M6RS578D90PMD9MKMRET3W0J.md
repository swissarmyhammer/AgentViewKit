---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6rt0m4t5jw2y5a4bh07rzcd
  text: |-
    Research (measured headless with a scratch copy of EK's ZZMinSizeRepro in the worktree's ScreenshotTests, not committed):

    - Mechanism: AgentThreadView's built-in attachment inspector (`.inspector(isPresented:)` in AttachmentInspectorModifier, present since Oct 21) makes AppKit take the thread content's minimum size from a zero-width probe: the content reports 241 x 787.5 at proposal width 0. Without the `.inspector` (host mode, or the modifier swapped for a background) the same thread fits 1180x760 (min 480 at any width >= 500).
    - What grows at narrow width: the session breadcrumb in AgentInfoHeader (SessionBreadcrumb on EK EditorBreadcrumbBar, added 1dc0efdf Nov 3 / 145c5cfd Nov 5, after the Oct 29 capture). AgentBreadcrumb gives the agent segment layout priority, so at the probe width the last crumb gets a sliver and EK wraps its title one character per line: header alone = 288 pt tall at <= 200 pt wide (16 pt at >= 400). With the crumb removed (experiment) the full thread is 435.5 pt min at every width, inspector included.
    - Not the cause: the request deck (119-134 pt at any width), the composer (90 pt at any width), EK's .boundedHeight, the inspector's safe-area padding (missing insets are 0 here), the transcript (75 pt).
    - Dead ends: the 'min at 1180 wide' probe of the repro mixes in the inspector's zero-width probe, so per-component numbers at 1180 were misleading until measured across widths.
  timestamp: 2026-11-06T16:10:36.058508+00:00
- actor: claude-code
  id: 01m6rwnm5vh2aqzn5z36zk3dtk
  text: |-
    Fix: AgentThreadView holds `.frame(minWidth: AgentThreadLayout.minimumWidth * fontScale)` (360 pt at the default font, ThemeFontScale(.ui)) inside the attachment inspector modifier, so the `.inspector`'s zero-width probe reads the thread at 360 pt: least size 360 x 560.5 (was 241 x 787.5); at 1180 x 760 it fits.

    What did not work (don't repeat):
    - `.frame(minWidth: 120)` on SessionBreadcrumb in AgentBreadcrumb: height fixed (467.5) but thread least width went to 336, and in the real capture EK's crumb menu drew ~120 pt right of its separator. With `maxWidth: .infinity` added, the crumb drew centered in the row.
    - `.frame(minWidth: 340)` on the AgentBreadcrumb row: height fixed, but the crumb menu drew over the separator chevron.
    - Row min width + crumb min width together: the repro run took 1120 s (layout churn).
    - Baseline check: without any fix and with the gallery window temporarily 820 tall, the crumb draws correctly, so the misplacement came from the frames around EK's bar, not before. Possible EK follow-up: EditorBreadcrumbBar's visible menu row misplaces when an ancestor/wrapping frame floors its width; and its last crumb wraps one character per line when squeezed.

    Thread least width grew 241 -> 360 pt; worth noting for hosts with narrow detail columns.

    ### implement — changed
    - evidence: 1 file — Sources/AgentViewKit/Thread/AgentThreadView.swift; commit 0ad2c52d on worktree-agent-af5a5026f1b53e997. Root swift build clean (only the allowed mlx warnings); swift test 1072 tests/123 suites + 50 tests/10 suites passed. ScreenshotTests swift test 32 tests/4 suites passed, incl. thePageShowsEachKeyScreenAndEachRecordedSnapshot; Gallery columns light+dark images present. Without the fix the same gallery test fails with the 787.5 clip.
    - next: /review
  timestamp: 2026-11-06T16:57:01.371641+00:00
- actor: claude-code
  id: 01m6rwtcyk39whptmhgj1cyma8
  text: |-
    ### review — clean
    - evidence: review sha b33f9c3c..HEAD — 1 file (Sources/AgentViewKit/Thread/AgentThreadView.swift), 7 validator runs attempted, 0 failed, 0 skipped; findings 0, confirmed 0, refuted 0
    - next: none — moved to done
  timestamp: 2026-11-06T16:59:37.811157+00:00
position_column: done
position_ordinal: ffffffc280
title: Thread with a pending permission request needs 787.5 pt of height
---
The "Gallery columns" key screen of the ScreenshotTests review gallery has no image: EK's capture refuses to clip it — "the window clips the screen: its content needs 1180.0×787.5 points, the window gives 1180.0×760.0".

EditorKit (editorkit-b5) reproduced it headless: it is AVK's thread view on its own — a thread + a pending permission request + the composer — whose minimum height is 787.5 pt at 1180 wide. Same on every EK from 7697fab0 through ba6b57d5, with any toolbar item or none (the gallery window is borderless, so no system toolbar is built). The last capture of that screen was Oct 29, so AVK's minimum height grew since then. The thread screens are 860 tall, so they fit.

A thread must not force a window to be that tall: the transcript scrolls, so the minimum height of the thread should be small. Find which part of the bars (the request deck in the bar, the permission request, the composer, the header) stopped compressing since Oct 29 and make the thread's minimum height small again. Do not enlarge the gallery window to hide it, and keep "multiline fields size to content; the inspector/thread scrolls, never a small fixed box" — if the deck itself is what is tall, it is the bar that must stay bounded, decide with the user if that conflicts.

Repro from EK: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-EditorKit/4c16fd9c-af46-4c5b-967c-20d45d45288d/scratchpad/avkrepro (test ZZMinSizeRepro). Screen: ScreenshotTests ReviewGalleryScreen.gallery (ReviewGalleryFixtures.withGalleryScreen, InMemoryDemoScript.gallery, permission session "gallery-permission").

- [x] Find the view whose minimum height grew since Oct 29 (bisect AVK if needed)
- [x] The thread with a pending permission request fits a 1180×760 window again
- [x] ScreenshotTests gallery generates every key screen, including "Gallery columns"