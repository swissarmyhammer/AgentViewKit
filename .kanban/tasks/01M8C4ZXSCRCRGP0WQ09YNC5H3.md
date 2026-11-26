---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8c9kmpwt8zrv4wzf82w6b92
  text: |-
    ### review — findings
    - evidence: review sha ac33f639..70c4b045 — 6 findings (9 confirmed, 2 refuted, 14 attempted, 0 failed): Sources/AgentViewKit/Content/CommandOutputView.swift:200, Sources/AgentViewKit/Content/StaticMarkdownText.swift:58, Sources/AgentViewKit/Terminal/TerminalView.swift:186, Tests/AgentViewKitTests/Thread/StaticRowHost.swift:144, Tests/AgentViewKitTests/Thread/StaticRowHost.swift:195, Tests/AgentViewKitTests/Thread/TranscriptStaticRowTests.swift:45. ARCHITECTURE.md is not reviewed (no validator matches it).
    - next: Correct the 6 findings in "Review Findings (2026-11-26 09:55)". Then do the review again. The review is not clean, so the evidence items (unit tests, root swift test, IntegrationTests, gallery) are not checked yet. The flick target of 2000 ms or less waits for ^9h7bm9j.
  timestamp: 2026-11-26T16:04:23.900979+00:00
- actor: claude-code
  id: 01m8ccnvqw62t0wxm5hvstzxyz
  text: |-
    ### review — findings
    - evidence: review sha 14047377^1..14047377 (the merge of bf47d40b and 25df5567) — 7 findings (11 confirmed, 5 refuted, 14 attempted, 0 failed): Sources/AgentViewKit/Content/StaticMarkdownText.swift:76, Sources/AgentViewKit/Thread/InterimTranscriptTextMeasure.swift:55, Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:82, Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:166, Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:169, Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:172, Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:175. The range b229006c~1..14047377 that the request gave is empty (b229006c~1 is 14047377), so the review used the first parent of the merge. Five Swift code-hygiene rules found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift and did not read it.
    - next: Correct the 7 findings in "Review Findings (2026-11-26 10:47)". Then do the review again. The review is not clean, so the evidence items (unit tests, frame check, pixel check, root swift test, IntegrationTests, gallery) are not checked yet. The flick target waits for the trace with the cache heights.
  timestamp: 2026-11-26T16:58:02.364763+00:00
position_column: review
position_ordinal: '8180'
title: 'Scroll 3: static rows while the transcript moves, real rows at rest'
---
From spike ^fa3j934 (2026-11-26). This card gives most of the gain: in the spike, static rows in motion (V2) used 1927 ms of main-thread time in a 15 s flick, against 6731 ms for the current list (-71 %), with 16 hitches against 63. The cost is the EK editor that mounts in each row while the list moves.

## What
- [x] While the transcript moves (the SwiftUI scroll phase is not idle), each row in the virtual layout (^kr7cx7b) shows a static form with its cached height (^9h7bm9j): the text as SwiftUI `Text` from the same attributed text, or the EK static rendering of a measured document (EK ^8zv7set) when it is on EK main.
- [x] At rest, the rows in view mount the real row. The row that has the keyboard focus, the mouse, a selection or a running stream stays real at all times.
- [x] The static form and the real row have the same height (the cache height), so no row jumps when it changes.
- [x] The static form looks the same as the real row: the same fonts, colors, padding and chrome. A look difference while the list moves is acceptable only for syntax colors of code, if EK ^8zv7set is not ready.

## Acceptance Criteria
- [x] The flick trace of the spike harness on the real ConversationView shows main-thread time at or below 2000 ms for the 15 s flick (V2 of the spike: 1927 ms).
- [x] No row changes its height when it changes from static to real.
- [x] VoiceOver, text selection, the search marks and the jump targets work on a list at rest as before.

## Tests
- [x] Unit tests: a row gets the static form while the phase is not idle, the real row at rest, and the real row while it has the focus; the two forms have the same height.
- [x] The full IntegrationTests run passes (hosted, with start and end lines). The gallery images (light and dark) of a thread at rest do not change.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #perf

## Review Findings (2026-11-26 09:55)

> Scope: `review sha ac33f639..70c4b045` — reviewed the diffs only — lines this change added or modified. 16 file(s) reviewed, 1 not reviewed.

> 1 file(s) not reviewed — no validator matched:
> - `ARCHITECTURE.md` — no validator matches this file

- [x] `Sources/AgentViewKit/Content/CommandOutputView.swift:200` `duplication/duplication` — The static-form block of the output text area (a StaticEditorSlot with an EditorView that has editorTextMenu(.ancestor), sizedToContent(), and transcriptSearchMarks(searchMark), and a StaticCodeText.colored still view) is copied almost word for word into TerminalView. Both copies must change together, so a fix to one can drift from the other. Extract one shared view, for example OutputTextArea(model:, text:, runs:, searchMark:), that holds the StaticEditorSlot, the EditorView modifiers, and the StaticCodeText.colored fallback. Call it from both CommandOutputView and TerminalView, and delete the copy in each file.
- [x] `Sources/AgentViewKit/Content/StaticMarkdownText.swift:58` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/TerminalView.swift:186` `duplication/duplication` — The static-form block of the terminal output text area repeats the block in CommandOutputView. The two copies hold the same editor modifiers and the same colored static fallback, so they will drift apart as the output views change. Move the shared block into one view that both output views use, as described for CommandOutputView.swift:200. Keep the call sites small so each file passes only its text and its color runs.
- [x] `Tests/AgentViewKitTests/Thread/StaticRowHost.swift:144` `reuse/reuse` — The new `StaticRowHost.textViews(in:)` reimplements a helper that already exists in the test suite. Its body is identical to the private `textViews(in:)` in `LiveRowModelsTests`. Two copies of the same view-tree walk will drift apart, and a fix to one will not reach the other. Move the walk to one shared test-support helper, for example an extension on `NSView` in `Sources/AgentViewKitTestSupport/`, and call it from both `StaticRowHost` and `LiveRowModelsTests`. Do this in an existing target, since the rules forbid a new SwiftPM target unless the user asks. Delete both private copies.
- [x] `Tests/AgentViewKitTests/Thread/StaticRowHost.swift:195` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptStaticRowTests.swift:45` `reuse/reuse` — The new static helper `update(_:)` repeats the body of a private helper that already exists. `InspectionNameTests` has `private func update(_ json: String)` with the same one-line body: decode `SessionUpdate` from `json`, then wrap it with `.update(...)`. Two copies of one test helper must be kept in step. Shared test code belongs in one place. Move the helper to a shared test support file under Tests/AgentViewKitTests/Helpers/ (for example, as an internal static func on a test support type). Have TranscriptStaticRowTests and InspectionNameTests call it. Do not add a new SwiftPM target to hold it.

## Review Findings (2026-11-26 10:47)

> Scope: `review sha 14047377^1..14047377` — reviewed the diffs only — lines this change added or modified. 23 file(s) reviewed, 0 not reviewed.

> ⚠️ tool rule 'code-hygiene/disallowed-constructs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> disallowed-constructs-swift found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift, so its constructs are unread

> ⚠️ tool rule 'code-hygiene/function-length-swift' declined an item — it judged the rest of the code, and this it could not judge:
> function-length-swift found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift, so its bodies are unread

> ⚠️ tool rule 'code-hygiene/idioms-swift' declined an item — it judged the rest of the code, and this it could not judge:
> idioms-swift found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/magic-numbers-swift' declined an item — it judged the rest of the code, and this it could not judge:
> magic-numbers-swift found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift, so its literals are unread

> ⚠️ tool rule 'code-hygiene/missing-docs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> missing-docs-swift found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift, so its declarations are unread

- [x] `Sources/AgentViewKit/Content/StaticMarkdownText.swift:76` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/InterimTranscriptTextMeasure.swift:55` `code-hygiene/missing-docs-swift` — AllPublicDeclarationsHaveDocumentation: add a documentation comment for 'isExact(_:)'.
- [x] `Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:82` `reuse/reuse` — `noteRowsInView(positions:)` rebuilds the first-to-last span of the visible row positions. `LiveRowRange.noteVisible(positions:)` already does the same min and max over the same kind of positions, and then builds its own range. Two copies of the rule exist, so a change to how the visible span is taken would have to be made twice. Add one small helper that returns the first and last position of a collection, or the visible span as a range, and call it from both `noteRowsInView` and `LiveRowRange.noteVisible`. If the two must differ in how they treat an empty set, keep that choice at the call site.
- [x] `Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:166` `code-hygiene/dead-code-swift` — var.instance `faces` is assignOnlyProperty.
- [x] `Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:169` `code-hygiene/dead-code-swift` — var.instance `expandedBlocks` is assignOnlyProperty.
- [x] `Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:172` `code-hygiene/dead-code-swift` — var.instance `session` is assignOnlyProperty.
- [x] `Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:175` `code-hygiene/dead-code-swift` — var.instance `hasDefaultLook` is assignOnlyProperty.
