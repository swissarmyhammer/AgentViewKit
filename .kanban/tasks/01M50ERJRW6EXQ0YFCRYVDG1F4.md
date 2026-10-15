---
assignees:
- claude-code
depends_on:
- 01M50ER0NN5DRGV5S3HGQ8H07P
position_column: todo
position_ordinal: '8e80'
title: 'Mail step 7 T4-A6: Remove the clock waits and polls from the other test folders'
---
Part of T4 (^m7q9e97). Area: Tests/AgentViewKitTests/Status, Activity, Commands, Sessions, Attachments, Terminal, Config, Helpers, ACP, TestSupport, the files at the root of Tests/AgentViewKitTests, and Tests/PackageStructureTests. Same rules as T4-A1. At the end, no use of `pump(for:)` with a fixed time, `waitUntil` or `pump(until:)` is left in Tests; check with a search. One full run, one commit. Write all text in STE. #mail-step-7