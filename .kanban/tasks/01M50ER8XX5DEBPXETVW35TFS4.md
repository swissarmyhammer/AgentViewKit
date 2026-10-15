---
assignees:
- claude-code
depends_on:
- 01M50ER0NN5DRGV5S3HGQ8H07P
position_column: todo
position_ordinal: 8a80
title: 'Mail step 7 T4-A2: Remove the clock waits and polls from the Items tests'
---
Part of T4 (^m7q9e97). Area: Tests/AgentViewKitTests/Items (about 85 sites). Same rules as T4-A1: direct render pass, event wait on a certain event where needed, gate or fixed order; no time bound; no read-back of a value that the test wrote; delete no test; report a wait with no event and no direct render before you change it. One full run, one commit. Write all text in STE. #mail-step-7