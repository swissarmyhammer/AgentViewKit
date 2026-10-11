---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4ndy0h9ax08dt79w2mdpy45
  text: |-
    Implementation notes (2026-10-11).

    - Pins: I edited the git-ignored root `Package.resolved` (FoundationModelsACP `5f94484eaed1f47e1432b689b9bda8194ecb95a0`, FoundationModelsACPClient `24643be3817912251e93705443012013b6b6e177`) and ran `swift package resolve`. It worked with no workaround. I did not use `swift package update`. Then I copied the root file into `Examples/AgentViewKitDemo/AgentViewKitDemo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (the two files are equal). FoundationModelsACP `main` is now `7570149`, which adds only kanban records after `5f94484`, so I kept `5f94484`.
    - `resolve` does not remove the pins that 24643be no longer needs (for example Noora). The file is git-ignored, and `ResolvedPinsTests` passes.
    - Type renames: done in the six files on the card. No other `Unstable.` use is in the repository.
    - Other build error: alpha.8 adds the stop reason `error`. `StateBanner.message(forStopReason:)` had an exhaustive switch, so the kit did not compile. Fix (test first): `StateBanner` shows "The turn failed" (`StateBanner.failedTurnIdentifier` = `state-banner-error`). When the idle state has the new `error` object (`IdleStateUpdate.error`), the explanation shows its `message`. `ThreadAccessibility.turnAnnouncement` speaks the banner title for `error`. New tests: two in `StateBannerStopReasonTests`, plus `error` added to `ThreadAccessibilityTests` and to the hosted `SessionStateBannersHostedTests`.
    - Doc comments: "unstable ACP" changed to "stable ACP since schema alpha.8" in `CompactionEntryView`, `SessionNoticeBanner`, `AgentTheme` and two lines of `plan.md`.
    - Behavior changes: no effect on the kit. `InMemoryDemoACPAgent` uses `insertUserMessage(_:)` with no history closure (`7b3ee45`). The demo agent sends only valid updates (`dd8996e`). `ScriptedWireAgent` writes raw frames, so its frames do not go through the send rules. `SessionModel.cancel(meta:)` of the client already answers pending permissions before `session/cancel`, and `PendingPermissionRequests` lets the first answer win (`a8736dc`). `Docs/decisions/acp-version.md` has the full table.
    - Build warning: each build prints `warning: missing creator for mutated node: ('/Users/wballard/github/swissarmyhammer/AgentViewKit/.build/out/Products/Debug/mlx-swift_Cmlx.bundle/Contents/MacOS')`. It comes from the mlx-swift package (FoundationModelsACPClient -> FoundationModelsExtras -> mlx-swift-lm -> mlx-swift). FoundationModelsACPClient `74fc2df` had the same FoundationModelsExtras dependency. No kit source makes it.
  timestamp: 2026-10-11T12:10:20.585277+00:00
- actor: claude-code
  id: 01m4ndy7759sqj8skrm2yrt67d
  text: |-
    ### implement — changed
    - evidence: 15 tracked files plus the two git-ignored pin files. Pins: `Package.resolved` and `Examples/AgentViewKitDemo/AgentViewKitDemo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (FoundationModelsACP 5f94484, FoundationModelsACPClient 24643be). Sources: `Sources/AgentViewKit/Status/StateBanner.swift`, `Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift`, `Sources/AgentViewKit/Theme/AgentTheme.swift`, `Sources/AgentViewKit/Items/CompactionEntryView.swift`, `Sources/AgentViewKit/Status/SessionNoticeBanner.swift`. Tests: `StateBannerStopReasonTests.swift`, `ThreadAccessibilityTests.swift`, `SessionStateBannersHostedTests.swift`, `StatusColorsTests.swift`, `CompactionAndNoticeHostedTests.swift`, `TranscriptRowKeyTests.swift`. Docs: `Docs/decisions/acp-version.md`, `plan.md`. `swift build --build-tests`: Build complete. Full `swift test` (run after the last change): 1042 tests in 110 suites passed, 89 tests in 9 suites passed, 1 test in 1 suite passed, XCTest 0 tests; exit 0. Load average during the run: 22.79 before, 19.81 after. One build warning from the mlx-swift package: `warning: missing creator for mutated node: ('/Users/wballard/github/swissarmyhammer/AgentViewKit/.build/out/Products/Debug/mlx-swift_Cmlx.bundle/Contents/MacOS')`. Subtasks 6 of 6 checked.
    - next: /review. The task stays in doing. Not committed. After the commit, check the third subtask of ^06hz99g.
  timestamp: 2026-10-11T12:10:27.429276+00:00
position_column: doing
position_ordinal: '8280'
title: Move AgentViewKit to FoundationModelsACP 5f94484 (ACP schema alpha.8) and FoundationModelsACPClient 24643be
---
## What
The EventBroadcaster deadlock fix of ^06hz99g is in FoundationModelsACP `main` at `5f94484`. AgentViewKit cannot use that revision with a pin change only. This task does the migration.

Facts found on 2026-10-11 (^06hz99g):
- Pins today (git-ignored `Package.resolved`): FoundationModelsACP `b2cec56`, FoundationModelsACPClient `74fc2df`. `Package.swift` pins both packages with `branch: "main"`. FoundationModelsACPClient also pins FoundationModelsACP with `branch: "main"`, with no revision. FoundationModelsACPAgent is not in the graph.
- `b2cec56..5f94484` has 19 commits. `dc336cb` re-vendors the schema to `schema-v2.0.0-alpha.8`. It moves `Unstable.CompactionStatus`, `Unstable.NoticeSeverity`, `Unstable.CompactionId` and `Unstable.SessionUpdate` out of `Unstable`. Other commits change behavior: `7b3ee45` (breaking: record the user message in history only after success), `dd8996e` (refuse invalid session updates before they are sent), `a8736dc` (answer pending permission requests on session cancel), `1cc2dd5` (`promptWithEcho`).
- FoundationModelsACPClient `74fc2df` does not compile with FoundationModelsACP `5f94484` (`'CompactionStatus' is not a member type of enum 'FoundationModelsACP.Unstable'` in `CompactionEntry.swift`).
- FoundationModelsACPClient `main` is `24643be` ("refactor!: make the package a client library only and move to stable ACP types"). It removes the `AcpClientCore` library and the `acp-client` executable. In the `FoundationModelsACPClient` library it changes only the `Unstable.` type names. It compiles with `5f94484`.
- With both new revisions, AgentViewKit stops at `Sources/AgentViewKit/Theme/AgentTheme.swift`: `'CompactionStatus' is not a member type of enum 'FoundationModelsACP.Unstable'` and the same for `NoticeSeverity`.

## Work
- [x] Set the pins to FoundationModelsACP `5f94484` (or later) and FoundationModelsACPClient `24643be` (or later). Copy the root `Package.resolved` into the generated demo project (`Examples/Scripts/xcodeproj_generator.rb` does this), so that `ResolvedPinsTests` stays green.
- [x] Change each `Unstable.CompactionStatus`, `Unstable.NoticeSeverity` and `Unstable.CompactionId` to the type without `Unstable.`: `Sources/AgentViewKit/Theme/AgentTheme.swift`, `Sources/AgentViewKit/Items/CompactionEntryView.swift`, `Sources/AgentViewKit/Status/SessionNoticeBanner.swift`, `Tests/AgentViewKitTests/Theme/StatusColorsTests.swift`, `Tests/AgentViewKitTests/Items/CompactionAndNoticeHostedTests.swift`, `Tests/AgentViewKitTests/Thread/TranscriptRowKeyTests.swift`.
- [x] Fix each other build error that the new revisions cause in the kit, `DemoSupport`, the test support and the tests.
- [x] Check the scripted demo agents and the tests against the behavior changes of `7b3ee45`, `dd8996e` and `a8736dc`.
- [x] Update `Docs/decisions/acp-version.md`: the schema pin (`schema-v2.0.0-alpha.8`, FoundationModelsACP `5f94484`), and a section with the alpha.7 to alpha.8 wire changes and their effect on the kit.
- [x] Build, and run the full suite.