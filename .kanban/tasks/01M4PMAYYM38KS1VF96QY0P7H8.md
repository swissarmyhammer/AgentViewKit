---
assignees:
- claude-code
position_column: todo
position_ordinal: '8980'
title: 'Message views: decide on the host date parameter of UserMessageView and MessageHeader'
---
## What
Found during ^mttp3zg. The owner decided (2026-10-11) that the time of an entry is a decorator (`EntryTimingView`, `.transcriptTiming()`, `.entryTiming(_:)`), and that the message views do not show times by themselves.

The kit still has a host `date:` parameter that makes a message view show a relative time in its header:
- `UserMessageView(entry:date:)` (`Sources/AgentViewKit/Items/UserMessageView.swift`)
- `TranscriptMessageView(entry:date:)` and `MessageLayout.date` (`Sources/AgentViewKit/Items/MessageItemView.swift`, `Items/TranscriptMessageView.swift`)
- `MessageHeader(role:date:)` and `MessageHeader.relativeText(for:now:)` (`Sources/AgentViewKit/Items/MessageHeader.swift`)

`ItemRow` always gives `nil`, so the default rows show no date. A host that gives a date gets a second time display, beside the decorator.

## Work
- [ ] Ask the owner: remove the `date:` parameters (the decorator is the one way to show a time), or keep them.
- [ ] Do what the owner decides, with tests (`MessageViewsHostedTests` covers `MessageHeader` with a date).