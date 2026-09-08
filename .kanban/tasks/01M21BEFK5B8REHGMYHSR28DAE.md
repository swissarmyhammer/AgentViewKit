---
depends_on:
- 01M21AF2MV082PZY3Q6H0M4YCM
- 01M21ACHJYSF8G8R7HY3M70Z7F
position_column: todo
position_ordinal: b680
title: EditorKitPromptEditor with SlashCommandSource and @file path completion (plan §4.1, §9 D)
---
## What
Create `Sources/AgentViewKit/Input/EditorKitPromptEditor.swift` and `SlashCommandSource.swift`, per plan.md §4.1 and §9 D.

- `EditorKitPromptEditor(context: PromptEditorContext)`: hosts an EditorKit `EditorView` with `.editorSizingMode(.intrinsic)`, the `AgentTheme` bridge, and a `CompletionEngine` with two sources. Return calls `context.onSubmit`; Shift-Return inserts a newline.
- `SlashCommandSource: CompletionSource`: triggers on `/` at the start of a line, lists `context.commands` filtered by prefix, and inserts the command name plus a space on accept. Shows the `inputHint` as the detail text.
- `@file`: EditorKit's `PathCompletionSource` rooted at a directory the host passes through `.promptFileRoot(_:)`. An accepted path becomes a `SmartTag` chip in the editor and a `resourceLink` block on submit.
- Register the editor as the `editor:` slot value `EditorKitPromptEditor.init` so a host writes `PromptInputView(text:onSubmit:, editor: EditorKitPromptEditor.init)`.

## Acceptance Criteria
- [ ] Typing `/` lists the context commands; typing `/co` filters to those with the prefix; accept inserts the name.
- [ ] Typing `@` lists entries under the file root; accept inserts a chip.
- [ ] Return calls `onSubmit`; Shift-Return does not, and the text gains a newline.

## Tests
- [ ] `Tests/AgentViewKitTests/Input/SlashCommandSourceTests.swift`: trigger, filter, insert.
- [ ] `Tests/AgentViewKitTests/Input/EditorKitPromptEditorHostedTests.swift`: keys through the harness with a temp directory as the file root.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.