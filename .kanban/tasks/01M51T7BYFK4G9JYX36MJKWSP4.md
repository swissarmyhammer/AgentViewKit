---
assignees:
- claude-code
position_column: todo
position_ordinal: 9b80
title: Check the other .equatable() views for the AttributeGraph byte-compare gap (ConversationView row, ToolCallView)
---
Found in ^fzn2beh. SwiftUI computes the compare layout of a view type on a background queue. Until that layout is ready, SwiftUI compares the bytes of the old and the new view value and does not call `==`. A view value that the parent makes again on each update (new String or Array storage) then evaluates its body again, although `==` gives `true`. Early in a process and in a busy full run, this can last for a whole test (evidence on ^fzn2beh: probe logs zn2beh-probe5/6/8 in the session scratchpad; with `AG_ASYNC_LAYOUTS=0` the gap does not occur).

ResponseView now gives a settled paragraph its stored value again (`ParagraphViewCache`). Two other places use `.equatable()` for the same reuse guarantee:
- [ ] Sources/AgentViewKit/Thread/ConversationView.swift (the transcript row with `.equatable()`; the test `aChunkEvaluatesOnlyTheRowOfItsEntry` counts it).
- [ ] Sources/AgentViewKit/Items/ToolCallView.swift (`.equatable()`).
- [ ] For each: read if the parent makes new storage for an unchanged value on each update. If yes, keep the stored value (as `ParagraphViewCache` does), and add a unit test that compares the bytes. Do not change a test to hide the gap.
Write all text in STE. #mail-step-7