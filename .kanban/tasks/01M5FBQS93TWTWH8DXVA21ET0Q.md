---
assignees:
- claude-code
position_column: todo
position_ordinal: b680
title: Check the test comments that came from the old ImageRenderer cgImage defect
---
Source: ^v82ggv6. That card found that `ImageRenderer.cgImage` gives the pixels of an earlier render of the process when the content draws nothing. The fix puts each render in front of an empty `Canvas`, so each render starts from a clear image.

Problem: other test comments and test designs were made with the old render path. The same defect can be part of their reasons:
- "ImageRenderer does not draw a ScrollView" (ConversationEmptyStateColorHostedTests reads the window cache for this reason).
- "ImageRenderer does not draw a focusable view" (PermissionView and composer tests read the window cache for this reason).
- "ImageRenderer draws the edge of a rounded glass differently after its first renders in a process" (^ffhv52w, ^r4xbbre: the glass tests compare only the inside of the glass).

Do:
- For each claim, run a small probe with the fixed `RenderedPixels` and record the result on this card.
- If a claim is false now, simplify the test (for example, compare the whole glass again, or use `RenderedPixels` in place of the window cache), but keep each test deterministic.
- If a claim is still true, correct its comment so that it gives the real reason.

Acceptance:
- Each claim has a result on this card.
- 3 full `swift test` runs one after the other pass.
- No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8