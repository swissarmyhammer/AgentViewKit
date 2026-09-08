---
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: b280
title: AuthorizationPresenter over ASWebAuthenticationSession with an injected session factory (plan §12)
---
## What
Create `Sources/AgentViewKit/Connections/AuthorizationPresenter.swift` and `WebAuthSessionFactory.swift`, per plan.md §12.

- `WebAuthSessionFactory` protocol: `makeSession(url:callbackScheme:completion:) -> WebAuthSession` where `WebAuthSession` has `prefersEphemeralWebBrowserSession`, `presentationContextProvider`, `start() -> Bool`, `cancel()`. The default factory wraps `ASWebAuthenticationSession`.
- `AuthorizationPresenter` (`@MainActor`): `init(factory:)`, `present(url:callbackScheme:ephemeral:) async throws -> URL`. It supplies the presentation anchor from the key window (or an injected `NSWindow`), starts the session on a user action, and returns the callback URL. Throws `AuthorizationPresenterError.cancelled` when the session ends without a callback and `.failedToStart` when `start()` returns false.
- Touches no OAuth protocol. No token, no PKCE, no discovery.

## Acceptance Criteria
- [ ] With a fake factory that completes with a URL, `present` returns that URL.
- [ ] With a fake that completes with the cancelled error, `present` throws `.cancelled`.
- [ ] `ephemeral: true` sets `prefersEphemeralWebBrowserSession` on the session.

## Tests
- [ ] `Tests/AgentViewKitTests/Connections/AuthorizationPresenterTests.swift`: the three cases with the fake factory.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.