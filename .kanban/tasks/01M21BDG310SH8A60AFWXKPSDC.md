---
comments:
- actor: claude-code
  id: 01m2n2jwb34wgpq6x03vj5cadn
  text: 'Note from ^he8kkt1: `Sources/AgentViewKit/Connections/WebAuthSessionFactory.swift` now holds the `WebAuthSession` and `WebAuthSessionFactory` protocols and the `WebAuthSessionCompletion` typealias (`@Sendable (URL?, (any Error)?) -> Void`). `makeSession` takes `url:callbackScheme:completion:`. In this task, add the default factory over `ASWebAuthenticationSession` to that file. `FakeWebAuthSession` (in `AgentViewKitTestSupport`) completes synchronously in `start()` with the scripted URL, with `ASWebAuthenticationSessionError(.canceledLogin)`, or returns `false` for `.failsToStart`.'
  timestamp: 2026-09-16T12:20:37.859702+00:00
- actor: claude-code
  id: 01m2n32mwprwpfwea2tfg6643a
  text: 'Correction from ^he8kkt1 (after review finding `swift/concurrency`): the session API is now async, with no completion handler. `WebAuthSessionFactory.makeSession(url:callbackScheme:) -> any WebAuthSession`. `WebAuthSession` has `prefersEphemeralWebBrowserSession`, `presentationContextProvider`, `start() async throws -> URL`, and `cancel()`. `start()` throws `WebAuthSessionError.failedToStart` when the session does not start, and `ASWebAuthenticationSessionError(.canceledLogin)` when it ends with no callback. The default factory must bridge the completion of `ASWebAuthenticationSession` to `start()`. `FakeWebAuthSession` scripts: `.callback(URL)`, `.cancelled`, `.failsToStart`, `.waitsForCancel`. The earlier note about `start() -> Bool` and a completion is no longer correct.'
  timestamp: 2026-09-16T12:29:14.518546+00:00
- actor: claude-code
  id: 01m2n4hdmz77sxpz30cg8faw23
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — added Sources/AgentViewKit/Connections/AuthorizationPresenter.swift, added SystemWebAuthSessionFactory and SystemWebAuthSession to WebAuthSessionFactory.swift, added Tests/AgentViewKitTests/Connections/AuthorizationPresenterTests.swift (10 tests).
    - test: green — swift test, 65 passed, 0 failed, no new warnings.
    - commit: 92109f3
    - review: clean — review sha HEAD~1..HEAD, 0 findings.
    - decisions: the session API is async (see the correction from ^he8kkt1), so `init(factory:anchor:)` replaces `init(factory:)` and the presenter adds `cancel()` and `isPresenting`. A cancel of the calling task also stops the session. Errors that are not the cancelled error or the start failure pass through unchanged. SystemWebAuthSession makes the ASWebAuthenticationSession in `start()`, because the system session takes its completion handler at init. The presenter default isolation is the main actor (package setting).
  timestamp: 2026-09-16T12:54:47.199390+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: done
position_ordinal: '8480'
title: AuthorizationPresenter over ASWebAuthenticationSession with an injected session factory (plan §12)
---
## What
Create `Sources/AgentViewKit/Connections/AuthorizationPresenter.swift` and `WebAuthSessionFactory.swift`, per plan.md §12.

- `WebAuthSessionFactory` protocol: `makeSession(url:callbackScheme:) -> any WebAuthSession` where `WebAuthSession` has `prefersEphemeralWebBrowserSession`, `presentationContextProvider`, `start() async throws -> URL`, `cancel()` (see the correction comment from ^he8kkt1). The default factory (`SystemWebAuthSessionFactory`) wraps `ASWebAuthenticationSession`.
- `AuthorizationPresenter` (`@MainActor`): `init(factory:anchor:)`, `present(url:callbackScheme:ephemeral:) async throws -> URL`, `cancel()`, `isPresenting`. It supplies the presentation anchor from the key window (or an injected `NSWindow`), starts the session on a user action, and returns the callback URL. Throws `AuthorizationPresenterError.cancelled` when the session ends without a callback and `.failedToStart` when the session does not start.
- Touches no OAuth protocol. No token, no PKCE, no discovery.

## Acceptance Criteria
- [x] With a fake factory that completes with a URL, `present` returns that URL.
- [x] With a fake that completes with the cancelled error, `present` throws `.cancelled`.
- [x] `ephemeral: true` sets `prefersEphemeralWebBrowserSession` on the session.

## Tests
- [x] `Tests/AgentViewKitTests/Connections/AuthorizationPresenterTests.swift`: the three cases with the fake factory.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.