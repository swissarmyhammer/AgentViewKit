---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: Thread with a pending permission request needs 787.5 pt of height
---
The "Gallery columns" key screen of the ScreenshotTests review gallery has no image: EK's capture refuses to clip it — "the window clips the screen: its content needs 1180.0×787.5 points, the window gives 1180.0×760.0".

EditorKit (editorkit-b5) reproduced it headless: it is AVK's thread view on its own — a thread + a pending permission request + the composer — whose minimum height is 787.5 pt at 1180 wide. Same on every EK from 7697fab0 through ba6b57d5, with any toolbar item or none (the gallery window is borderless, so no system toolbar is built). The last capture of that screen was Oct 29, so AVK's minimum height grew since then. The thread screens are 860 tall, so they fit.

A thread must not force a window to be that tall: the transcript scrolls, so the minimum height of the thread should be small. Find which part of the bars (the request deck in the bar, the permission request, the composer, the header) stopped compressing since Oct 29 and make the thread's minimum height small again. Do not enlarge the gallery window to hide it, and keep "multiline fields size to content; the inspector/thread scrolls, never a small fixed box" — if the deck itself is what is tall, it is the bar that must stay bounded, decide with the user if that conflicts.

Repro from EK: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-EditorKit/4c16fd9c-af46-4c5b-967c-20d45d45288d/scratchpad/avkrepro (test ZZMinSizeRepro). Screen: ScreenshotTests ReviewGalleryScreen.gallery (ReviewGalleryFixtures.withGalleryScreen, InMemoryDemoScript.gallery, permission session "gallery-permission").

- [ ] Find the view whose minimum height grew since Oct 29 (bisect AVK if needed)
- [ ] The thread with a pending permission request fits a 1180×760 window again
- [ ] ScreenshotTests gallery generates every key screen, including "Gallery columns"