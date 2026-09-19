---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m2x218xmd6bfh5n3dgjpkwzh
  text: |
    ### finish iteration 1 — done

    - implement: `AgentThreadView(thread:actions:)` takes the actions and sets them as the outermost environment value of its body, so the agent command scope and each card read them. `EnvironmentValues.threadActions` is now `(any AgentThreadActions)?` with the default `nil`. `LoggingThreadActions` stays public; its doc says that a host selects it, and `AgentTranscriptView` takes it as the default of a new `actions:` parameter. `AgentCommandTarget.actions` and `AgentCommandMount.Scope.actions` are optional. Each reader (PromptInputView, PromptQueueView, DefaultPromptAccessory, PermissionView, ElicitationView, ElicitationURLConsentView, AuthorizationView, AgentAuthView, BranchNavigator, MessageActions, ConfigOptionControl, PermissionModePicker, AgentCommandScope) handles the `nil` case. New decision: `Docs/decisions/required-thread-actions.md`.
    - test: `timeout 1500 swift test` passed. AgentViewKitTests 1284, AgentViewKitACPTests 102, AgentViewKitRouterTests 74, PackageStructureTests 23, AgentViewKitFoundationModelsTests 48. Only the accepted mlx-swift warning. The new test is `AgentThreadViewHostedTests.theActionsOfTheInitializerReachTheCardsOfTheThread`: it mounts the thread view with no `threadActions` in the environment and shows that a press on the Allow button of a pending permission card answers through the actions of the initializer.
    - commit: `ac51d6b feat(thread)!: require the thread actions in AgentThreadView (^33tg6p6)`.
    - review: `review sha HEAD~1..HEAD` gave 0 findings over 32 files and 21 validator runs.

    ### Review Findings (2026-09-19)

    - [x] No finding. The review is clean.

    Note: the package has no `#Preview` block, so the preview part of the acceptance criteria has no work.
  timestamp: 2026-09-19T14:44:56.372517+00:00
position_column: done
position_ordinal: cb80
title: Make the thread actions required, and remove the LoggingThreadActions default
---
Today a host that gives no actions gets `LoggingThreadActions`: a send or a cancel only writes a log line, and nothing happens. This is a quiet failure. The user decided that a host must give the actions.

## Acceptance criteria
- [x] `AgentThreadView` takes the actions in its initializer. A host cannot forget them.
- [x] The environment default is no longer `LoggingThreadActions`. Keep `LoggingThreadActions` as a public type, because a host can still choose it.
- [x] Each view that reads the actions from the environment gets them from the thread view, not from a silent default.
- [x] Each preview, test and fixture in the package gives the actions. The test support helpers (for example `threadViewHarness`) keep their short form. (The package has no `#Preview` block.)
- [x] `Docs/decisions/` records the change and the reason: a quiet failure is worse than a compile error.

## Tests
- [x] All tests pass, and no test count goes down.
- [x] A test shows that the actions of the initializer arrive at a child view (for example PromptInputView).

## Notes
This is a breaking change for the hosts that exist. Write the change in the commit message.
