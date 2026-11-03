---
assignees:
- claude-code
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