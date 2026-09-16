---
comments:
- actor: claude-code
  id: 01m2nvgfqh9e8020xdmvq75m8f
  text: 'Note from ^hwpnt7d (StateBanner): `StateBanner(state:errorID:onShowError:)` shows a "Show Error" button when the host gives the `ThreadError` id and a closure. The closure gets the error id. When ErrorView exists, the view that mounts StateBanner (AgentThreadView or ConversationView) must give `errorID` (the newest ThreadError that relates to the stop reason) and an `onShowError` closure that scrolls to the ErrorView row of that id.'
  timestamp: 2026-09-16T19:36:13.809784+00:00
- actor: claude-code
  id: 01m2nwhjxkz33e3pgjnham89pj
  text: |-
    ### implement — changed
    Decisions:
    - `ErrorActions.Handler` is `@MainActor (ThreadError) -> Void`. The closure gets the error of the card, so that the host knows which error the user acted on.
    - The identifier `error-<case>` and the label "<title>, <detail>" are on the text element of the card, not on a container. A container element with one child merges into the `.contain` element of `ItemRow` and loses its identifier (tested). The action button is a sibling element with identifier `error-action-<compact|retry|rephrase>`.
    - `ItemRow` now shows `ErrorView` for `.error` items (the error placeholder is gone).
    - The `acp` and `unknown` kinds have no button. A `rateLimited` error with no reset time and a guardrail or refusal with no explanation show a fixed text.
    - The note about `StateBanner` is for the view that mounts the banner. I wrote it on ^xa2n421 (ConversationView).
    - evidence: `swift test --filter AgentViewKitTests` — 653 tests in 58 suites passed.
  timestamp: 2026-09-16T19:54:18.419130+00:00
- actor: claude-code
  id: 01m2nwv2ynk9t3ppxrghgpnmyy
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — ErrorView.swift, ErrorActions.swift, ItemRow.swift, ErrorViewHostedTests.swift
    - test: green — swift test --filter AgentViewKitTests, 653 tests in 58 suites passed
    - commit: e1841b8
    - review: findings — Tests/AgentViewKitTests/Items/ErrorViewHostedTests.swift:82, Tests/AgentViewKitTests/Items/ErrorViewHostedTests.swift:158
  timestamp: 2026-09-16T19:59:29.749770+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: review
position_ordinal: '80'
title: 'ErrorView: one block per error kind with an action (plan §9 A2)'
---
## What
Create `Sources/AgentViewKit/Items/ErrorView.swift` and `ErrorActions.swift`, per plan.md §9 A2.

- `ThreadError` cases (from the model task): `contextSizeExceeded(contextSize, tokenCount)`, `rateLimited(resetAt)`, `guardrailViolation(explanation)`, `refusal(explanation)`, `timeout`, `acp(code, message)`, `unknown(message)`.
- `ErrorActions`: closures `compact`, `retry`, `rephrase`, each optional. The host passes them through `.errorActions(_:)`. Defaults are nil, and a nil action hides its button.
- `ErrorView(error:)`: a glass card with an SF Symbol, the title, the detail, and the action: `contextSizeExceeded` shows both counts and Compact; `rateLimited` shows the reset time and Retry; `guardrailViolation` and `refusal` show the explanation and Rephrase; `timeout` shows Retry; `acp` shows the code and message; `unknown` shows the message.
- Accessibility identifier `error-<case>` and label "<title>, <detail>".

## Acceptance Criteria
- [x] Each case mounts with identifier `error-<case>` and the expected button title.
- [x] With `compact` nil, the Compact button is absent.
- [x] Tapping Retry calls the closure once.

## Tests
- [x] `Tests/AgentViewKitTests/Items/ErrorViewHostedTests.swift`: one test per case, the nil-action case, the tap.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 14:54)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Tests/AgentViewKitTests/Items/ErrorViewHostedTests.swift:82` `completeness/invariant-propagation` — The `refusal` kind is tested only with an explanation provided, while `guardrailViolation` (lines 75–81) is tested both with and without explanation. In the ErrorView.content() function (lines 134–139 vs 128–133), both kinds handle an optional explanation identically — using a default message when nil — so the test coverage should match. Add a test case for `.refusal(explanation: nil)` with `identifier: "error-refusal"`, `buttonTitle: "Rephrase"`, and `detailParts: []` to mirror the nil-explanation test for guardrailViolation.
- [x] `Tests/AgentViewKitTests/Items/ErrorViewHostedTests.swift:158` `completeness/invariant-propagation` — The test `tappingRetryCallsTheClosureOnce` (line 158–167) verifies that tapping the Retry button calls its handler. However, the Compact button (used in the test case at line 62 for contextSizeExceeded) and Rephrase button (used at lines 76 and 83 for guardrailViolation and refusal) are included in test cases but are never tested for calling their handlers. In ErrorView.swift:185–189, all three action types are handled identically — each checks if a handler exists and calls it — so the test coverage should be symmetric. Add tests `tappingCompactCallsTheClosureOnce` (for the contextSizeExceeded case) and `tappingRephraseCallsTheClosureOnce` (for guardrailViolation or refusal case) following the same pattern as the Retry test.