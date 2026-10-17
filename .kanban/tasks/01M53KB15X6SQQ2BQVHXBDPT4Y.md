---
assignees:
- claude-code
position_column: todo
position_ordinal: a080
title: 'ConversationView and AgentCommandTarget: two copies of the position lookup of a row key'
---
Found during ^bh5vs6r. `ConversationView.position(of:)` and `AgentCommandTarget` (the jump to a prompt) both find the position of a transcript entry by its row key with `transcript.firstIndex { $0.rowKey == key }`.

- Fix: one shared lookup of the position of a row key in a transcript (for example an extension on `[TranscriptEntry]` beside `entry(withID:)` in Sources/AgentViewKit/Thread/TranscriptEntryLookup.swift), used by both; delete the copies. No behavior change. A test for the lookup.

Write all text in STE. #refactor