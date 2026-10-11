---
assignees:
- claude-code
position_column: todo
position_ordinal: '8880'
title: Make theBodyShowsTheRawInputTheTextPartAndTheRawOutputOfTheEntry wait for every part it checks
---
## What
Found during ^5fpgrjg (2026-10-11): `ToolCallEntryViewHostedTests.theBodyShowsTheRawInputTheTextPartAndTheRawOutputOfTheEntry` failed one time in a filtered run at load average 178, and passed in later runs. The test waits only for the output text, not for the text part, so the check of the text part can run before the text part shows.

## Work
- [ ] Make the test wait for each part that it checks (raw input, text part, raw output) before it asserts. Do not raise a wait limit.
- [ ] Look for the same pattern (wait for one element, then assert on others) in the other hosted tests of the same file.