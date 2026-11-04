---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: 'All AVK inspection through EditorKit''s EditorInspector: AttachmentInspector, config and tool forms, ACPClient conformances'
---
Rescoped 2026-11-04 by the user's call (relayed by editorkit-b5): the core inspector and `Inspectable` live in EditorKit, so every kit gets them, and **all inspection in AVK goes through EditorInspector**.

EK card ^tgdjf5g (01M6KG4FZSP41EZ8CDBTGDJF5G, card on EK origin at ec3869b2) builds a new EK product, `EditorInspector`: `Inspectable` (`AnyObject, Observable`), `Inspection`, `FieldGroup`/`Field` with the builders, the modifiers, `.adding`/`.removing`/`.replacing`, `InspectorView(selection)` / `InspectorView(selection, inspection)` (the content of an inspector column or panel; a panel can hold several; it replaces `InspectorForm(inspecting:)`), and `.inspect(_:)` as the convenience for the system column. Editable rows use EK editors (String → SingleLineField, `.multiline()` → EditorView at intrinsic sizing, [String] → TagField). EK starts by lifting AVK's `InspectorForm`, `InspectorActionRow` and `inspectorPreviewFrame()` from `Sources/AgentViewKitStyle/Inspector/`.

**Blocked:** this waits for the EK commit SHA that lands EditorInspector on origin. editorkit-b5 sends it. Don't start before then.

## Panel hosting
Testudo's dockable panel shows several objects at once. Every AVK inspector has to work as content in a panel where the **host owns scrolling** (no ScrollView or Form scrolling of its own) and at **narrow widths, about 240 pt**. EK's `InspectorView` handles both. Build each one on it, not around it.

## What
1. Once the EK SHA is on origin, update all dependencies together (`swift package update`). Drop AVK's copies of `InspectorForm`, `InspectorActionRow` and `inspectorPreviewFrame()`, or re-export EK's for a transition. Update the docc page (Sources/AgentViewKitStyle/AgentViewKitStyle.docc/AgentViewKitStyle.md).
2. Move every inspector-style form in AVK onto `InspectorView`. Survey at rescope time:
   - `AttachmentInspector` (Sources/AgentViewKit/Attachments/AttachmentInspector.swift: `.inspector(isPresented:)` and `InspectorForm(name:)` with `.inspectorPreviewFrame()`), `AttachmentActions` (`InspectorActionRow`), `AttachmentInspectorMode`, and the users in AttachmentView, ImageView and AgentThreadView.
   - `ConfigOptionsView` `.form` style (Sources/AgentViewKit/Config/ConfigOptionsView.swift:233, a grouped Form over `SessionModel.configOptions`). Decide whether it becomes a `FieldGroup` in SessionModel's inspection.
   - `ToolToggles` `.list` style (Sources/AgentViewKit/Input/ToolToggles.swift:107, a grouped Form of toggles).
   - Not inspectors, so left as they are: the Elicitation `#Preview` Forms (a request form, previews only) and the demo's `GalleryLookControls` (app chrome). Re-check this list with a grep for `Form {`, `.inspector(` and `LabeledContent` when the card starts.
3. Conform the FoundationModelsACPClient models (SessionModel, ToolCallEntry, TerminalEntry, …) as `extension X: @retroactive Inspectable` in AVK.

## Acceptance Criteria
- [ ] AVK builds against the EK EditorInspector SHA. No AVK copy of InspectorForm/InspectorActionRow/inspectorPreviewFrame is left, apart from a re-export if one is kept.
- [ ] AttachmentInspector is built on EK's `InspectorView` and looks the same.
- [ ] No inspector-style Form is left in AVK outside EditorInspector (config options and tool toggles included, or a written reason on this card why one stays).
- [ ] Each inspector works as panel content: host-owned scrolling, about 240 pt wide, several in one panel.
- [ ] SessionModel, ToolCallEntry, TerminalEntry and the other ACPClient view models conform as `@retroactive Inspectable` in AVK.
- [ ] Gallery screenshots of each inspector, light and dark, including the narrow panel width.

## Tests
- [ ] Hosted tests: each ACPClient conformance shows its fields and updates live when the model changes.
- [ ] Hosted tests: config options and tool toggles still commit their changes through the new rows.
- [ ] Existing attachment, config and tool toggle tests pass. Any change to their checks is written on the card.

The SHA does not need relaying to KVK/SVK/Testudo; editorkit-b5 sends it to them.