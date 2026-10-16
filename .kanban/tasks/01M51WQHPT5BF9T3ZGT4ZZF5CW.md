---
assignees:
- claude-code
position_column: todo
position_ordinal: '9e80'
title: Remove the padding bytes of ToolCallBody (and AgentTheme) so that the byte compare of SwiftUI finds no change
---
Found in ^mjkwsp4. While the compare layout of a view type is not ready, SwiftUI compares the bytes of the old and the new view value (see ^fzn2beh). The bytes include the padding bytes of the type.

`ToolCallBody` (Sources/AgentViewKit/Items/ToolCallView.swift) does not get new storage on each update: its fields are the entry object, the renderer closure of the same registration, the registration UUID, and the theme (trivial values). But the type has padding: `registrationID: UUID?` is 17 bytes with alignment 1, and the next field `theme: AgentTheme` has alignment 8, so 7 padding bytes follow it. `AgentTheme` also has 7 internal padding bytes after `materialLevel` (1 byte) before `symbolWeight: Font.Weight` (alignment 8).

Probe (session scratchpad, probe/main.swift, `swiftc -Onone`): a struct with the same field types and the same init gives size 121. Two values made from the same inputs are `==` but have different bytes at offsets 41, 42, 43, 44 (the padding after the UUID?). A ParagraphViewCache-type cache does not correct this reliably, because a field-wise copy does not keep padding bytes.

- [ ] Confirm the real layout with `MemoryLayout<ToolCallBody>.size` and `MemoryLayout<AgentTheme>.size` (ToolCallBody is `private` now).
- [ ] Write a deterministic RED test first (for example: the size of the type is equal to the sum of the sizes of its fields, so the type has no padding).
- [ ] Remove the padding: put the fields in an order with no gaps (for example `registrationID` last in ToolCallBody, and `materialLevel` and `density` after `symbolWeight` in AgentTheme). Keep the public API of AgentTheme.
- [ ] Check ParagraphView and ItemRow for padding too (ItemRow is one 8-byte enum of object references, no padding).
Write all text in STE. #mail-step-7