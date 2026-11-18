---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: Build the AgentCommand definition through the shared AgentCommandPresentation helper
---
Origin: review finding of ^xf6j8gk (duplication, SideCardCommands.swift). That task added `AgentCommandPresentation` and `CommandDefinition.init(_:target:isVisible:make:)` in Sources/AgentViewKit/Commands/AgentCommandPresentation.swift. `SideCardCommand.definition(of:for:)` and `AgentAttachmentCommand.definition(of:for:)` now use the helper. The finding said not to edit AgentCommands.swift in that task.

Do:
- Add `var presentation: AgentCommandPresentation` to `AgentCommandVerb`, with the key `AgentKeymap.defaultChords[verb]?.first`.
- Make `AgentCommand.definition(of:for:)` in Sources/AgentViewKit/Commands/AgentCommands.swift call `CommandDefinition(verb.presentation, target: target, isVisible: { verb.isVisible(in: $0) }) { target, payload in AgentCommand(verb: verb, target: target, payload: payload) }`.
- Remove the copy of the keys dictionary, the id, title, icon, menu and context menu wiring, and the weak-target make closure.

Tests: the existing AgentCommandsTests (`theDefinitionsCarryTheDefaultKeys` and the others) stay green. Run only `swift test` at the package root.