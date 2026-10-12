---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4prspm069xktqc5bc7bp4yk
  text: |-
    ### Fix is in the ^02jyret commit
    - The test `theBodyShowsTheRawInputTheTextPartAndTheRawOutputOfTheEntry` now waits for each part before it checks the part: the raw input, the text part and the raw output.
    - No wait limit changed. `waitTimeout` stays at 5 seconds.
    - The file is Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift. Two new helpers, `waitForElements` and `waitForTexts`, wait for all listed items.
    - Tests changed in the same file, because they had the same pattern (one wait, then more checks):
      - theBodyShowsTheRawInputTheTextPartAndTheRawOutputOfTheEntry
      - aNamedCallShowsTheViewRegisteredForItsNameWithTheTitleAsItsLabel
      - aCallWithNoNameShowsTheDefaultBody
      - aStructuredDiffShowsTheDiffViewAndNotTheUnknownView
      - aLinkedElicitationShowsInTheRowOfItsToolCallOnly
      - aLinkedElicitationAcceptSendsTheFormValuesAsTheACPContent
    - Tests not changed: theLabelChangesWithTheStatusOfTheEntry, aLaterUpdateAddsALocationChip and aLaterRawOutputUpdateChangesTheShownOutput. Each one already waits for the exact thing it checks.
    - Result: the full suite has 1102 tests passed, 1 known issue (expected). Load average was about 45 before and after.
  timestamp: 2026-10-12T00:39:28.128498+00:00
position_column: todo
position_ordinal: '8880'
title: Make theBodyShowsTheRawInputTheTextPartAndTheRawOutputOfTheEntry wait for every part it checks
---
## What
Found during ^5fpgrjg (2026-10-11): `ToolCallEntryViewHostedTests.theBodyShowsTheRawInputTheTextPartAndTheRawOutputOfTheEntry` failed one time in a filtered run at load average 178, and passed in later runs. The test waits only for the output text, not for the text part, so the check of the text part can run before the text part shows.

## Work
- [ ] Make the test wait for each part that it checks (raw input, text part, raw output) before it asserts. Do not raise a wait limit.
- [ ] Look for the same pattern (wait for one element, then assert on others) in the other hosted tests of the same file.