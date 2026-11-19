---
assignees:
- claude-code
position_column: todo
position_ordinal: '8280'
title: 'Side card: Close stays available while the fork needs input'
---
Request from testudoapp-9a (2026-11-18), after task 01M7QV7CE6YS0MPFZY7XF6J8GK (8eab72b1, 497a1d5a, 968473ff).

Now: while the fork of a `SideQuestionCard` needs input (a pending permission request or an elicitation), the card shows "Needs input" and the Open button only. The Close verb is unavailable, with the reason "The side question needs input. Open it to answer."

The user must always be able to dismiss a side question. The app handles Close: it stops the turn of the fork and archives the fork (D204, so undo brings it back).

Do:
- While the fork needs input, Close stays available with no reason, and the card shows the Close button. Open also stays available. Send to Chat stays hidden in that state.
- Escape on a focused card runs Close also in that state.
- Remove the string "The side question needs input. Open it to answer." from the catalog if nothing uses it.
- Update the unit tests and the snapshot test of the needs-input card (compile only, do not run ScreenshotTests).

Run `swift test`. Push, and send the sha to testudoapp-9a.