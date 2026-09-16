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
- actor: claude-code
  id: 01m2n59x2y6tp39w50yfwc9wy2
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 5 source files, 3 test files, Docs/decisions/code-block-source.md
    - test: green — swift test, 93 passed (28 new in the Code suites)
    - commit: 8958054
    - review: findings — CodeBlockModelCache.swift:90, CodeBlockView.swift:25, CodeBlockView.swift:88
    - decisions: Textual 0.5.0 has no public raw code, so the style reads the private `content` of `CodeBlockProxy` with `Mirror` (the exact pin and a hosted test guard it). The `Pasteboard` protocol keeps `copyText(_:)` from ^he8kkt1. The label uses the trimmed language hint, and "plain text" when the hint is missing or empty. See Docs/decisions/code-block-source.md.
    - next: the three findings are fixed in the tree; commit and review again.
  timestamp: 2026-09-16T13:08:09.438831+00:00
- actor: claude-code
  id: 01m2n5ewkgadrw5kpwtwdeem3h
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — makeReadOnly rename, internal view inputs, syncModel method
    - test: green — swift test, 93 passed
    - commit: 4da0f6d
    - review: clean — review sha HEAD~1..HEAD, 0 findings; all prior findings checked; task moved to done
  timestamp: 2026-09-16T13:10:52.784067+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
- 01M21BCRF2JZ6W49NKXHE8KKT1
- 01M21ABMYXZQRNRDGB3DR6RK73
position_column: done
position_ordinal: '8580'
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
- [x] A fenced block inside a Textual document mounts a `code-block` element.
- [x] Rendering the same fenced-block id twice returns the same `EditorModel` instance.
- [x] `appendStreaming` on a model with text "a" and input "b" leaves `model.text == "ab"`.
- [x] Unknown language mounts with label "plain text code block".
- [x] A press on `code-block-copy` writes the code to the injected `FakePasteboard`.

## Tests
- [x] `Tests/AgentViewKitTests/Code/CodeBlockModelCacheTests.swift`: identity per id, eviction.
- [x] `Tests/AgentViewKitTests/Code/EditorModelAppendTests.swift`: append, append on read-only, append of an empty string.
- [x] `Tests/AgentViewKitTests/Code/CodeBlockViewHostedTests.swift`: identifier, label, unknown language, copy.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 08:01)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 8 file(s) reviewed, 5 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `Docs/decisions/code-block-source.md` — no validator matches this file

- [x] `Sources/AgentViewKit/Code/CodeBlockModelCache.swift:90` `swift/fluent-usage` — Factory method does not follow the naming convention. Factory methods that create instances should begin with `make` to clearly signal object creation. Rename to `static func makeReadOnly(_ code: String) -> EditorModel`.
- [x] `Sources/AgentViewKit/Code/CodeBlockView.swift:25` `swift/access-control` — Input property marked `private` should be `internal`. SwiftUI view input properties must participate in the synthesized memberwise initializer and not be marked `private`. Remove `private` modifier: change to `let code: String`.
- [x] `Sources/AgentViewKit/Code/CodeBlockView.swift:88` `swift/initialization` — Callback closure contains branching logic (`if` statement) which buries control flow where it cannot be named or tested. Should be extracted to a named method. Extract the branching logic to a private method: `private func updateReadOnlyIfNeeded() { if !model.isReadOnly { model.isReadOnly = true }; model.syncStreaming(to: code) }` and call it from the onChange closure.
