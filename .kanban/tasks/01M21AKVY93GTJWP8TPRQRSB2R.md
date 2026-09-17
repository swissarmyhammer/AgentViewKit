---
comments:
- actor: claude-code
  id: 01m2nxa0fzmye4gt9wktqa3fkm
  text: 'Note from ^5a3wmgc (ElicitationView): `ElicitationView(request:)` shows no fields for a URL mode request. The host must show `ElicitationURLConsentView` for `.url` mode. To keep the three-action rule the same, the consent view can use `ElicitationHeader(request:)` for the server name, and the `focusReporter` environment value on appear.'
  timestamp: 2026-09-16T20:07:38.751724+00:00
- actor: claude-code
  id: 01m2pfz9j0yyc7xpytjfw3zw62
  text: |-
    ### finish iteration 1 — findings
    - implement: added URLDisplay, ElicitationURLConsentView, the `authorizationPresenter` environment value, `startRespond(to:_:)`, and the URL mode card in PendingRequestsHost.
    - test: swift test passed. AgentViewKitTests 995, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 1.
    - commit: b89b99b
    - review: 11 findings (10 magic-numbers-swift in URLDisplay.swift:30-39, 1 swift/immutability in URLDisplay.swift:99).
  timestamp: 2026-09-17T01:33:50.528049+00:00
- actor: claude-code
  id: 01m2pg3wh8750z0743j0aq8e6k
  text: |-
    ### finish iteration 2 — done
    - implement: named the Unicode script ranges in `URLDisplay.Ranges`, and built the script set with `filter` and `map`.
    - test: swift test passed. AgentViewKitTests 995, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 1.
    - commit: fa43819
    - review: clean (0 new findings, all prior items checked).
  timestamp: 2026-09-17T01:36:21.032160+00:00
depends_on:
- 01M21BDG310SH8A60AFWXKPSDC
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BD0YVS2J4MD6VXDM317W6
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: done
position_ordinal: b480
title: ElicitationURLConsentView and URLDisplay on AuthorizationPresenter (plan §13.3)
---
## What
Create `Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift` and `URLDisplay.swift`, per plan.md §13.3. `AuthorizationView` is in its own task.

- `URLDisplay.highlighted(_ url: URL) -> AttributedString`: the full URL with the host in bold; `URLDisplay.warning(for:) -> String?` returns a message when the host contains Punycode (`xn--`) or mixed scripts.
- `ElicitationURLConsentView(request:)`: shows the server, the message, the highlighted URL, and the warning when present. Never auto-opens or pre-fetches. "Open in browser" calls `AuthorizationPresenter.present` (injected through the environment) and then `respond(to:_:)` with `.accept(nil)`. Shows a waiting state until the request leaves `pendingElicitations`, with Retry and Cancel always present. Cancel sends `.cancel`.
- Accessibility identifiers: `elicitation-url`, `elicitation-url-warning`, `elicitation-open`, `elicitation-retry`, `elicitation-cancel`, `elicitation-waiting`.

## Acceptance Criteria
- [x] The URL element value has the host in bold; an `xn--` host mounts `elicitation-url-warning`.
- [x] Before any press, the injected presenter records zero calls.
- [x] After a press on `elicitation-open`, the presenter records one call, `respond` receives `.accept(nil)`, and `elicitation-waiting` is present.
- [x] A press on `elicitation-cancel` sends `.cancel`.

## Tests
- [x] `Tests/AgentViewKitTests/Elicitation/URLDisplayTests.swift`.
- [x] `Tests/AgentViewKitTests/Elicitation/ElicitationURLConsentViewHostedTests.swift`: with `FakeWebAuthSession` and `NoopThreadActions`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 20:30)

> Scope: `review sha HEAD~1..HEAD` (b89b99b).

- [x] `Sources/AgentViewKit/Elicitation/URLDisplay.swift:30` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/URLDisplay.swift:31` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/URLDisplay.swift:32` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/URLDisplay.swift:33` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/URLDisplay.swift:34` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/URLDisplay.swift:35` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/URLDisplay.swift:36` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/URLDisplay.swift:37` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/URLDisplay.swift:38` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/URLDisplay.swift:39` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/URLDisplay.swift:99` `swift/immutability` — Uses a mutable `var` accumulator inside a loop to build a collection, requiring a reader to walk the entire loop body to understand the final value. This should be built with functional methods. Replace with functional collection building: `Set(text.unicodeScalars.filter(\.properties.isAlphabetic).map { script(of: $0.value) })`.

## Review Findings (2026-09-16 20:35)

> Scope: `review sha HEAD~1..HEAD` (fa43819). No new findings.
