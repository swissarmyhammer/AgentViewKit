---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21AF2MV082PZY3Q6H0M4YCM
position_column: todo
position_ordinal: a080
title: 'AgentCommands: the kit verbs as EditorKit commands with a default keymap (plan §4.1, §11#14)'
---
## What
Create `Sources/AgentViewKit/Commands/AgentCommands.swift` and `AgentKeymap.swift`, per plan.md §4.1 and decision 14.

- Commands, each an EditorKit `Command` with a `CommandID`, title, and eligibility: `send`, `cancel`, `approvePending`, `rejectPending`, `jumpToNext`, `jumpToPrevious`, `copyThread`, `toggleExpandAll`, `scrollToBottom`, `focusComposer`.
- `AgentCommandScope`: a focus scope for `AgentThreadView` that registers the commands in the ambient `CommandSystem` and resolves eligibility from `thread.state` and the pending lists.
- `AgentKeymap`: a `Keymap` with defaults (Command-Return send, Escape cancel, Command-Shift-C copy thread, Option-Up and Option-Down jump).
- The composer and the pending cards invoke the same commands, so the palette and the keybindings editor see them.

## Acceptance Criteria
- [ ] With the scope mounted, `CommandRegistry` lists the ten commands.
- [ ] `cancel` is ineligible when `thread.state == .idle` and eligible when running.
- [ ] Dispatching `send` calls `AgentThreadActions.send`.

## Tests
- [ ] `Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift`: registration, eligibility, dispatch through EditorKit's `CommandSystemHarness` from `EditorCommandsTestSupport`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.