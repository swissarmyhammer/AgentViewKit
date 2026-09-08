---
depends_on:
- 01M21A9KJGPPJE0X01JE0B9V33
- 01M21ABMYXZQRNRDGB3DR6RK73
- 01M21BCRF2JZ6W49NKXHE8KKT1
- 01M21CAWYA16NQ5MKZKBBH4DS6
position_column: todo
position_ordinal: 8f80
title: 'PromptInputView: slots, PromptEditorContext, stock editor, submit and stop (plan §7, §9 D)'
---
## What
Create `Sources/AgentViewKit/Input/PromptInputView.swift`, `PromptEditorContext.swift`, `StockPromptEditor.swift`, and `DefaultPromptAccessory.swift`, per plan.md §7 and §9 D. The EditorKit editor, the attachment chips, and the suggestions, mic, and tool toggles come in their own tasks.

- `PromptInputView<Editor, Accessory>` with the constrained-extension overloads from §7. Default `Editor == StockPromptEditor` (a `TextEditor`), `Accessory == DefaultPromptAccessory`.
- `PromptEditorContext`: `text: Binding<AttributedString>`, `placeholder`, `onSubmit`, `commands: [SlashCommand]`.
- `StockPromptEditor(context:)`: Return calls `onSubmit`; Shift-Return inserts a newline.
- `DefaultPromptAccessory`: the submit button in `.glassProminent`. It becomes Stop while `thread.state == .running` and calls `cancel`. Slots for the later chips, suggestions, mic, and tool toggles are empty views here.
- On submit the view calls `AgentThreadActions.send(UserInput(text:attachments:))` and clears the text.
- Accessibility identifiers: `prompt-editor`, `prompt-submit`, `prompt-stop`.

## Acceptance Criteria
- [ ] `PromptInputView(text:onSubmit:)` compiles with no closures and mounts `prompt-editor`.
- [ ] Return calls `send` with the text and clears the editor; Shift-Return does not, and the text gains a newline.
- [ ] While running, `prompt-stop` is present, `prompt-submit` is absent, and a press calls `cancel`.

## Tests
- [ ] `Tests/AgentViewKitTests/Input/PromptInputViewHostedTests.swift`: mount, keys, submit and stop through `NoopThreadActions`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.