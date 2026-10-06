---
assignees:
- claude-code
position_column: todo
position_ordinal: b980
title: Make SessionEntryRowsHostedTests.anAppendedErrorShowsItsData stable
---
## What

The test `SessionEntryRowsHostedTests.anAppendedErrorShowsItsData` fails some times. It failed in two filtered runs with other suites. It passed in the full runs. It passed in one filtered run with 20 repetitions (`swift test --filter 'SessionEntryRowsHostedTests|MessageViewsHostedTests|WireContentBlockViewHostedTests' --maximum-repetitions 20`). The cause is not known.

The test calls `appendError` on the session model. Then it waits up to 5 seconds for the element with the identifier `ErrorView.dataIdentifier`. The wait limit must stay at 5 seconds. Do not use sleeps.

Find the cause. Read the order of events between `appendError`, the row in the list, and the lookup of the element. Check if the row is not made in the list, or if the identifier is lost when the row merges the element. Fix the cause in the view or in the harness. Views must bind directly to the FoundationModelsACPClient models. Add no kit-side state, copy, or turn logic.

## Acceptance Criteria

- [ ] The cause of the failure is found and written on this task.
- [ ] The test passes in every run, with the wait limit at 5 seconds.
- [ ] The fix has no sleeps and no raised limits.

## Tests

- [ ] Write a failing test that shows the cause, if the cause can be shown in a test.
- [ ] Run `swift test --filter SessionEntryRowsHostedTests` one time after the fix.
- [ ] Run the full suite one time at the end. It must have zero failures and zero warnings.

## Workflow

- Use `/tdd` — write failing tests first, then implement to make them pass.