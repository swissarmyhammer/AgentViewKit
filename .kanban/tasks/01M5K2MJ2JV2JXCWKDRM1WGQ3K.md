---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5k3pqmk4pp4v8ps1ymm6hh6
  text: |-
    Picked up. Research notes:
    - `swift package update EditorKit` resolved main at 34233ed (contains 7e22d7a EK-6.6 and be05965 EK-6.5). Package.resolved is gitignored in AVK, so the bump leaves no diff.
    - EditorTestSupport (UndoActionLog/UndoActionGate) is a TARGET in EditorKit, not a product; AVK cannot link it. Only EditorCommandsTestSupport is a product. The composer tests read the real window stack, so they need no fake entries anyway.
    - Window stack: root `.commandScope` of AgentThreadView (agent command scope at `.root(AgentCommandTarget.segment(for:))`) owns it; read with `system.undo.stack(for: path)`; `edit.undo` = `system.registry.perform(.undo, at: path)`.
    - StockPromptEditor = SwiftUI TextEditor -> SystemUndoSource (follows window NSUndoManager; entries only when a top-level group CLOSES, groups-by-event close at the end of a run-loop event). EditorKitPromptEditor = EditorView -> EditorUndoSource; its `pull` calls `model.replaceAll(plain)` only when the text differs (onChange initial:true), so a non-empty draft at mount is a candidate AVK-made entry.
    - AVK harness: off-screen window, `.prohibited` policy, key events through `window.sendEvent`; the only run-loop pass is the zero-wait one before each key event.
  timestamp: 2026-10-23T00:48:49.299280+00:00
- actor: claude-code
  id: 01m5k67pckc6zbg8cz8wqv7q8r
  text: |-
    Implementation landed (EditorKit at 7c043ad after the coordinator's second update; first update gave 34233ed).
    - New suite Tests/AgentViewKitTests/Input/ComposerWindowUndoHostedTests.swift, parameterized over EditorKitPromptEditor and StockPromptEditor inside AgentThreadView under a CommandSystem: (1) mount (empty and with a draft) + re-render (agent goes running, binding re-applied) -> WindowUndoChecks.expectUnavailableOnAnEmptyStack; (2) typing -> canUndo, edit.undo until !canUndo -> text empty; (3) Send clears -> the clear is a new top entry, one edit.undo restores the prompt in the text view AND the binding, and the typing entry is top again (count measured as the change across Send, so it holds with ^nmt6pdy coalescing).
    - RED first: EditorKitPromptEditor + draft left an entry on mount (AVK `pull` -> `replaceAll(draft)` from onChange(initial:)); EditorKitPromptEditor Send-undo restored the text view but never the binding (undo/redo of the window stack runs on the engine, which does not feed EditorModel.transactions). An earlier version of the test hung on an ObservationWait for that binding; the tests now assert the binding directly after waitUntilIdle.
    - Passed at once (EditorKit EK-6.5/6.6 already gives it): every StockPromptEditor case, and EditorKitPromptEditor with an empty mount and typing undo.
    - Fix in AVK (Sources/AgentViewKit/Input/EditorKitPromptEditor.swift): PromptEditorSession.model(startingWith:) seeds the engine with the prompt text at first read (no replaceAll edit), and an engine dispatch observer forwards undo/redo transactions to the commit closure so the binding follows.
    - Stock redo limit recorded as `withKnownIssue` (TextEditor writes its binding back after undo, clearing the AppKit redo list); no redo faked.
    - Harness limits: ⌘Z cannot go through NSApplication in the hosted harness, so tests run `edit.undo` via system.registry.perform(.undo, at:). Typing/Return use the harness key events to the off-screen window.
    - EditorTestSupport (UndoActionLog/UndoActionGate) is not an EditorKit product, so it cannot be linked; not needed since the tests read the real stack.
    - Full swift test: 1678 tests in 206 suites passed, 4 known issues (3 pre-existing + the stock redo limit).
  timestamp: 2026-10-23T01:33:02.227231+00:00
- actor: claude-code
  id: 01m5k67rnpn9kzevn9fchg2y4y
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Input/EditorKitPromptEditor.swift, Tests/AgentViewKitTests/Input/ComposerWindowUndoHostedTests.swift (new); EditorKit 7c043ad; red first: EditorKitPromptEditor draft-mount entry + EditorKitPromptEditor clear-undo not reaching the binding; full swift test 1678 tests / 206 suites passed, 4 known issues
    - next: review
  timestamp: 2026-10-23T01:33:04.566670+00:00
- actor: claude-code
  id: 01m5k6h17cvj8f93a8yv5zek4h
  text: |-
    ### test — green
    - evidence: swift test run twice back to back, both exit 0. Run 1: 1678 tests in 206 suites passed (67.5s), 4 known issues; 227 tests in 30 suites (XCTest-side/other runner) passed. Run 2: 1678 tests in 206 suites passed (72.1s), 4 known issues; 227 tests in 30 suites passed. 0 failures, 0 skipped. ComposerWindowUndoHostedTests passed with its 1 documented redo known issue (3 pre-existing + 1 new = 4). Only warning: the SwiftPM mlx-swift "missing creator for mutated node" notice; no project-code warnings after touching EditorKitPromptEditor.swift. EditorKit pinned at 7c043ade64e0e2dfef43e5d6f33645a0e77c4810 (no package update run).
    - next: review/commit
  timestamp: 2026-10-23T01:38:08.236677+00:00
- actor: claude-code
  id: 01m5k6p2xhwcm8ag6smvvyhb2v
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (43f1df7): 0 findings, 0 confirmed, 0 refuted (7 validator runs attempted, 0 failed); 2 files reviewed, 2 .kanban files excluded by .reviewignore
    - next: task moved to done
  timestamp: 2026-10-23T01:40:53.809642+00:00
- actor: claude-code
  id: 01m5k6pfwh22yfrsr5v2gdy2he
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — EditorKitPromptEditor: the model starts with the prompt (a draft mount adds no entry), and engine undo/redo pass to the binding (⌘Z after Send restores the prompt); new ComposerWindowUndoHostedTests for both composers; red first: the draft mount left an entry, and undoing the clear didn't restore the binding; StockPromptEditor's redo limit is a documented withKnownIssue
    - test: green — swift test run twice, 1678 passed each, 0 failed, 0 skipped, 4 known issues (3 existing + the redo limit); EditorKit 7c043ad
    - commit: 43f1df7
    - review: clean — 0 findings, task in done
  timestamp: 2026-10-23T01:41:07.089268+00:00
- actor: claude-code
  id: 01m5k6qar0hc88srgbtgkk9h4f
  text: 'Follow-up from testudoapp-2c: the StockPromptEditor redo limit is NOT final. The user asked for redo back, and EditorKit card ^2x162ch is to make ⇧⌘Z redo undone TextEditor typing through the window stack. When it lands, the `withKnownIssue` in ComposerWindowUndoHostedTests reports that the known issue no longer occurs, so the suite goes red. Then turn it into a real redo assertion and remove the limit note. If EditorKit reports that AppKit truly blocks it, the note stays.'
  timestamp: 2026-10-23T01:41:34.592979+00:00
position_column: done
position_ordinal: ffffc180
title: 'Composer undo on the window stack: no entry on mount or re-render; the clear after Send is one undoable entry'
---
Requested by testudoapp-2c (TestudoApp ^yahkhjn, the composer pushed empty undo entries). User decision (2026-10-22): clearing the composer after Send IS undoable, so ⌘Z restores the sent prompt. Do not wrap the clear to suppress undo.

EditorKit EK-6 now gives each window one undo stack:
- EK-6.3 ac4e366: the root `.commandScope` registers `edit.undo`/`edit.redo`. They're unavailable while the stack is empty.
- EK-6.5 be05965: every EditorView's undo groups go to the window stack. `model.replaceAll(text)` with UNCHANGED text adds nothing; a real change is ONE entry ("Change").
- EK-6.6 7e22d7a: system text views (TextEditor, NSTextView, field editor) feed the window stack. A group that changes no text is dead, never an entry. A programmatic clear (binding set to "") is ONE entry, and ⌘Z restores the text.
- AppKit limits: ⇧⌘Z can't redo undone TextEditor typing, because TextEditor writes the binding back. Closing a composer drops its typing entries.

Work:
- `swift package update` EditorKit to 7e22d7a or later.
- Hosted tests for BOTH composers: the default EditorKitPromptEditor, and StockPromptEditor (TextEditor over AttributedString):
  1. Mounting the thread with the composer, then forcing a re-render with no edit (e.g. a state change that redraws the composer), leaves the window stack with `canUndo == false`. This is the ^yahkhjn regression.
  2. Typing a prompt, then Send (the composer clears), leaves ONE entry for the clear. `edit.undo` restores the sent prompt text in the composer.
  3. Typing alone creates entries (sanity), and `edit.undo` removes them.
  For StockPromptEditor, write down the AppKit redo limit in a test comment or a `withKnownIssue`; don't fake a redo.
- Use the existing WindowUndoChecks helper and EditorTestSupport's UndoActionLog/UndoActionGate where they fit.
- If a test shows AVK itself adds an entry on mount or re-render (e.g. a draft restore through a changing replaceAll), fix that in AVK.
- The full `swift test` must be green. #avk-7 #testudo-request