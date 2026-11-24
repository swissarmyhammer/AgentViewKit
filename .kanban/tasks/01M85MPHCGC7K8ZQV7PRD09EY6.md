---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m85n0vsyz8kvfhksqrp1wksz
  text: 'Implementation done. The session (`PromptEditorSession`) keeps a new value `syncedText`: the newest text that the editor pushed or pulled. `didPush` sets it. `didPull(_:)` now takes the pulled text and sets it. `pushedText` and `isNewestPush` stay as they were. The new function `isChangedOutside(_:)` is true only when a synced text exists and the prompt text is not equal to it. In `didCommit`, after the `isPull` guard, a prompt text that changed outside the editor goes to the editor through `pull`, and the function returns with no push. The comment gives the reason (the async clear of a host composer after the Return). Discovery: `onChange(of: context.text, initial: true)` pulls at the first draw, so the synced text exists from the first draw. Unit test: `Tests/AgentViewKitTests/Input/PromptEditorSessionSyncTests.swift` (4 tests). RED was a compile failure (no `isChangedOutside`, no `didPull(_:)`); GREEN after the change. The CI criterion (`ThreadComposerHostedTests` green) is still open: hosted suites do not run locally.'
  timestamp: 2026-11-24T02:09:10.462013+00:00
- actor: claude-code
  id: 01m85n0y8y7adz9bmykx24peff
  text: |-
    ### implement — changed
    - evidence: 2 files — Sources/AgentViewKit/Input/EditorKitPromptEditor.swift, Tests/AgentViewKitTests/Input/PromptEditorSessionSyncTests.swift. `swift build` 0 warnings; `swift test` 1724 tests in 194 suites and 59 tests in 12 suites passed, 0 failures; `swift build --build-tests` in IntegrationTests complete.
    - next: /review; after commit and push, CI Integration job must run ThreadComposerHostedTests green.
  timestamp: 2026-11-24T02:09:12.990485+00:00
- actor: claude-code
  id: 01m85n50wz2n3pyry4ms5f5p01
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (038c3906); 1 finding, 1 confirmed, 0 refuted — Sources/AgentViewKit/Input/EditorKitPromptEditor.swift:417 (completeness/public-output-contract).
    - next: /implement — the early return in didCommit must not skip the .completionAccept side effects; add a test for an accept commit after an outside change. The CI item for ThreadComposerHostedTests stays open until CI runs.
  timestamp: 2026-11-24T02:11:26.751615+00:00
- actor: claude-code
  id: 01m85nh6th8bsm4c3nf5ymzafz
  text: 'Review finding done (EditorKitPromptEditor.swift, didCommit). The userEvent switch now runs before the check for an outside change, so `didAccept(in:)` runs and the accept records its file reference or mention in local values (`acceptedReferences`, `acceptedMentions`). On an outside change, `pull(_:into:keeping:mentions:)` takes the prompt text and keeps those accepted values, and the editor pushes nothing. With no outside change, the new `record(_:mentions:)` adds the accepted values to the state, then the push runs as before. New statics `references(in:root:keeping:)` and `mentions(in:root:keeping:)` give the references and mentions of a pulled text plus the kept ones; `pull` uses them, so a pull after the accept does not erase the accept. Tests: 2 new tests in `Tests/AgentViewKitTests/Input/PromptEditorSessionSyncTests.swift` (an accepted file reference and an accepted mention stay after an outside clear to ""). RED was a compile failure (no `keeping` argument); GREEN after the change. Limit: the commit flow itself is in a SwiftUI view, so the unit tests check the static decision, not a real accept commit. `swift build` shows one SwiftPM note "missing creator for mutated node" on the mlx-swift_Cmlx.bundle product; it is a build-system note on a dependency, not a compiler warning.'
  timestamp: 2026-11-24T02:18:06.033615+00:00
- actor: claude-code
  id: 01m85nh94tj34xc28fagjj54eg
  text: |-
    ### implement — changed
    - evidence: 2 files — Sources/AgentViewKit/Input/EditorKitPromptEditor.swift, Tests/AgentViewKitTests/Input/PromptEditorSessionSyncTests.swift. `swift test --filter PromptEditorSessionSyncTests` 6 passed; `swift test` 1726 tests in 194 suites and 59 tests in 12 suites passed, 0 failures; `swift build` 0 compiler warnings; `swift build --build-tests` in IntegrationTests complete.
    - next: /review; after commit and push, the CI Integration job must run ThreadComposerHostedTests green.
  timestamp: 2026-11-24T02:18:08.410115+00:00
- actor: claude-code
  id: 01m85nmkvbkbr7p4v22ya8v1k0
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (a0f7738f); 0 findings, 0 confirmed, 0 refuted; 7 attempted, 0 failed. The prior finding (EditorKitPromptEditor.swift:417, completeness/public-output-contract) is checked.
    - next: the task stays in review. After push, the CI Integration job must run ThreadComposerHostedTests green; then check the two CI items and move the task to done.
  timestamp: 2026-11-24T02:19:57.675193+00:00
position_column: review
position_ordinal: '8580'
title: A late editor commit must not give the old text back after a host composer clears the prompt
---
## What
CI run 45299061645 on 6a881d1c: `ThreadComposerHostedTests.returnGivesTheTextToTheHostAndClearsTheComposer` fails at `IntegrationTests/Tests/IntegrationTests/Thread/ThreadComposerHostedTests.swift:115` and `:118`. The host closure gets the text one time, but the draft and the editor keep "Go on" after Return.

Cause (from the code):
- With a submit hook, `PromptInputView.submit()` (`Sources/AgentViewKit/Input/PromptInputView.swift`) clears the text in a later `Task`, after the hook returns `.consumed`.
- `EditorKitPromptEditor.submit(model:modifiers:)` pulls the prompt text at once only for the synchronous send.
- In `EditorKitPromptEditor.didCommit(_:in:)` (`Sources/AgentViewKit/Input/EditorKitPromptEditor.swift`), every commit that is not a pull pushes `model.text` to the prompt. A commit that the stream gives after the async clear, and before `onChange(of: context.text)` pulls the empty text, writes the old text back. Then `onChange` sees no change and does not fire.
- In the test with a held submit, the long hold lets the stream drain first, so that test passes.

Fix: the editor session (`EditorKitPromptEditor` session class, near `didPush`/`didPull`/`isNewestPush`) keeps the last text that the editor pushed or pulled. In `didCommit`, when the prompt text is not that synced text, the prompt changed outside the editor: pull the prompt text into the model, and push nothing.

## Acceptance Criteria
- [x] A commit after an outside change of the prompt text pulls that text into the editor and does not push the editor text.
- [x] A commit with no outside change pushes the editor text as before.
- [ ] `ThreadComposerHostedTests` passes in CI (all 3 tests).

## Tests
- [x] Unit test in `Tests/AgentViewKitTests/Input/` for the session decision: after a push of "Go on" and an outside change to "", the session reports an outside change; after a push with no outside change, it does not.
- [x] `swift build` and `swift test` (unit tests only; no hosted suite locally while the screen hold stays) pass with 0 failures and 0 warnings.
- [ ] CI Integration job runs `ThreadComposerHostedTests` green.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
#bug

## Review Findings (2026-11-23 20:09)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 2 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Sources/AgentViewKit/Input/EditorKitPromptEditor.swift:417` `completeness/public-output-contract` — The new early return in didCommit skips every commit side effect when the prompt changed outside the editor. For a .completionAccept transaction, the file reference or mention is not recorded, and didAccept(in:) is not called. The pull replaces the editor text, so the accepted completion is lost without any warning or fallback. The intended fix only needed to stop the old text from being pushed back, not to drop the accept side effects. Keep the pull, but do not return before the userEvent switch. Run the accept side effects first, or skip only the push at line 437. Add a test where an accept commit follows an outside change and check that the file reference or mention is still recorded.

## Review Findings (2026-11-23 20:18)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 2 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

No findings (a0f7738f): 0 findings, 0 confirmed, 0 refuted.
