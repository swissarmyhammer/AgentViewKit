---
assignees:
- claude-code
depends_on:
- 01M50ER0NN5DRGV5S3HGQ8H07P
position_column: todo
position_ordinal: 8b80
title: 'Mail step 7 T4-A3: Remove the clock waits and polls from the Thread and Accessibility tests'
---
Part of T4 (^m7q9e97). Area: Tests/AgentViewKitTests/Thread and Tests/AgentViewKitTests/Accessibility (about 95 sites, including the waits that ^fn4p8gy left in ConversationViewHostedTests, ThreadMinimapViewHostedTests and AgentCommandScopeHostedTests helpers). Same rules as T4-A1. Tests that need the SwiftUI visibility report use the ^809cwz0 treatment. One full run, one commit. Write all text in STE. #mail-step-7