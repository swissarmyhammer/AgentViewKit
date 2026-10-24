---
assignees:
- claude-code
position_column: todo
position_ordinal: a480
title: Bar banners (failure, sign-in) draw over transcript text in the bottom-bar-buttons snapshots
---
Reported by testudoapp-2c on 2026-10-24 (the user found it). Snapshots `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/bottom-bar-buttons-{light,dark,increase-contrast,reduce-transparency}.png` were last recorded in f5374f0 (^p6e0v5w).
- The failure banner ("The response stopped because of a failure in the agent. Send the request again." plus "Show Error") is drawn on top of transcript rows, so the text under it is garbled. OCR reads "row thatharespomaeaddess".
- The "Sign in with the agent" banner overlaps "Assistant" (OCR: "Assistagtnt").
- OCR over all the other AVK hosted and glass snapshots found no other problems.

Decide first, and record the answer: is this a real bar layout bug, or only the test fixture's layout? plan.md "Scroll under the bars" says content scrolls under the floating glass bars. But at rest, with no scroll, the bar and its banners must inset the content (a safe-area or content-margin inset sized to the bar plus its banners) so no row's text sits under a bar. If the real bar has the overlap, Testudo shows it too.

- [ ] Find out whether the overlap is in the real bar layout or only in the fixture; record which.
- [ ] Fix the cause. At rest, a banner in the top or bottom bar never covers transcript text: the bar's inset grows with its banners, and content scrolls under only when it is scrolled.
- [ ] A hosted test fails today and passes after the fix: with a failure banner and a sign-in banner shown, the frame of the last row's text does not intersect the frame of the bar.
- [ ] Re-record the four bottom-bar-buttons snapshots (light, dark, increase-contrast, reduce-transparency) and look at each one. List them.
- [ ] Check the top-bar banner placement the same way.

When done, send testudoapp-2c the SHA after the user pushes. #avk-8 #cross-repo