---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m46pcg3pgej6zc8hsj89qprh
  text: 'Research. InMemoryDemoAgent.turnFrames sends the frames of a turn after the prompt result, in this order: state_update running, agent_message_chunk (two chunks), agent_message (full text), plan_update, usage_update, state_update idle end_turn. ACPThreadSource makes the reply record at the first chunk, so the record can exist with part of the text or with no blocks. eachTurnGivesANewReply waits only until the record exists, so the assertion on the blocks can read the record before the last chunk. aSendOfHelloGivesTheReplyOfTheAgent already waits for the turn end (state idle(endTurn) and the record exists). Because the running state comes before the first chunk, "record exists and state is idle(endTurn)" is true only after the end of that turn, also for turn 2. The other tests of the file do not read the content of a streamed record.'
  timestamp: 2026-10-05T18:49:27.414583+00:00
- actor: claude-code
  id: 01m46q5mxt4z9e5v7q6wbg9pht
  text: |-
    Implementation landed. Only the test file changed.

    RED: 8 parallel processes, each `swift test --skip-build --filter "ACPDemoSessionTests/eachTurnGivesANewReply" --maximum-repetitions 200 --repeat-until fail`. 1 failure in 1600 runs, at the blocks assertion, with `second.blocks → []`. The reply record existed, but its text was still streaming.

    Change: a new private suite member `waitForTheEndOfTurn(_:in:)`. It waits until the reply record of the turn exists and the thread state is `.idle(.endTurn)`. eachTurnGivesANewReply now waits for the end of turn 1 and the end of turn 2. aSendOfHelloGivesTheReplyOfTheAgent used the same condition inline, so it now calls the helper. Its assertion `thread.streaming[replyID] == nil` stays as a separate check. No sleep was added.

    Other tests of the file: no other test reads the content of a streamed record, so no other test has this race.

    GREEN: the same 8 x 200 run after the change gave 1600 passes and 0 issues.

    Full `swift test`, three runs:
    - Run 1: pass (1279 tests in 110 suites, 77 in 12, 1 in 1).
    - Run 2: 4 issues, all in `ConversationViewHostedTests.anInsertWhileUnpinnedShowsOneNewInThePill` (the view stayed pinned to the bottom). This hosted view test has no relation to this change. I recorded it as the new task ^5kcr5z8.
    - Run 3: pass.

    Each build writes the SwiftPM warning `missing creator for mutated node` for the mlx-swift_Cmlx bundle. The warning was also in the build before this change.
  timestamp: 2026-10-05T19:03:11.546121+00:00
- actor: claude-code
  id: 01m46q5pwffb0dpypza4fdb3m1
  text: |-
    ### implement — changed
    - evidence: 1 file — Tests/AgentViewKitTests/ACP/ACPDemoSessionTests.swift. RED 1 failure in 1600 filtered repetitions (8 x 200); GREEN 0 failures in 1600. Full `swift test`: runs 1 and 3 pass; run 2 failed only in ConversationViewHostedTests.anInsertWhileUnpinnedShowsOneNewInThePill, which has no relation to this change and is now task ^5kcr5z8.
    - next: /review
  timestamp: 2026-10-05T19:03:13.551235+00:00
- actor: claude-code
  id: 01m46qd9xp2jygfqz942167n8r
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — ACPDemoSessionTests waits for the end of each turn (waitForTheEndOfTurn); race repeated 1 of 1600, then 0 of 1600
    - test: green — swift test, 1279 passed
    - commit: a403b17
    - review: clean — 0 findings
  timestamp: 2026-10-05T19:07:22.422256+00:00
- actor: claude-code
  id: 01m46qdbcrv3nfr10yvgad6nsg
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (a403b17). 1 file reviewed, 6 .kanban files not reviewed because of .reviewignore. 0 findings, 0 confirmed, 0 refuted. The task has no earlier review findings.
    - next: none. The task moved to done.
  timestamp: 2026-10-05T19:07:23.928209+00:00
position_column: done
position_ordinal: e480
title: Make ACPDemoSessionTests.eachTurnGivesANewReply stable in the full suite run
---
## What
`ACPDemoSessionTests.eachTurnGivesANewReply()` failed one time in a full `swift test` run on 2026-10-05 (task ^qmb021n). The suite passed when it ran alone.

The failure: `second.blocks == [ContentBlock(text: InMemoryDemoAgent.replyText(to: "two"))]` was false.

Probable cause: the test waits until the assistant message of turn 2 exists. It does not wait until all of the text of that message has arrived. Under load, the assertion reads the message before the last chunk.

- [x] Wait until the blocks of the turn 2 message are equal to the full reply text, not only until the message exists.
- [x] Look for the same pattern in the other tests of `Tests/AgentViewKitTests/ACP/ACPDemoSessionTests.swift`.

## Acceptance Criteria
- [x] The test waits for the full reply text.
- [x] `swift test` passes.

## Workflow
- Use `/tdd`.