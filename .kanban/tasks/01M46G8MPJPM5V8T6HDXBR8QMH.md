---
assignees:
- claude-code
position_column: todo
position_ordinal: a880
title: Make ACPDemoSessionTests.eachTurnGivesANewReply stable in the full suite run
---
## What
`ACPDemoSessionTests.eachTurnGivesANewReply()` failed one time in a full `swift test` run on 2026-10-05 (task ^qmb021n). The suite passed when it ran alone.

The failure: `second.blocks == [ContentBlock(text: InMemoryDemoAgent.replyText(to: "two"))]` was false.

Probable cause: the test waits until the assistant message of turn 2 exists. It does not wait until all of the text of that message has arrived. Under load, the assertion reads the message before the last chunk.

- [ ] Wait until the blocks of the turn 2 message are equal to the full reply text, not only until the message exists.
- [ ] Look for the same pattern in the other tests of `Tests/AgentViewKitTests/ACP/ACPDemoSessionTests.swift`.

## Acceptance Criteria
- [ ] The test waits for the full reply text.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd`.