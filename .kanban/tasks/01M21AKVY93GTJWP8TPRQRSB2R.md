---
comments:
- actor: claude-code
  id: 01m2nxa0fzmye4gt9wktqa3fkm
  text: 'Note from ^5a3wmgc (ElicitationView): `ElicitationView(request:)` shows no fields for a URL mode request. The host must show `ElicitationURLConsentView` for `.url` mode. To keep the three-action rule the same, the consent view can use `ElicitationHeader(request:)` for the server name, and the `focusReporter` environment value on appear.'
  timestamp: 2026-09-16T20:07:38.751724+00:00
depends_on:
- 01M21BDG310SH8A60AFWXKPSDC
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BD0YVS2J4MD6VXDM317W6
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: 9d80
title: ElicitationURLConsentView and URLDisplay on AuthorizationPresenter (plan §13.3)
---
## What
Create `Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift` and `URLDisplay.swift`, per plan.md §13.3. `AuthorizationView` is in its own task.

- `URLDisplay.highlighted(_ url: URL) -> AttributedString`: the full URL with the host in bold; `URLDisplay.warning(for:) -> String?` returns a message when the host contains Punycode (`xn--`) or mixed scripts.
- `ElicitationURLConsentView(request:)`: shows the server, the message, the highlighted URL, and the warning when present. Never auto-opens or pre-fetches. "Open in browser" calls `AuthorizationPresenter.present` (injected through the environment) and then `respond(to:_:)` with `.accept(nil)`. Shows a waiting state until the request leaves `pendingElicitations`, with Retry and Cancel always present. Cancel sends `.cancel`.
- Accessibility identifiers: `elicitation-url`, `elicitation-url-warning`, `elicitation-open`, `elicitation-retry`, `elicitation-cancel`, `elicitation-waiting`.

## Acceptance Criteria
- [ ] The URL element value has the host in bold; an `xn--` host mounts `elicitation-url-warning`.
- [ ] Before any press, the injected presenter records zero calls.
- [ ] After a press on `elicitation-open`, the presenter records one call, `respond` receives `.accept(nil)`, and `elicitation-waiting` is present.
- [ ] A press on `elicitation-cancel` sends `.cancel`.

## Tests
- [ ] `Tests/AgentViewKitTests/Elicitation/URLDisplayTests.swift`.
- [ ] `Tests/AgentViewKitTests/Elicitation/ElicitationURLConsentViewHostedTests.swift`: with `FakeWebAuthSession` and `NoopThreadActions`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.