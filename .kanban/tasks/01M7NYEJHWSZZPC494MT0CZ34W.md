---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: DemoAgent default profile "tiny" is missing in the new FoundationModelsACPAgent
---
A fresh package resolve gets FoundationModelsACPAgent main 7f2524e (the new `ProfileStore`). Then 12 tests fail in DemoAgentTests and RecordedSessionsAgentTests with `no profile is named "tiny"; the profiles are: large, small`. `DemoAgent.defaultProfileName` is "tiny".

The main checkout still passes, because its untracked Package.resolved pins an older FoundationModelsACPAgent. The failure comes back at the next `swift package update`.

Do: find the profile rule of the new ProfileStore. Change `DemoAgent.defaultProfileName` (or the profile setup of the tests) so that the demo agent uses a profile that exists. Then run `swift package update FoundationModelsACPAgent` and `swift test`.