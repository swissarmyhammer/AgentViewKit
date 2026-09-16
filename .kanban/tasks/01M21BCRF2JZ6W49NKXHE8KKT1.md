---
comments:
- actor: claude-code
  id: 01m2n2jn6kxtg1m5t7ah7her91
  text: |-
    ### implement — changed
    - evidence: Package.swift (new AgentViewKitTestSupport target, linked from the four kit test targets); Sources/AgentViewKit/Platform/{Pasteboard,Announcer,FocusReporter,ProcessLauncher}.swift; Sources/AgentViewKit/Connections/WebAuthSessionFactory.swift; Sources/AgentViewKit/Diagnostics/BodyEvaluationCounter.swift; Sources/AgentViewKitTestSupport/{HostedViewHarness,FakePasteboard,RecordingAnnouncer,RecordingFocusReporter,FakeWebAuthSession,FakeProcessLauncher}.swift; Tests/AgentViewKitTests/TestSupport/{HostedViewHarnessTests,FakesTests,BodyEvaluationCounterTests}.swift; two manifest tests in Tests/PackageStructureTests/ManifestTests.swift.
    - next: test
  timestamp: 2026-09-16T12:20:30.547634+00:00
- actor: claude-code
  id: 01m2n2jqcra0fskqsz660ekggg
  text: |-
    ### test — green
    - evidence: `swift test` exits 0: 46 tests (PackageStructureTests 15, AgentViewKitTests 28, three adapter targets 1 each). `swift test --filter AgentViewKitTests` passed 3 runs in a row. No warning in Sources, Tests, or Package.swift.
    - next: commit
  timestamp: 2026-09-16T12:20:32.792649+00:00
- actor: claude-code
  id: 01m2n2xrx4tjczv01d8hq9aay7
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (4fe730f), 16 findings — WebAuthSessionFactory.swift:50, BodyEvaluationCounter.swift:13, HostedViewHarness.swift:63, 66, 195, 226, 389-397, 411
    - next: implement
  timestamp: 2026-09-16T12:26:34.788981+00:00
- actor: claude-code
  id: 01m2n2xtydpqvmnhsxf059yqh3
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 17 source and test files, Package.swift
    - test: green — swift test, 46 passed
    - commit: 4fe730f
    - review: findings — Sources/AgentViewKit/Connections/WebAuthSessionFactory.swift:50, Sources/AgentViewKit/Diagnostics/BodyEvaluationCounter.swift:13, Sources/AgentViewKitTestSupport/HostedViewHarness.swift:63, :66, :195, :226, :389, :390, :391, :392, :393, :394, :395, :396, :397, :411
  timestamp: 2026-09-16T12:26:36.877660+00:00
- actor: claude-code
  id: 01m2n32v2g5ytwd77p660v85nn
  text: |-
    ### implement — changed
    - evidence: all 16 findings fixed. WebAuthSessionFactory.swift: async `start() async throws -> URL`, no completion handler, new `WebAuthSessionError`. FakeWebAuthSession.swift: async scripts, with `.waitsForCancel`. BodyEvaluationCounter.swift: `private static let storage` over a private storage class. HostedViewHarness.swift: file-scope `HarnessConstants` with `static let` values; key codes from Carbon `kVK_*`; function keys found by the Unicode private-use category. FakesTests.swift: four async web authentication tests. `swiftlint --only-rule no_magic_numbers` over Sources: no violation.
    - next: test
  timestamp: 2026-09-16T12:29:20.848850+00:00
- actor: claude-code
  id: 01m2n32wtyj72v97nb1kz35wbj
  text: |-
    ### test — green
    - evidence: `swift test` exits 0: 46 tests (PackageStructureTests 15, AgentViewKitTests 28, adapter targets 1 each). `swift build --build-tests`: no warning in Sources, Tests, or Package.swift.
    - next: commit
  timestamp: 2026-09-16T12:29:22.654274+00:00
- actor: claude-code
  id: 01m2n35n6808w3vcp5nerx40ch
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (67921aa), 0 findings; all 16 prior findings checked
    - next: none
  timestamp: 2026-09-16T12:30:53.128311+00:00
- actor: claude-code
  id: 01m2n35p51sydnd1yd6xkwtjqb
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — 5 files, all 16 findings fixed
    - test: green — swift test, 46 passed
    - commit: 67921aa
    - review: clean — 0 findings
  timestamp: 2026-09-16T12:30:54.113752+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: done
position_ordinal: '8280'
title: 'AgentViewKitTestSupport target: hosted view harness, evaluation counter, fakes for pasteboard, announcer, focus, and auth session'
---
## What
Create the test-support target that every hosted view test uses. Add `AgentViewKitTestSupport` to `Package.swift` as a library target (not a product) that depends on `AgentViewKit`, and add it to every test target's dependencies. This task holds only view-neutral helpers. `NoopThreadActions` and the thread fixtures come with the actions task.

- `Sources/AgentViewKitTestSupport/HostedViewHarness.swift`: mounts any SwiftUI view in an `NSHostingView` inside an off-screen `NSWindow`, pumps the run loop for a given duration, and exposes `accessibilityElements()` (a flattened list with role, label, value, identifier, and `linkedElements` from `accessibilityLinkedUIElements()`), `element(identifier:)`, `press(identifier:)`, `type(_ text: String)`, and `sendKey(_:modifiers:)`.
- `BodyEvaluationCounter.swift`: a `@MainActor` counter keyed by a string. A view calls `BodyEvaluationCounter.note("row-<id>")` in `body` under `#if DEBUG`. Tests read and reset counts.
- `FakePasteboard.swift`: the `Pasteboard` protocol the kit uses for copy, with a recording fake. `NSPasteboard` conforms in the kit.
- `RecordingAnnouncer.swift`: the `Announcer` protocol the accessibility task uses, with a recording fake.
- `RecordingFocusReporter.swift`: the `FocusReporter` protocol the pending-request host calls when it moves focus, with a recording fake.
- `FakeWebAuthSession.swift`: a `WebAuthSessionFactory` fake that returns a scripted callback URL or throws cancelled.
- `FakeProcessLauncher.swift`: a `ProcessLauncher` fake that records the program, arguments, and environment, and feeds scripted output.

## Implementation notes
- The kit views call `BodyEvaluationCounter.note`, and the kit uses the protocols. The kit cannot import the test-support target. Thus `BodyEvaluationCounter` (debug builds only), `Pasteboard`, `Announcer`, `FocusReporter`, `ProcessLauncher` with `LaunchedProcess`, and `WebAuthSessionFactory` with `WebAuthSession` are in `Sources/AgentViewKit`. The fakes and the harness are in `Sources/AgentViewKitTestSupport`.
- `ProcessLauncher` has no ACP type, so it is in the kit target. The ACP verbs task adds only the default launcher over `AgentProcess`.
- `WebAuthSessionFactory.swift` holds only the protocols and `WebAuthSessionError`. The session API is async: `makeSession(url:callbackScheme:) -> any WebAuthSession`, and `WebAuthSession.start() async throws -> URL` with `cancel()`. The AuthorizationPresenter task adds the default factory over `ASWebAuthenticationSession`.
- SwiftUI builds its accessibility tree only after an assistive client sets `AXEnhancedUserInterface` on the application. The harness sets this attribute. SwiftUI nodes answer the `NSAccessibilityProtocol` selectors but do not declare the protocol, so the harness reads them through Objective-C dynamic lookup.
- ApplicationServices also declares `Pasteboard`. Code that imports AppKit writes `AgentViewKit.Pasteboard`.
- `PackageStructureTests` links no package target by design, so it does not link the test-support target.

## Acceptance Criteria
- [x] A test can mount `Text("hi")`, pump, and read one accessibility element with label "hi".
- [x] `BodyEvaluationCounter` counts increment on re-evaluation and reset between tests.
- [x] Each fake records calls in order.

## Tests
- [x] `Tests/AgentViewKitTests/TestSupport/HostedViewHarnessTests.swift`: the mount and read case, a press, a key, the linked-elements read.
- [x] `Tests/AgentViewKitTests/TestSupport/FakesTests.swift`: each fake.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 07:20)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 17 file(s) reviewed, 8 not reviewed.

> 8 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 8 file(s)

- [x] `Sources/AgentViewKit/Connections/WebAuthSessionFactory.swift:50` `swift/concurrency` — New public API for inherently async work (web authentication) uses a completion-handler callback instead of async/await. Per Swift concurrency guidelines, prefer async/await over @escaping completion handlers in new code. Redesign the protocol to use async/await: `func makeSession(url: URL, callbackScheme: String) async throws -> (URL?, (any Error)?)` to return the result asynchronously or throw. Test fakes would implement async functions with scripted returns instead of calling completion handlers.
- [x] `Sources/AgentViewKit/Diagnostics/BodyEvaluationCounter.swift:13` `swift/immutability` — Stored `static var` is mutable shared state that any method can modify globally. Per Swift API design guidelines, static members must be either `let` (immutable) or computed `var` (derived from other state). Refactor to use a `static let` pointing to a mutable container class: Create `private class CountsStorage { var data: [String: Int] = [:] }`, then declare `private static let counts = CountsStorage()`. Update all accesses from `counts[key]` to `counts.data[key]`.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:63` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:66` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:195` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:226` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:389` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:390` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:391` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:392` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:393` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:394` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:395` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:396` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:397` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKitTestSupport/HostedViewHarness.swift:411` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.