---
depends_on:
- 01M21AF2MV082PZY3Q6H0M4YCM
- 01M21AM66JDT2YAVFPWSQFHEXD
position_column: todo
position_ordinal: c380
title: 'AttachmentChips in the composer: chip row, remove, file drop, image paste (plan §9 D)'
---
## What
Create `Sources/AgentViewKit/Input/AttachmentChips.swift`, per plan.md §9 D. It builds on `AttachmentChip` from the attachments task.

- `AttachmentChips(attachments: Binding<[Attachment]>)`: a horizontal row of `AttachmentChip` views, each with a remove button that drops the entry.
- `.dropDestination(for: URL.self)` adds one `Attachment(url:)` per dropped file. A dropped image `Data` is written to a temp file and added.
- Paste: `onPasteCommand(of: [.image])` writes the image to a temp file and adds it.
- `PromptInputView` shows the row above the editor when the binding is non-empty and passes the attachments into `UserInput` on submit.
- Accessibility identifier `attachment-chip-<id>` and remove identifier `attachment-remove-<id>`.

## Acceptance Criteria
- [ ] Two attachments render two chips; a press on a remove leaves one.
- [ ] A drop of two file URLs adds two attachments with the resolved types.
- [ ] Submit passes the attachments in `UserInput.attachments`.

## Tests
- [ ] `Tests/AgentViewKitTests/Input/AttachmentChipsHostedTests.swift`: render, remove, drop through a `DropInfo` fake, submit through `NoopThreadActions`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.