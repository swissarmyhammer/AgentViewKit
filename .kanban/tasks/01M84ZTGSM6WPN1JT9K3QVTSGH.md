---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: Keep the EditorKit models of thread rows in a thread-level cache so rows that come back do not rebuild
---
## Rule
Stay with SwiftUI and use it smarter. Do not replace views with AppKit.

## What
Bug: "scrolling is not very smooth in the agent view" (seen in TestudoApp). Rows that come back into the live range make new EditorKit models in batches.
- Sources/AgentViewKit/Thread/LiveRowRange.swift:23 `margin = 16`, :31 `slack = 8`, :47-51 `noteVisible` moves the range in large steps.
- Sources/AgentViewKit/Content/ResponseView.swift:218-227 shows a placeholder when the row is not live; the editor then leaves the tree.
- Sources/AgentViewKit/Content/RenderedMarkdownView.swift:91 and Sources/AgentViewKit/Code/CodeBlockView.swift:45 keep the model in `OwnModelSlot` (@State). The slot goes away with the view, so a row that comes back makes a new model.
- TestudoApp does not set `\.codeBlockModelCache` (Sources/AgentViewKit/Code/CodeBlockModelCache.swift).
- Fix: ConversationView (Sources/AgentViewKit/Thread/ConversationView.swift, near :309) sets a thread-level `CodeBlockModelCache` by default when the host does not give one. Then a row that leaves the range keeps its model. Also move the range in smaller steps (examine smaller margin/slack values).

## Acceptance Criteria
- [ ] Without a host cache, ConversationView gives one cache to all rows.
- [ ] A host cache still wins over the default.
- [ ] Scroll down and back up makes 0 new models for rows already seen.

## Tests
Write the tests first.
- Add a DEBUG `BodyEvaluationCounter` key in the make-model paths of RenderedMarkdownView and CodeBlockView.
- New hosted test in IntegrationTests/Tests/IntegrationTests/Thread/: host 300 answers with fences, scroll down and back up with the helpers `scrollToTop` and `jump` in ConversationViewHostedTests.swift:264-289, assert 0 new models on the way back.
- Run `swift test` in the root (headless). Run the hosted test alone: `cd IntegrationTests && swift test --filter <TestName>`. One hosted test at a time.
- No sleep, poll, retry or time limit. Wait only on certain events.

## Workflow
Use /tdd.

## Subtasks
- [ ] Add the DEBUG make-model counter keys.
- [ ] Add the hosted test (it fails first).
- [ ] Set a default thread-level cache in ConversationView.
- [ ] Make the range move in smaller steps; keep LiveRowRange unit tests green.
- [ ] Make the hosted test pass.

Files: ConversationView.swift, LiveRowRange.swift, RenderedMarkdownView.swift, CodeBlockView.swift, one new test file. #scroll-perf