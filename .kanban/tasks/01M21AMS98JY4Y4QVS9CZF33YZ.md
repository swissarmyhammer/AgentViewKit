---
comments:
- actor: claude-code
  id: 01m2psscqjaappj5pgkrm8aay3
  text: |-
    ### finish iteration 1 — findings
    - implement: added AgentCommandVerb, AgentCommand, AgentCommandTarget, AgentCommandScope (`.agentCommandScope(thread:)`), AgentKeymap. AgentThreadView applies the scope. PromptInputView and PermissionView run the send, cancel, approve, and reject commands.
    - test: `swift test` passed. AgentViewKitTests 1033, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 44. No new warnings.
    - commit: 2e442c0
    - review: 1 finding (`code-hygiene/magic-numbers-swift` at AgentCommandTarget.swift:75).
  timestamp: 2026-09-17T04:25:22.930716+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21AF2MV082PZY3Q6H0M4YCM
position_column: doing
position_ordinal: '8180'
title: 'AgentCommands: the kit verbs as EditorKit commands with a default keymap (plan §4.1, §11#14)'
---
## What
Create `Sources/AgentViewKit/Commands/AgentCommands.swift` and `AgentKeymap.swift`, per plan.md §4.1 and decision 14.

- Commands, each an EditorKit `Command` with a `CommandID`, title, and eligibility: `send`, `cancel`, `approvePending`, `rejectPending`, `jumpToNext`, `jumpToPrevious`, `copyThread`, `toggleExpandAll`, `scrollToBottom`, `focusComposer`.
- `AgentCommandScope`: a focus scope for `AgentThreadView` that registers the commands in the ambient `CommandSystem` and resolves eligibility from `thread.state` and the pending lists.
- `AgentKeymap`: a `Keymap` with defaults (Command-Return send, Escape cancel, Command-Shift-C copy thread, Option-Up and Option-Down jump).
- The composer and the pending cards invoke the same commands, so the palette and the keybindings editor see them.

## Acceptance Criteria
- [x] With the scope mounted, `CommandRegistry` lists the ten commands.
- [x] `cancel` is ineligible when `thread.state == .idle` and eligible when running.
- [x] Dispatching `send` calls `AgentThreadActions.send`.

## Tests
- [x] `Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift`: registration, eligibility, dispatch through EditorKit's `CommandSystemHarness` from `EditorCommandsTestSupport`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 23:20)

- [ ] `Sources/AgentViewKit/Commands/AgentCommandTarget.swift:75` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.