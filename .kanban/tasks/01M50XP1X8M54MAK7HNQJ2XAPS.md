---
assignees:
- claude-code
position_column: todo
position_ordinal: '9080'
title: Use the shared ReportRecorder for the per-file ObservationReport recorders
---
T4-A5 (^35sw345) added the shared generic test recorder ReportRecorder<Value> (Tests/AgentViewKitTests/Helpers/ReportRecorder.swift). Three older test recorders have the same shape, one class for each file: PromptSubmitRecorder (Input/PromptInputViewHostedTests.swift), SpeechPhaseRecorder (Input/SpeechInputButtonHostedTests.swift) and TurnAnnouncementStepRecorder (Accessibility/ThreadAccessibilityHostedTests.swift). Replace each one with ReportRecorder<Value>, and delete the copies. Keep each assertion. Run the affected suites one time. Write all text in STE. #mail-step-7