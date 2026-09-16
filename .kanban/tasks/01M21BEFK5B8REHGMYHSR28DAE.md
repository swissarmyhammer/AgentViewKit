---
comments:
- actor: claude-code
  id: 01m2p8zczvykhm85yh8cs1vtdm
  text: |-
    ### finish iteration 1 — findings
    - implement: Added EditorKitPromptEditor, SlashCommandSource, FileReferenceSource, FileReferenceDetector, DirectoryFileSystem, `.promptFileRoot(_:)`. PromptInputView sends each file `link` in the text as an attachment. Added the EditorExtensions product to the manifest.
    - test: swift test green. AgentViewKitTests 933 (was 894), AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 20, AgentViewKitFoundationModelsTests 1. No new warnings.
    - commit: d664b32
    - review: 2 findings (code-hygiene/dead-code-swift: `EngineKey.commands` and `EngineKey.root` are assign-only properties).
    - decision: EditorKit `PathCompletionSource` needs a `/` in the token and reads `@` as part of the directory name. So `FileReferenceSource` does its own scan on the EditorKit `FileSystem` contract.
  timestamp: 2026-09-16T23:31:34.011397+00:00
- actor: claude-code
  id: 01m2p939daba4tf90tbk9ccbw6
  text: |-
    ### finish iteration 2 — done
    - implement: Removed the `EngineKey` struct. The session stores the engine commands and root and compares them directly. This removes the two assign-only properties.
    - test: swift test green. AgentViewKitTests 933, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 20, AgentViewKitFoundationModelsTests 1. No new warnings.
    - commit: 3cafd8c
    - review: 0 findings. All prior items checked. Moved to done.
  timestamp: 2026-09-16T23:33:41.418762+00:00
depends_on:
- 01M21AF2MV082PZY3Q6H0M4YCM
- 01M21ACHJYSF8G8R7HY3M70Z7F
position_column: done
position_ordinal: af80
title: EditorKitPromptEditor with SlashCommandSource and @file path completion (plan §4.1, §9 D)
---
## What
Create `Sources/AgentViewKit/Input/EditorKitPromptEditor.swift` and `SlashCommandSource.swift`, per plan.md §4.1 and §9 D.

- `EditorKitPromptEditor(context: PromptEditorContext)`: hosts an EditorKit `EditorView` with `.editorSizingMode(.intrinsic)`, the `AgentTheme` bridge, and a `CompletionEngine` with two sources. Return calls `context.onSubmit`; Shift-Return inserts a newline.
- `SlashCommandSource: CompletionSource`: triggers on `/` at the start of a line, lists `context.commands` filtered by prefix, and inserts the command name plus a space on accept. Shows the `inputHint` as the detail text.
- `@file`: EditorKit's `PathCompletionSource` rooted at a directory the host passes through `.promptFileRoot(_:)`. An accepted path becomes a `SmartTag` chip in the editor and a `resourceLink` block on submit.
- Register the editor as the `editor:` slot value `EditorKitPromptEditor.init` so a host writes `PromptInputView(text:onSubmit:, editor: EditorKitPromptEditor.init)`.

## Acceptance Criteria
- [x] Typing `/` lists the context commands; typing `/co` filters to those with the prefix; accept inserts the name.
- [x] Typing `@` lists entries under the file root; accept inserts a chip.
- [x] Return calls `onSubmit`; Shift-Return does not, and the text gains a newline.

## Tests
- [x] `Tests/AgentViewKitTests/Input/SlashCommandSourceTests.swift`: trigger, filter, insert.
- [x] `Tests/AgentViewKitTests/Input/EditorKitPromptEditorHostedTests.swift`: keys through the harness with a temp directory as the file root.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 18:27)

> Scope: `review sha HEAD~1..HEAD` (d664b32). 9 files reviewed. `Docs/decisions/dependencies.md` not reviewed: no validator matches this file.

- [x] `Sources/AgentViewKit/Input/EditorKitPromptEditor.swift:425` `code-hygiene/dead-code-swift` — var.instance `commands` is assignOnlyProperty.
- [x] `Sources/AgentViewKit/Input/EditorKitPromptEditor.swift:426` `code-hygiene/dead-code-swift` — var.instance `root` is assignOnlyProperty.

## Review Findings (2026-09-16 18:32)

> Scope: `review sha HEAD~1..HEAD` (3cafd8c). 1 file reviewed. No findings.