---
comments:
- actor: claude-code
  id: 01m2ptfxf695vqptq7djc452m2
  text: |-
    ### finish iteration 1 — findings
    - implement: added AttachmentChips, AttachmentDrop, `.attachmentDropDestination(_:)`, and the `attachments:` binding of PromptInputView. A SwiftUI drop gives no `DropInfo` value, so the drop tests call `AttachmentChips.add(_:to:directory:)` directly.
    - test: `timeout 1500 swift test` passed. PackageFileSupportTests 22, AgentViewKitTests 1044, AgentViewKitRouterTests 71, AgentViewKitFoundationModelsTests 44, AgentViewKitACPTests 93. Only the accepted mlx warning.
    - commit: bebe3d4
    - review: 1 finding (`code-hygiene/dead-code-swift`, `ownAttachments` in PromptInputView.swift:44).
  timestamp: 2026-09-17T04:37:40.966040+00:00
- actor: claude-code
  id: 01m2ptmexsdw0gfvnc8z8xv13s
  text: |-
    ### finish iteration 2 — clean
    - implement: PromptInputView reads the kept attachment list through `Binding(get:set:)` on `ownAttachments`, not through `$ownAttachments`.
    - test: `timeout 1500 swift test` passed. PackageFileSupportTests 22, AgentViewKitTests 1044, AgentViewKitRouterTests 71, AgentViewKitFoundationModelsTests 44, AgentViewKitACPTests 93. Only the accepted mlx warning.
    - commit: 74853a2
    - review: 0 findings. The finding of iteration 1 is checked.
  timestamp: 2026-09-17T04:40:09.913304+00:00
depends_on:
- 01M21AF2MV082PZY3Q6H0M4YCM
- 01M21AM66JDT2YAVFPWSQFHEXD
position_column: done
position_ordinal: ba80
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
- [x] Two attachments render two chips; a press on a remove leaves one.
- [x] A drop of two file URLs adds two attachments with the resolved types.
- [x] Submit passes the attachments in `UserInput.attachments`.

## Tests
- [x] `Tests/AgentViewKitTests/Input/AttachmentChipsHostedTests.swift`: render, remove, drop through a `DropInfo` fake, submit through `NoopThreadActions`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 23:34)

> Scope: `review sha HEAD~1..HEAD` (bebe3d4). 5 files reviewed, 0 not reviewed.

- [x] `Sources/AgentViewKit/Input/PromptInputView.swift:44` `code-hygiene/dead-code-swift` — var.instance `ownAttachments` is unused.

## Review Findings (2026-09-16 23:38)

> Scope: `review sha HEAD~1..HEAD` (74853a2). 1 file reviewed, 0 not reviewed. No findings.