---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21ACHJYSF8G8R7HY3M70Z7F
- 01M21ACSE9JBXMRD2FQQD4CYR6
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: '9380'
title: 'ResponseView on Textual: settled paragraphs, streaming tail, code fence routing (plan §4.2, §8, §9 B)'
---
## What
Create `Sources/AgentViewKit/Content/ResponseView.swift` and `ParagraphView.swift`, per plan.md §4.2, §8, and §9 B. The other content block views come in their own task.

- `ResponseView(message:streaming:)`: splits the text with the paragraph splitter, renders each settled paragraph through Textual once (`ParagraphView` keyed by paragraph id, `.equatable()`), and renders the streaming tail through Textual with the balanced text from `StreamingMarkdownBalancer`.
- An `.openFence` tail renders through `CodeBlockView` and feeds `EditorModel.appendStreaming` on each delta.
- Applies `EditorKitCodeBlockStyle` with `.textual.codeBlockStyle(_:)` so every fenced block renders through `CodeBlockView`.
- Each `ParagraphView` calls `BodyEvaluationCounter.note("paragraph-<id>")` under `#if DEBUG`.
- Accessibility identifier `response-paragraph-<index>` and `response-tail`.

## Acceptance Criteria
- [ ] A message with three settled paragraphs and a tail mounts four paragraph elements.
- [ ] Appending to the tail adds one evaluation for `response-tail` and zero for the three settled ids.
- [ ] A fenced block mounts a `code-block` element.

## Tests
- [ ] `Tests/AgentViewKitTests/Content/ResponseViewHostedTests.swift`: element counts, evaluation counts, fence routing.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.