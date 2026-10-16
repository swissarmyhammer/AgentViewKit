---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m53frfyqm4q0fxhqswxqcq3g
  text: |-
    Research done. ReportRecorder<Value> (Tests/AgentViewKitTests/Helpers/ReportRecorder.swift) is @MainActor @Observable, keeps `values`, and gives `report: ObservationReport<Value>`. ObservationReport and its callAsFunction are internal to AgentViewKit, so a file that calls `recorder.report(x)` must use `@testable import AgentViewKit`.

    Classes with the same shape (array of reported values and a record function), to replace:
    - PromptSubmitRecorder (Input/PromptInputViewHostedTests.swift).
    - SpeechPhaseRecorder (Input/SpeechInputButtonHostedTests.swift).
    - TurnAnnouncementStepRecorder (Accessibility/ThreadAccessibilityHostedTests.swift). It also has the computed values hasStarted and idleAnnouncements. These move to an extension of ReportRecorder where Value is TurnAnnouncementStep, in the same file.
    - ToolToggleRecorder (Input/ToolTogglesHostedTests.swift). The host closure has two arguments, so the test adapts them into one Call value.
    - ScrollRecorder (Infrastructure/ScrollAnchorManagerTests.swift). AgentCommandsTests already uses ReportRecorder<ScrollAnchorTarget> for the same closure.

    Classes that do not fit:
    - ReconnectRecorder (Connections/AgentAuthViewHostedTests.swift): it counts calls of an async host closure. It keeps no values.
    - HeightRecorder (Accessibility/DynamicTypeHostedTests.swift): it keeps only the last height, and it is not observable.
    - HostedEventLog (TestSupport/HostedViewHarnessTests.swift): it has no report function, and the file does not import AgentViewKit. The harness tests examine the test support module only.
    - CallLog (Diff/DiffViewHostedTests.swift): it keeps three lists of different types, and it has no report function.
    - OpenedSessions (ACP/DemoAgentTests.swift): it is not @Observable or @MainActor, and it has no report function.
    - CallCounter (Commands/AgentCommandsTests.swift): it keeps a count only.
    - OpenedURLRecorder (Helpers): it is nonisolated and Sendable with a lock, because the URL action can run off the main actor.
    - RecordingAnnouncer, RecordingFocusReporter, FakeSpeechTranscriber: they are in Sources/AgentViewKitTestSupport and conform to kit protocols. This card does not change Sources.
  timestamp: 2026-10-16T23:11:38.967306+00:00
- actor: claude-code
  id: 01m53g8dnfhz2xqg55y0fjmz2j
  text: |-
    Implementation landed (tests only, no change in Sources/).

    Replaced with ReportRecorder<Value>, and the copies are deleted:
    - PromptSubmitRecorder -> ReportRecorder<PromptSubmitOutcome>. mount gives `recorder?.report` to promptSubmitReport. The static report(to:) is deleted.
    - SpeechPhaseRecorder -> ReportRecorder<SpeechInputButton.Phase>. The static report(to:) is deleted.
    - TurnAnnouncementStepRecorder -> ReportRecorder<TurnAnnouncementStep>. hasStarted and idleAnnouncements are now in `extension ReportRecorder<TurnAnnouncementStep>` in the same file. The static report(to:) is deleted.
    - ToolToggleRecorder -> ReportRecorder<ToolTogglesHostedTests.Call>. The onToggle closure gives `Call(id:isEnabled:)` to `recorder.report`.
    - ScrollRecorder (ScrollAnchorManagerTests) -> ReportRecorder<ScrollAnchorTarget>.
    ToolTogglesHostedTests and ScrollAnchorManagerTests now use `@testable import AgentViewKit`, because ObservationReport and its callAsFunction are internal.

    Each assertion stays. Each `try #require` after a press or a key stays before the next wait (PromptInputViewHostedTests: `try #require(!recorder.values.isEmpty)` right after sendKey; SpeechInputButtonHostedTests: pressToRecord requires the Recording value). The recorder is still @MainActor @Observable, so each ObservationWait.until and harness.render(when:) gets the same change events as before. No wait was added.

    Note: the edit op of the files tool replaces only one match, also with replace_all. For the many renames in ScrollAnchorManagerTests, the file was written whole and the diff was checked.
  timestamp: 2026-10-16T23:20:20.911377+00:00
- actor: claude-code
  id: 01m53g8haqmv7v21g2znvwtbf0
  text: |-
    ### implement — changed
    - evidence: 5 files — Tests/AgentViewKitTests/Input/PromptInputViewHostedTests.swift, Tests/AgentViewKitTests/Input/SpeechInputButtonHostedTests.swift, Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift, Tests/AgentViewKitTests/Input/ToolTogglesHostedTests.swift, Tests/AgentViewKitTests/Infrastructure/ScrollAnchorManagerTests.swift. `swift build --build-tests`: complete, no warning in Sources/ or Tests/ (one SwiftPM note: missing creator for mutated node in mlx-swift_Cmlx.bundle). Affected suites (one run): 68 tests in 5 suites passed. Full `swift test --skip-build`: 1295 tests in 151 suites passed, 2 known issues (the withKnownIssue tests aWrappedTextWithAFixedVerticalSizeFails and aViewThatIgnoresTheThemeFails), XCTest 0 tests.
    - next: review
  timestamp: 2026-10-16T23:20:24.663876+00:00
- actor: claude-code
  id: 01m53g9kcmykkqxqddb5xeg1zh
  text: |-
    ### test — green
    - evidence: the implement step ran the full suite one time after the change: swift test --skip-build, 1295 tests in 151 suites passed, 2 known issues (the same as before). swift build --build-tests: no warning in Sources/ or Tests/. It was not run again (no repeat runs).
    - next: commit, review, push.
  timestamp: 2026-10-16T23:20:59.540071+00:00
position_column: doing
position_ordinal: '80'
title: Use the shared ReportRecorder for the per-file ObservationReport recorders
---
T4-A5 (^35sw345) added the shared generic test recorder ReportRecorder<Value> (Tests/AgentViewKitTests/Helpers/ReportRecorder.swift). Three older test recorders have the same shape, one class for each file: PromptSubmitRecorder (Input/PromptInputViewHostedTests.swift), SpeechPhaseRecorder (Input/SpeechInputButtonHostedTests.swift) and TurnAnnouncementStepRecorder (Accessibility/ThreadAccessibilityHostedTests.swift). Replace each one with ReportRecorder<Value>, and delete the copies. Keep each assertion. Run the affected suites one time. Write all text in STE. #mail-step-7