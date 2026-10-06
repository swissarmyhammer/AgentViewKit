---
assignees:
- claude-code
depends_on:
- 01M443PGJC9H955A0M1QSS6FR3
- 01M48MQ0BVDHNY798PTF3VYEQH
position_column: todo
position_ordinal: '9980'
title: Examine promptCapabilities before the composer sends image and embedded resource blocks
---
## What
At present, image blocks go out always, and embedded `resource` blocks never go out. Source: update.md §9.4 (first row). Owner rule (2026-10-06): the composer binds directly to the observable model of FoundationModelsACPClient. It reads the capabilities from `ConnectionModel` at the time of use, and keeps no copy of them.

- [ ] Read `promptCapabilities` from `ConnectionModel.agentCapabilities` directly, at the time of the content build and in the chip view. Do not store the capabilities in the composer, in `@State` or in a kit object.
- [ ] In the content build of the composer (`Sources/AgentViewKit/Input/ThreadActionTasks.swift` `promptBlocks(for:)` and the attachment chips), send an image block only when `promptCapabilities.image` is true. Send an attached file as an embedded `resource` block when `promptCapabilities.embeddedContext` is true; else send a `resource_link`. The content build is a pure function of the input and the capabilities.
- [ ] When the agent does not accept an attachment kind, show it as not accepted on its chip, and do not send it.

## Acceptance Criteria
- [ ] With `image: false` in the `initialize` answer, a pasted image is not sent and its chip shows the not-accepted state.
- [ ] With `embeddedContext: true`, an attached text file goes out as an embedded resource.
- [ ] With `embeddedContext: false`, it goes out as a resource link.
- [ ] A second connection with other capabilities changes the chip state with no other step (the view reads the model).

## Tests
- [ ] `Tests/AgentViewKitTests/Input/PromptCapabilitiesTests.swift`: the content build for each capability combination (pure function test).
- [ ] One hosted test in `Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift` that reads the sent frames of the scripted agent, and that the chip state follows `ConnectionModel.agentCapabilities`.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.