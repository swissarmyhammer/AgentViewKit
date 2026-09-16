---
comments:
- actor: claude-code
  id: 01m2n3seqf2twt7by723g8vb43
  text: |-
    ### finish — dependency added
    - The task must apply the AgentTheme bridge (`.editorTheme(agentTheme.editorTheme)`). The AgentTheme task ^dr6rk73 did not exist as a dependency.
    - The orchestrator added ^dr6rk73 to depends_on and moved this task back to todo. No code was changed.
    - Research note from the stopped run: Textual gives no raw code string in the code block configuration. `CodeBlockProxy` keeps the code in a private `content` property.
    - next: implement this task after ^dr6rk73 is done.
  timestamp: 2026-09-16T12:41:41.871855+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
- 01M21BCRF2JZ6W49NKXHE8KKT1
- 01M21ABMYXZQRNRDGB3DR6RK73
position_column: todo
position_ordinal: c980
title: CodeBlockView on EditorKit, the Textual CodeBlockStyle hook, per-fence model cache, and the streaming append helper (plan §4.1, §8)
---
## What
Create `Sources/AgentViewKit/Code/CodeBlockView.swift`, `EditorKitCodeBlockStyle.swift`, `CodeBlockModelCache.swift`, `EditorModel+Append.swift`, and `Pasteboard.swift`, per plan.md §4.1 and §8.

- `Pasteboard` protocol with `setString(_:)` and an `NSPasteboard` conformance; `EnvironmentValues.pasteboard` defaults to the general pasteboard. Tests inject `FakePasteboard`.
- `CodeBlockView(code:language:filename:)`: hosts an EditorKit `EditorView` with `isReadOnly = true`, `.editorSizingMode(.intrinsic)`, `.editorSyntax(language)` when `GrammarRegistry.grammar(for:)` is non-nil, and `LineNumbers`. A header row shows the filename or language and a Copy button that writes to the environment pasteboard. Applies the `AgentTheme` bridge. Accessibility identifier `code-block`, label "<language> code block", Copy identifier `code-block-copy`.
- `EditorKitCodeBlockStyle: StructuredText.CodeBlockStyle` for Textual. `makeBody(configuration:)` reads `languageHint` and the raw code and returns `CodeBlockView`. Confirm the exact protocol and configuration member names in the Textual 0.5.0 sources before you write it.
- `CodeBlockModelCache` (`@MainActor`): one `EditorModel` per fenced-block id, so a streaming tail re-render never rebuilds a settled block. Keyed by the paragraph id from the splitter. Evicts with the message.
- `EditorModel.appendStreaming(_ text: String)`: builds a `Transaction` with `ChangeSet(fromLength:replacements:)` that replaces the empty range at the end, dispatches it, and returns the `DispatchOutcome`. Works on a read-only model by toggling `isReadOnly` around the dispatch.

## Acceptance Criteria
- [ ] A fenced block inside a Textual document mounts a `code-block` element.
- [ ] Rendering the same fenced-block id twice returns the same `EditorModel` instance.
- [ ] `appendStreaming` on a model with text "a" and input "b" leaves `model.text == "ab"`.
- [ ] Unknown language mounts with label "plain text code block".
- [ ] A press on `code-block-copy` writes the code to the injected `FakePasteboard`.

## Tests
- [ ] `Tests/AgentViewKitTests/Code/CodeBlockModelCacheTests.swift`: identity per id, eviction.
- [ ] `Tests/AgentViewKitTests/Code/EditorModelAppendTests.swift`: append, append on read-only, append of an empty string.
- [ ] `Tests/AgentViewKitTests/Code/CodeBlockViewHostedTests.swift`: identifier, label, unknown language, copy.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.