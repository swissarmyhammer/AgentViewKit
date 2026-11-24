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
position_column: doing
position_ordinal: '80'
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
- [ ] A commit after an outside change of the prompt text pulls that text into the editor and does not push the editor text.
- [ ] A commit with no outside change pushes the editor text as before.
- [ ] `ThreadComposerHostedTests` passes in CI (all 3 tests).

## Tests
- [ ] Unit test in `Tests/AgentViewKitTests/Input/` for the session decision: after a push of "Go on" and an outside change to "", the session reports an outside change; after a push with no outside change, it does not.
- [ ] `swift build` and `swift test` (unit tests only; no hosted suite locally while the screen hold stays) pass with 0 failures and 0 warnings.
- [ ] CI Integration job runs `ThreadComposerHostedTests` green.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
#bug