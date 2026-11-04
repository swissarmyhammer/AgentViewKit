---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: 'Adopt EditorKit EditorInspector: drop AVK inspector copies, conform ACPClient models to Inspectable'
---
Rescoped 2026-11-04 by the user's call (relayed by editorkit-b5): the core inspector and `Inspectable` live in EditorKit, not AVK, so every kit gets them.

EK card ^tgdjf5g (01M6KG4FZSP41EZ8CDBTGDJF5G, card on EK origin at ec3869b2) builds a new EK product, `EditorInspector`: `Inspectable`, `Inspection`, `FieldGroup`/`Field` with the builders, the modifiers, `.adding`/`.removing`/`.replacing`, `.inspect(_:)` and `InspectorForm(inspecting:)`. Editable rows use EK editors (String → SingleLineField, `.multiline()` → EditorView at intrinsic sizing, [String] → TagField). EK starts by lifting AVK's `InspectorForm`, `InspectorActionRow` and `inspectorPreviewFrame()` from `Sources/AgentViewKitStyle/Inspector/`.

**Blocked:** this waits for the EK commit SHA that lands EditorInspector on origin. editorkit-b5 sends it. Don't start before then.

## What
1. Once the EK SHA is on origin, update all dependencies together (`swift package update`). Drop AVK's copies of `InspectorForm`, `InspectorActionRow` and `inspectorPreviewFrame()`, or re-export EK's for a transition. Move `AttachmentInspector` (Sources/AgentViewKit/Attachments/) and the other users (ImageView, AttachmentView, AgentThreadView, the docc page) onto EK's.
2. Conform the FoundationModelsACPClient models (SessionModel, ToolCallEntry, TerminalEntry, …) to `Inspectable`, as extensions in AVK.

## Acceptance Criteria
- [ ] AVK builds against the EK EditorInspector SHA. No AVK copy of InspectorForm/InspectorActionRow/inspectorPreviewFrame is left, apart from a re-export if one is kept.
- [ ] AttachmentInspector uses EK's inspector and looks the same.
- [ ] SessionModel, ToolCallEntry, TerminalEntry and the other ACPClient view models conform to `Inspectable` in AVK.
- [ ] Gallery screenshots of the conformed inspectors, light and dark.

## Tests
- [ ] Hosted tests: each ACPClient conformance shows its fields and updates live when the model changes.
- [ ] Existing attachment inspector tests pass unchanged.

The SHA does not need relaying to KVK/SVK/Testudo; editorkit-b5 sends it to them.