---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: 'CI Integration red on Xcode 27.2: ThreadBarInsetHostedTests reads the floating controls 39 points short'
---
Run 41235913570 (2eb7e92) on m3u1: 5 tests in ThreadBarInsetHostedTests fail at line 166 with bottom inset 239.92, bar below 201.5. On this Mac (Xcode 27.1, same EditorKit 02607e0) the same tests give inset 239.92, bar below 240.5, and pass.

So the inset is the same on both, and the difference is the accessibility frame of `AgentThreadLayout.floatingControlsIdentifier`.

m3u1 moved from /Applications/Xcode_27.1.app (SDK 27.0, last pass 0874d19) to /Applications/Xcode.app 27.2 (build 27B52, SDK 27.2). That is the leading suspect, not a proven cause: the newer dependencies on CI differ too, and they can't build here because FoundationModelsRouter needs `Transcript.Entry.data`, which the 27.1 SDK lacks.

- [ ] Install Xcode 27.2 on this Mac (user), so the failure can be reproduced and latest dependencies build.
- [ ] Reproduce, and find which part of the floating controls the frame misses.
- [ ] Fix the measurement, or the view if the element is really wrong. Do not widen `insetTolerance`.
- [ ] Integration passes on CI.