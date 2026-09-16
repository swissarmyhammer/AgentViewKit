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
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: doing
position_ordinal: '8180'
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