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
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: doing
position_ordinal: '80'
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
- `WebAuthSessionFactory.swift` holds only the protocols. The AuthorizationPresenter task adds the default factory over `ASWebAuthenticationSession`.
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