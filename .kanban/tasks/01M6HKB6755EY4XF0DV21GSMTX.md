---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6htcypmmrrfkatb14p3361c
  text: |-
    finish — stuck
    - evidence: FoundationModelsACPAgent announces live child runs only. It does not replay child history from a recording.
    - next: Wait for the agent session to say that replay exists. Then add the recording and enable RecordedNestedResumeTests.
  timestamp: 2026-11-03T23:02:39.060764+00:00
- actor: claude-code
  id: 01m6hv2p1vbbr0e12tkva77zmg
  text: 'Agent session answer: planned, not done. The agent card ^wd0cwz7 (cold resume of recorded nested sessions) is in todo with no commit. Keep RecordedNestedResumeTests disabled. The agent session sends the commit and the recording needs when it lands.'
  timestamp: 2026-11-03T23:14:31.099820+00:00
position_column: todo
position_ordinal: '8380'
title: 'Nested recording: resume of a recording with agentSpawn shows the tree'
---
## What
Split from the nested-fixtures card. Add a nested recording to `Examples/AgentViewKitDemo/RecordedSessions` whose Router record has `agentSpawn`, and turn on `RecordedNestedResumeTests` (it is written and disabled). The test resumes each recorded session from the start and checks that the tree has a child that has a child.

This waits for FoundationModelsACPAgent to replay the child history of a recording as child sessions (today it announces live child runs only: commits e0d6d07 and 4d4524d). The agent session tells when it is ready.

## Acceptance Criteria
- [ ] The recording is in the demo app and in the Gallery list.
- [ ] `RecordedNestedResumeTests` is on and passes, with no change to its checks.
- [ ] The tree after the resume has the same children as the recording, and a replay raises no attention mark.

## Tests
- [ ] Run `swift test --filter RecordedNestedResumeTests`. It passes. #subagents