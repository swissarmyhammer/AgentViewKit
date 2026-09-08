---
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: todo
position_ordinal: af80
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

## Acceptance Criteria
- [ ] A test can mount `Text("hi")`, pump, and read one accessibility element with label "hi".
- [ ] `BodyEvaluationCounter` counts increment on re-evaluation and reset between tests.
- [ ] Each fake records calls in order.

## Tests
- [ ] `Tests/AgentViewKitTests/TestSupport/HostedViewHarnessTests.swift`: the mount and read case, a press, a key, the linked-elements read.
- [ ] `Tests/AgentViewKitTests/TestSupport/FakesTests.swift`: each fake.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.