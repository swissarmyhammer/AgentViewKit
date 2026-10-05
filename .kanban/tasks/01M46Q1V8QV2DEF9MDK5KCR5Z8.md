---
assignees:
- claude-code
position_column: todo
position_ordinal: a880
title: Make ConversationViewHostedTests.anInsertWhileUnpinnedShowsOneNewInThePill stable in the full suite run
---
## What
`ConversationViewHostedTests.anInsertWhileUnpinnedShowsOneNewInThePill()` failed one time in a full `swift test` run on 2026-10-05 (found during task ^xbr8qmh). The run before it and the change of ^xbr8qmh did not touch this test.

The failures, all in one run:
- `!anchors.isPinnedToBottom` was false: the anchor manager was pinned to the bottom.
- `harness.element(identifier: ScrollToBottomPill.identifier)?.label == "1 new"` was false: the pill did not exist.
- `anchors.newItemsSinceUnpinned == 1` was false: the value was 0.
- `anchors.visibleIDs.last != Self.insertedID` was false: the inserted message was visible.

Probable cause: the test scrolls up to unpin the view, but the view was pinned again (or never unpinned) before the insert. Thus the insert scrolled the view to the bottom. Find the real cause before a change.

- [ ] Show the failure in a way you can repeat (run the test many times with `--filter`, `--maximum-repetitions` and parallel processes).
- [ ] Make the test wait for a real condition (for example, the unpinned state) before the insert. Do not add sleeps.

## Acceptance Criteria
- [ ] The repeated run of the test passes.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd`.