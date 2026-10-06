---
assignees:
- claude-code
depends_on:
- 01M443PGJC9H955A0M1QSS6FR3
- 01M48MQ0BVDHNY798PTF3VYEQH
position_column: todo
position_ordinal: '9880'
title: 'Bind slash commands and config options to SessionModel: commands "not reported" and empty, setConfigOption'
---
## What
Source: update.md §4.2 (last-value state), §4.4 ("Commands not reported"), §5 (`availableCommands` in the new and resume responses). Owner rule (2026-10-06): the views bind directly to the observable model of FoundationModelsACPClient. They show what `SessionModel` holds and call its methods. The kit keeps no copy of the commands or of the config options, and no selected value of its own.

- [ ] `SlashCommandSource` (`Sources/AgentViewKit/Input/SlashCommandSource.swift`) reads `SessionModel.availableCommands` (ACP `AvailableCommand`) directly. `nil` means "not reported": show no command menu. `[]` means "no commands": show an empty menu with a short note. Remove the kit `SlashCommand` use here.
- [ ] `PromptInputView` (`Sources/AgentViewKit/Input/PromptInputView.swift`) gives `SessionModel.availableCommands` to the editor context. At present it reads `turn.thread?.availableCommands`, so a composer over a `SessionModel` gets no commands.
- [ ] `ConfigOptionsView` and `PermissionModePicker` (`Sources/AgentViewKit/Config/`) read `SessionModel.configOptions` (ACP `SessionConfigOption`) directly and call `SessionModel.setConfigOption(_:)`. The picker shows the current value from the model only; it keeps no local copy of the selected value. A failed call adds an error entry with `appendError(reporting:)`, and the picker keeps the value of the model. Remove the kit `ConfigOption` use and the `threadActions` use here.
- [ ] Hide the config controls when `configOptions` is empty or nil.

## Acceptance Criteria
- [ ] With commands not reported, the composer shows no command menu.
- [ ] After an `available_commands_update` with `[]`, the menu shows the "no commands" note.
- [ ] Commands from the `session/new` response show without an update.
- [ ] A change in the config picker calls `setConfigOption(_:)` and sends `session/set_config_option`. The picker then shows the value that the model reports.
- [ ] A `config_option_update` from the agent changes the shown value with no user step.

## Tests
- [ ] `Tests/AgentViewKitTests/Input/SlashCommandSessionModelTests.swift`: the three command states, each set by the scripted agent through the model.
- [ ] `Tests/AgentViewKitTests/Config/ConfigOptionsSessionModelHostedTests.swift`: the picker round trip with the scripted agent (assert the frame); an agent `config_option_update` changes the shown value; a failed call keeps the model value and adds an error row.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.