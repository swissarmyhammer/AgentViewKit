---
assignees:
- claude-code
position_column: todo
position_ordinal: a480
title: Bar banners (failure, sign-in) draw over transcript text in the bottom-bar-buttons snapshots
---
Reported by testudoapp-2c on 2026-10-24 (the user found it). The snapshots `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/bottom-bar-buttons-{light,dark,increase-contrast,reduce-transparency}.png` come from test `HostedSnapshotTests`, `verify(thread, named: "bottom-bar-buttons", …)`. They were last recorded in f5374f0 (^p6e0v5w).
- The failure banner ("The response stopped because of a failure in the agent. Send the request again." plus "Show Error") is drawn on top of transcript rows, so the text under it is garbled. Vision OCR reads "row thatharespomaeaddess" and "rowthaiasntethsipafess".
- The "Sign in with the agent / Sign In" banner overlaps "Assistant" (OCR: "Assistagtnt").
- OCR over the other 66 AVK hosted and glass snapshots, and the 4 KanbanViewKit snapshots, found no error text and no overlap.

This card also covers the duplicate card 01M5QK2PMN8Q8NWTDTAEVF0ETC, which a Testudo agent hand-wrote (the user reported the same thing from TestudoApp ^5wq4zfq). That card is deleted, and its useful items are below.

First, decide and record whether this is a real bar layout bug or only the test fixture's layout. Possible causes: a bar with no glass over the scrolled transcript, a fixture too small for the bottom bar, or a layout defect in the bottom bar. If it is a kit layout defect, fix the kit, not the fixture. plan.md "Scroll under the bars" says content scrolls under the floating glass bars. But at rest, with no scroll, the bar and its banners must inset the content (a safe-area or content-margin inset sized to the bar plus its banners), so no row's text sits under a bar. If the real bar has the overlap, Testudo shows it too.

- [ ] Find out whether the overlap is in the real bar layout or only in the fixture, and record which.
- [ ] Fix the cause. At rest, a banner in the top or bottom bar never covers transcript text: the bar's inset grows with its banners, and content scrolls under it only when the content is scrolled.
- [ ] Add a hosted test that fails today and passes after the fix: with a failure banner and a sign-in banner shown, the frame of the last row's text does not intersect the frame of the bar.
- [ ] The fixture shows the bottom-bar buttons (Scroll to Bottom, the stop-reason notice, the sign-in banner) with every line of text readable, in each `SnapshotVariant`.
- [ ] Re-record the four bottom-bar-buttons snapshots (light, dark, increase-contrast, reduce-transparency), look at each one, and list them.
- [ ] Check every image under `__Snapshots__` against the current rendering, so no image is out of date.
- [ ] Add a check that fails when a recorded snapshot holds overlapping text (for example, OCR of each recorded image finds each expected string of the fixture), or record why no such check is possible.
- [ ] Check the top-bar banner placement the same way.
- [ ] Full `swift test` green.

When done, send testudoapp-2c the SHA after the user pushes. #avk-8 #cross-repo