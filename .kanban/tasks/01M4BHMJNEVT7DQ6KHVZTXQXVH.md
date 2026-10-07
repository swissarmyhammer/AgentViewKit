---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4bjgfd77j132ydqxsw17ghw
  text: |-
    Research and work notes:
    - RED: ResolvedPinsTests failed with 4 issues (root and Benchmarks pins at fe0d82d and be7e615) before the pin move.
    - Pin move: `swift package update FoundationModelsACPClient FoundationModelsACP` in the root and in Benchmarks/. Only these two pins moved. FoundationModelsExtras stays at 130eb40: the kit builds with it, so the client does not need a newer FoundationModelsExtras. The demo pin file came from `ruby Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb` (a copy of the root file). No folder-removal error, so no SIGSTOP was necessary.
    - The kit has no exhaustive switch over AuthState or ConnectionModelError (the compiler found none), so the new cases `.reconnectRequired` and `ConnectionModelError.terminalAuthFailed` need no compile change.
    - async selectPermission/cancelPermission: view callbacks are synchronous, so SessionModel gets `startSelectPermission(_:option:)` and `startCancelPermission(_:)` (main-actor tasks, the same pattern as startPrompt). answerPermission keeps the old order (select task, then prompt task). ^b3a2m6a does the awaited order.
    - AgentAuthView.loginRefusal reads `.failed(AuthFailure)` only for operation `.login` with reason `.request`, so the view shows the same text as before.
    - Discovery: `ConnectionModel.disconnect()` does not close the transport. For InMemoryTransport, the agent side does not see the end of its input, so the agent stays alive. AgentProcess ends on the end of its bytes stream. Thus InProcessAgent now wraps the client end in `InProcessClientTransport`: when the client stops the read, it closes the client end, and the agent side stops. New test `InProcessAgentTests.aDisconnectOfTheModelClosesTheAgentSide` failed (5 s time limit) before this change and passes after it.
    - DemoAgent.stop now calls only `connection.disconnect()`. The in-process runner no longer needs AgentConnectionBox; the box stays for the agent-side close test and has `waitUntilClosed()`.
    - BackgroundRunsHostedTests found a tool call by title; it now finds it by `ToolCallEntry.toolCallId`.
  timestamp: 2026-10-07T16:17:55.623094+00:00
- actor: claude-code
  id: 01m4bk4ka5axsb9ze8219epb8q
  text: |-
    ### implement — changed
    - evidence: packages moved: FoundationModelsACPClient be7e615 -> 36f3249, FoundationModelsACP fe0d82d -> 163f7eb (root Package.resolved, Benchmarks/Package.resolved, generated demo Package.resolved). No other package moved; FoundationModelsExtras stays at 130eb40. Commands: `swift package update FoundationModelsACPClient FoundationModelsACP` (root and Benchmarks/), `ruby Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb`, `swift test` (1303 tests in 125 suites + 83 tests in 12 suites pass; only warning is the mlx-swift "missing creator for mutated node"), `Scripts/check-readme.sh` (pass), `Scripts/test-examples.sh AgentViewKitDemo` (BUILD SUCCEEDED, TEST SUCCEEDED, 4 tests). Files: Package.resolved, Benchmarks/Package.resolved, README.md, Sources/AgentViewKit/ACP/InProcessAgent.swift, Sources/AgentViewKit/Connections/AgentAuthView.swift, Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift, Sources/AgentViewKit/Input/ThreadActionTasks.swift, Sources/DemoSupport/AgentConnectionBox.swift, Sources/DemoSupport/DemoAgent.swift, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift, Tests/PackageStructureTests/ResolvedPinsTests.swift, Tests/AgentViewKitTests/ACP/InProcessAgentTests.swift, Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift, Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift, Tests/AgentViewKitTests/Connections/ConnectionModelViewsHostedTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift, Tests/AgentViewKitTests/Thread/BackgroundRunsHostedTests.swift.
    - extra: client 8c12a70 changed `canLogout` to "the agent lists an auth method of any type". AgentAuthViewHostedTests.signOutIsHiddenWhenTheAgentCannotLogOut now uses an agent with no auth method.
    - next: /review
  timestamp: 2026-10-07T16:28:54.981732+00:00
position_column: doing
position_ordinal: '80'
title: Move the pins to FoundationModelsACPClient 36f3249 and FoundationModelsACP 163f7eb, and adopt the breaking client API
---
## What
FoundationModelsACPClient remote `main` is now `36f3249`. This commit has the client tasks 73c1nkk, k8skz98, d8d4384, a97eq56, x6p3vh0, 65k5p79, nzdk3m5, qjgmscm, fxa80af, s57dn8h, qcdqcm3, 3p0m0c1, cgznw8q and 9caa4y2. After qcdqcm3, FoundationModelsACP resolves at `163f7eb`. FoundationModelsACP remote `main` is `163f7eb`.

This task moves the two pins and makes the kit compile with the breaking client API. This task does not do the feature work. The tasks ^s3zygvh, ^b3a2m6a, ^83200vg, ^0vyzmm0 and ^20j25qh do the feature work, and they start after this task.

Client API changes for the kit:
- Breaking: `selectPermission` and `cancelPermission` are `async`.
- Breaking: `AuthState.failed` holds an `AuthFailure` value.
- New `AuthState` cases: `.reconnectRequired` and `.required`.
- New: `canLogin`, `canUseAdditionalDirectories`, `disconnect()`, `toolCallEntry(for:)`, `ToolCallEntry.toolCallId`, `SessionModel.cwd`, `SessionModel.additionalDirectories`, and `SessionModel.mcpServers` with `MCPServerItem`.
- New: `loginWithTerminal(_:runner:)` with `TerminalAuthRunner`.
- Changed: `SessionModel.cancel` answers the pending permissions with `cancelled`.

Subtasks:
- [x] Update `Tests/PackageStructureTests/ResolvedPinsTests.swift` to the new revisions: FoundationModelsACPClient `36f3249` and FoundationModelsACP `163f7eb`. The test must fail before the pin move.
- [x] Move the two pins in the three `Package.resolved` files: the root file, the file in `Benchmarks/`, and the file of the demo Xcode project when the project is generated. Update only these two packages. Do not use a plain `swift package update`, because it moves all pins.
- [x] Add `await` at each call of `selectPermission` and `cancelPermission` in `Sources/` and `Tests/`. Make no other change of behavior at these calls. Task ^b3a2m6a does the frame order and the comment prompt order.
- [x] Change the kit code that reads `AuthState.failed` so that it compiles with `AuthState.failed(AuthFailure)`. Task ^83200vg does the failure views.
- [x] In the tests that find a tool call by its title, find the tool call by `ToolCallEntry.toolCallId`.
- [x] In the in-process helper and in the demo stop, where they now close the connection from the agent side, call `ConnectionModel.disconnect()`.

Note: the `sah serve` process runs sourcekit-lsp. sourcekit-lsp writes index data into `.build/checkouts/*/.build`. If SwiftPM cannot remove these folders, halt that process with SIGSTOP only during `swift package resolve`. Then send SIGCONT to that process.

## Acceptance Criteria
- [x] The three `Package.resolved` files pin FoundationModelsACPClient `36f3249` and FoundationModelsACP `163f7eb`.
- [x] `ResolvedPinsTests` passes.
- [x] `swift test`, `Scripts/check-readme.sh` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Tests
- [x] `Tests/PackageStructureTests/ResolvedPinsTests.swift`: checks the new revisions.
- [x] The existing suites pass with the new pins.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.