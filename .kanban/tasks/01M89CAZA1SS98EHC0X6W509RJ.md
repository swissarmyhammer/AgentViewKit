---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m89pdd0q27wzzxrvn8kkh3zp
  text: 'Research: the copy text is empty only when ThreadExporter.messageTexts(in:) is empty, because each message section starts with a role line that is never empty ("User:" or "Assistant:"). A message whose only text block is "" still gives the text "User:" plus a line, so the cheap check must count it as text. The check is thus: the transcript has a user or agent message entry whose texts(of:) is not empty. It uses the same texts(of:) as the copy text, so the answers agree. The package counter is BodyEvaluationCounter, with a key of the session model (BodyEvaluationKey.make(prefix:object:)), noted in AgentCommandTarget.plainText(of:). The windowless thread mount with a window that is never ordered in is AnswerTextHitTests.mount. Note: the kanban tool writes to the board of the main checkout, not to the .kanban copy of this worktree. The harness refuses a command that sets HOME, so the suite runs with the normal HOME; these tests do not touch home.'
  timestamp: 2026-11-25T15:50:27.607744+00:00
- actor: claude-code
  id: 01m89rgr1c8k9qbdj7sxt61je2
  text: 'Review note: the review engine reads files from the main checkout, so in a worktree `review sha HEAD~1..HEAD` resolves the HEAD of main, and the code-hygiene tool rules cannot read new or changed files. Use explicit shas and `review file .claude/worktrees/<name>/<path>` with the code-hygiene validators. The file op of AgentCommandTarget.swift also gave two findings on lines this change did not write: line 306 `swift/preconditions` (the `move.path == path` guard is nested in an `if let`) and line 696 `reuse/reuse` (jumpToSession uses `first(where:)` where `select(_:id:key:)` exists). They are outside the diff of this card and other agents work in parallel, so this card does not change them.'
  timestamp: 2026-11-25T16:27:14.348847+00:00
- actor: claude-code
  id: 01m89s3f7bbcdh32804y8390g8
  text: |-
    ### review — clean
    - evidence: `review sha 9b3cab31..aaff3702` 0 findings; `review file` (code-hygiene) of ThreadExporter.swift through its worktree path 0 findings; both prior findings fixed (9b3cab31, aaff3702). `swift test`: 1744 tests in 197 suites and 59 tests in 12 suites pass, 0 failures, 0 code warnings. The harness refuses a command that sets HOME, so the suite ran with the normal HOME; the new tests do not touch home. That subtask stays open for a run by a person.
    - next: none. Branch worktree-agent-a1f63a2f80f41f3c0, commits 9c2888a4, 9b3cab31, aaff3702. Not pushed.
  timestamp: 2026-11-25T16:37:27.915320+00:00
position_column: done
position_ordinal: ffffffffa880
title: 'Scroll perf 2: the Copy Thread availability check does not render the thread'
---
User request (2026-11-25): "scrolling is still way too slow", stay with SwiftUI. The scroll profile found this is 14.7% of main-thread time at rest and 26.9% while an answer streams.

## What

- `Sources/AgentViewKit/Commands/AgentCommandTarget.swift` (about line 475): `case .copyThread: !Self.plainText(of: session).isEmpty` renders the whole thread through the `copy-text` Stencil template (`plainText(of:)`, about line 954) only to find out if the text is empty. One call costs 2.66 ms for 312 entries. The button is in each message footer (`Sources/AgentViewKit/Items/MessageActions.swift`, about lines 202 and 252), and `EditorButtonSourceReader.body` asks for the availability. Each streamed chunk changes the transcript, so each realized footer button asks again (about 6 renders of the whole thread per chunk).
- [x] Add a cheap check, for example `ThreadExporter.hasMessageText(in:)`, that returns `true` at the first message with text that the copy would keep, with no template render. It must give the same answer as `!plainText(of:).isEmpty` for each transcript.
- [x] Use it at `case .copyThread`.

## Acceptance Criteria

- [x] The availability check of Copy Thread renders no template.
- [x] Copy Thread is available in the same cases as before (an empty thread and a thread with only tool calls keep their current answers).

## Tests

- [x] New tests in `Tests/AgentViewKitTests/Commands/`: the new check and `!plainText(of:).isEmpty` agree for an empty transcript, only tool calls, only a user message, a message with empty text, and a long mixed transcript.
- [x] A counter test: a package counter on the template render of `plainText`. Mount 20 message rows with footers (window never ordered in), stream 50 agent message chunks with `session.apply`, one layout pass each, and expect 0 renders.
- [ ] `HOME=$(mktemp -d) swift test` passes with 0 failures and 0 warnings.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #perf

## Review Findings (2026-11-25 10:11)

> Scope: `review sha bdce61a2..9c2888a4` (the diff rules) and `review file` of the new test file through its worktree path (the code-hygiene tool rules, which could not read the file from the main checkout).

- [x] `Tests/AgentViewKitTests/Commands/CopyThreadAvailabilityTests.swift:97` `reuse/reuse` — The transcript built at lines 97-99 repeats the turn loop of `longMixedTranscript` (lines 42-44): `(0..<n).flatMap { turn in [.user(...), .agent(...)] }`. Two copies of the same turn-building shape can diverge. The author should have extended the existing shape with a parameter for the turn count and item set, or pulled out one shared helper. Add a helper such as `static func turns(_ count: Int, withThoughtsAndTools: Bool) -> [PreviewTranscriptItem]`, or a closure parameter for the per-turn items. Use it for both `longMixedTranscript` and the transcript in `streamedChunksRenderNoCopyText`. Keep the per-case literal arrays in `transcripts` as they are, since they are per-case data and not a reuse miss.

## Review Findings (2026-11-25 10:22)

> Scope: `review sha 9c2888a4..9b3cab31` (clean), and `review file` with the code-hygiene validators of each changed file through its worktree path, because the tool rules read the main checkout. Only findings on lines this change wrote are listed here.

- [x] `Sources/AgentViewKit/Items/ThreadExporter.swift:115` `reuse/reuse` — `hasMessageText(in:)` repeats the traversal of `messageTexts(in:)` (lines 96-102): it walks the transcript, calls `message(of:)`, and calls `texts(of:)`. Its own doc comment says its answer equals `!messageTexts(in:).isEmpty`. The duplicate logic can drift from `messageTexts(in:)`, so a change to the copy-text rules could leave the availability check out of step with the copy text. Keep one source of truth. Either implement `hasMessageText(in:)` as `!messageTexts(in: transcript).isEmpty`, or add a shared lazy helper (for example, a sequence of `MessageText` values) that both functions consume. Use the lazy form if the early exit is needed for performance.