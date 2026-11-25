---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m885d3xpvgzcnkntdx1v7qjy
  text: |-
    Research and implementation notes:
    - `ModelChangeNotice` (new file) reads `_meta` `kind` `modelChanged` and `afterMessageId`. `place(in:)` finds the LAST entry whose wire id is `.userMessage`, `.agentMessage` or `.agentThought` of that id. Each kind of message has its own id space, so two entries can have the same id; the later one is the last message of the history.
    - The key of a line is `<place key>-<index>`. The place key is `start`, or the row key of the entry (for example `agent-message-<afterMessageId>`). It holds the `afterMessageId`, a replay gives the same key, and no row key can be `start`. The identifier is `model-change-<key>`.
    - `ModelChangeLine.ID` is a struct and not a `String`. Thus a status line is not a `String` scroll target, and `onScrollTargetVisibilityChange(idType: String.self)` does not give its id to the scroll anchors.
    - `ConversationView.rows(shownCount:placements:)` shows the lines after the row of their entry. The lines at `.start` show only when `shownCount == count`. A test with `.conversationPageSize(1)` covers this; it failed with the guard removed, and passes with the guard.
    - With an empty transcript, the conversation shows its empty state, so a line at `.start` does not show. This is the prior behavior of the empty state.
    - The card says "When done: push". The dispatching agent told this step not to commit and not to push. So no commit and no push were done.
    - The validator dump is 617 KB. This step read the Swift, completeness, duplication, reuse and test-integrity rule bodies and the summaries of the tool rules, not each line of the dead-code and other-language sections.
  timestamp: 2026-11-25T01:33:58.070331+00:00
- actor: claude-code
  id: 01m885daedw7apfsyhfp9bhm3y
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Items/ModelChangeNoticeView.swift (new), Tests/AgentViewKitTests/Items/ModelChangeNoticeTests.swift (new, 14 tests), Sources/AgentViewKit/Thread/ConversationView.swift, Sources/AgentViewKit/Status/SessionNoticeBanner.swift, plan.md. `HOME=$(mktemp -d) swift test --filter ModelChangeNoticeTests`: 14 passed. `HOME=$(mktemp -d) swift test`: 1742 tests in 196 suites passed, and 59 tests in 12 suites passed; 0 failures, 0 compiler warnings.
    - next: /review. No commit and no push (the dispatching agent said so).
  timestamp: 2026-11-25T01:34:04.749566+00:00
position_column: doing
position_ordinal: '80'
title: Show a modelChanged notice as a status line in the transcript
---
Request from TestudoApp (relayed by testudoapp-9a, 2026-11-24).

## What

FoundationModelsACPAgent 71ecb5e (with Router f06ec37b) sends one ACP `session/update` with `sessionUpdate: "notice"` on a resume that moves a session to a different model:

```json
{"sessionUpdate":"notice","severity":"info","title":"This session was recorded with <repo>. It continues with <repo>.","_meta":{"kind":"modelChanged","recordedModel":"<repo>","model":"<repo>","afterMessageId":"<id>"}}
```

- `afterMessageId` is the `messageId` of the last user message, agent message or thought of the history. It is absent when the history has no message.
- The ACP client `SessionModel` puts the notice in `notices` (`SessionNotice`, with `meta`), not in `transcript`. The model removes all notices at the start of a resume. The Router keeps the notice in the history, so each resume replays it.

Show each notice with `_meta.kind == "modelChanged"` as a status line in the transcript, not as a banner and not as an agent message:

- [x] New file `Sources/AgentViewKit/Items/ModelChangeNoticeView.swift`:
  - A function that reads the notices of `kind` `modelChanged` from `SessionModel.notices` and gives the `afterMessageId` of each (a `MessageId`, or `nil`).
  - A function that gives the place of each notice in a transcript: after the entry whose wire id is `.userMessage`, `.agentMessage` or `.agentThought` of that `MessageId`. With no `afterMessageId`, or with an id that no entry has, the place is before the first entry. Two notices at one place keep their arrival order.
  - The view: a `StatusBar` (AgentViewKitStyle) with `action: nil`, severity `.information`, the title of the notice as its title, and the information symbol of `NoticeBanner.symbolName(for:)`. It uses the `StatusBarPlacement.content` surface (separator stroke, no fill, no glass; TestudoApp D213), the same as the other status notes in content. Accessibility identifier: `model-change-<key>`. The key must not change on a replay: make it from `afterMessageId` (or `start`) and the index of the notice at that place, not from the `UUID` of `SessionNotice`.
- [x] `Sources/AgentViewKit/Thread/ConversationView.swift`, `rows(shownCount:)`: show the status line of each placed notice after the row of its entry. A notice placed before the first entry shows only when the first page of the transcript is shown. A notice whose entry is on a page that is not loaded shows when that page loads.
- [x] `Sources/AgentViewKit/Status/SessionNoticeBanner.swift`: do not show a banner for a notice of `kind` `modelChanged`. All other notices stay banners.
- [x] `plan.md`: in the notices part of §3.2, add one short paragraph about the modelChanged status line, in ASD-STE100 Simplified Technical English.

## Acceptance Criteria

- [x] A thread with a user message `u1`, an agent message `a1` and a modelChanged notice with `afterMessageId` `a1` shows the status line directly below the row of `a1`, and above any later row.
- [x] A modelChanged notice with no `afterMessageId` shows above the first row.
- [x] `SessionNoticeBanner` shows no banner for a modelChanged notice, and still shows a banner for a notice with no `_meta.kind`.
- [x] After a second replay of the same history (a new `SessionModel` that gets the same updates), the status line has the same place and the same accessibility identifier.
- [x] The status line has no glass and no Dismiss button.

## Tests

- [x] New `Tests/AgentViewKitTests/Items/ModelChangeNoticeTests.swift` (unit, no window ordered in, no wait):
  - the place after a user message, after an agent message and after a thought; no `afterMessageId`; an unknown id; two notices at one place;
  - a notice with a `kind` that is not `modelChanged` is not placed;
  - the key is the same for two models that get the same updates (replay);
  - the accessibility order of the mounted `ConversationView` (or `AgentThreadView`): the identifier `model-change-…` comes directly after the element of `a1`. Use the `mount(_:)` helper pattern of `Tests/AgentViewKitTests/Thread/AnswerTextHitTests.swift`;
  - `SessionNoticeBanner` has no element for a modelChanged notice and has one for a plain notice.
  - Make the notices with `SessionModel.preview(transcript:)` and `.update(.notice(...))`, the same as the previews of `SessionNoticeBanner.swift`.
- [x] `HOME=$(mktemp -d) swift test --filter ModelChangeNoticeTests` passes. Then the full `swift test` passes with 0 failures and 0 warnings.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- When done: push, and send the sha to testudoapp-9a.