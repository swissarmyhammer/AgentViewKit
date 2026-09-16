---
comments:
- actor: claude-code
  id: 01m2nvgfqh9e8020xdmvq75m8f
  text: 'Note from ^hwpnt7d (StateBanner): `StateBanner(state:errorID:onShowError:)` shows a "Show Error" button when the host gives the `ThreadError` id and a closure. The closure gets the error id. When ErrorView exists, the view that mounts StateBanner (AgentThreadView or ConversationView) must give `errorID` (the newest ThreadError that relates to the stop reason) and an `onShowError` closure that scrolls to the ErrorView row of that id.'
  timestamp: 2026-09-16T19:36:13.809784+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: todo
position_ordinal: b580
title: 'ErrorView: one block per error kind with an action (plan §9 A2)'
---
## What
Create `Sources/AgentViewKit/Items/ErrorView.swift` and `ErrorActions.swift`, per plan.md §9 A2.

- `ThreadError` cases (from the model task): `contextSizeExceeded(contextSize, tokenCount)`, `rateLimited(resetAt)`, `guardrailViolation(explanation)`, `refusal(explanation)`, `timeout`, `acp(code, message)`, `unknown(message)`.
- `ErrorActions`: closures `compact`, `retry`, `rephrase`, each optional. The host passes them through `.errorActions(_:)`. Defaults are nil, and a nil action hides its button.
- `ErrorView(error:)`: a glass card with an SF Symbol, the title, the detail, and the action: `contextSizeExceeded` shows both counts and Compact; `rateLimited` shows the reset time and Retry; `guardrailViolation` and `refusal` show the explanation and Rephrase; `timeout` shows Retry; `acp` shows the code and message; `unknown` shows the message.
- Accessibility identifier `error-<case>` and label "<title>, <detail>".

## Acceptance Criteria
- [ ] Each case mounts with identifier `error-<case>` and the expected button title.
- [ ] With `compact` nil, the Compact button is absent.
- [ ] Tapping Retry calls the closure once.

## Tests
- [ ] `Tests/AgentViewKitTests/Items/ErrorViewHostedTests.swift`: one test per case, the nil-action case, the tap.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.