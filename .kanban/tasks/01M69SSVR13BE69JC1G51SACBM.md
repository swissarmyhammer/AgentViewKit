---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: 'CI Integration red on macOS 27.2: ThreadBarInsetHostedTests reads the floating controls 39 points short'
---
Runs 41235913570 and 41242786511 on m3u1: 5 tests in ThreadBarInsetHostedTests fail at line 166 with bottom inset 239.92, bar below 201.5.

Not reproduced here. This Mac passes the suite with Xcode 27.2 (27B52), latest dependencies and the full IntegrationTests run: bar below 240.5 on Xcode 27.1, no failure on 27.2. The Xcode suspicion is ruled out.

The difference left is the OS. m3u1 went from macOS 27.0.1 (26A434, last pass 0874d19) to macOS 27.2 (26B123), and this Mac is on 27.0.1 (26A434). Accessibility frames come from the OS at runtime, so this is the leading cause, not proven.

The inset is 239.92 on both, so the layout looks right and the short value is the accessibility frame of `AgentThreadLayout.floatingControlsIdentifier`. Its contents are the state banner, the login prompt and the composer in a `FloatingGlassContainer`, with `.padding(barEdgeInset)`.

- [ ] Get a macOS 27.2 machine to run this on: update this Mac, or run on m3u1 (user).
- [ ] Find which part of the floating controls the frame misses.
- [ ] Fix the measurement, or the view if the element is really wrong. Do not widen `insetTolerance`.
- [ ] Integration passes on CI.