---
assignees:
- claude-code
depends_on:
- 01M443PGJC9H955A0M1QSS6FR3
position_column: todo
position_ordinal: '9880'
title: 'Bind slash commands and config options to SessionModel: commands "not reported" and empty, setConfigOption'
---
## What
Source: update.md §4.2 (last-value state), §4.4 ("Commands not reported"), §5 (`availableCommands` in the new and resume responses).

- [ ] `SlashCommandSource` (`Sources/AgentViewKit/Input/SlashCommandSource.swift`) reads `SessionModel.availableCommands` (ACP `AvailableCommand`). `nil` means "not reported": show no command menu. `[]` means "no commands": show an empty menu with a short note. Remove the kit `SlashCommand` use here.
- [ ] `ConfigOptionsView` and `PermissionModePicker` (`Sources/AgentViewKit/Config/`) read `SessionModel.configOptions` (ACP types) and send with `SessionModel.setConfigOption(_:)`. Remove the kit `ConfigOption` use here.
- [ ] Hide the config controls when `configOptions` is empty or nil.

## Acceptance Criteria
- [ ] With commands not reported, the composer shows no command menu.
- [ ] After an `available_commands_update` with `[]`, the menu shows the "no commands" note.
- [ ] Commands from the `session/new` response show without an update.
- [ ] A change in the config picker sends `session/set_config_option` and the view shows the new value from the model.

## Tests
- [ ] `Tests/AgentViewKitTests/Input/SlashCommandSessionModelTests.swift`: the three command states.
- [ ] `Tests/AgentViewKitTests/Config/ConfigOptionsSessionModelHostedTests.swift`: the picker round trip with the scripted agent.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.