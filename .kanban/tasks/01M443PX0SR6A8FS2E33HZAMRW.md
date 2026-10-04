---
assignees:
- claude-code
depends_on:
- 01M443PGJC9H955A0M1QSS6FR3
position_column: todo
position_ordinal: '9980'
title: Examine promptCapabilities before the composer sends image and embedded resource blocks
---
## What
At present, image blocks go out always, and embedded `resource` blocks never go out. Source: update.md §9.4 (first row).

- [ ] Read `promptCapabilities` from `ConnectionModel.agentCapabilities`.
- [ ] In the content build of the composer (`Sources/AgentViewKit/Input/` and the attachment chips), send an image block only when `promptCapabilities.image` is true. Send an attached file as an embedded `resource` block when `promptCapabilities.embeddedContext` is true; else send a `resource_link`.
- [ ] When the agent does not accept an attachment kind, show it as not accepted on its chip, and do not send it.

## Acceptance Criteria
- [ ] With `image: false`, a pasted image is not sent and its chip shows the not-accepted state.
- [ ] With `embeddedContext: true`, an attached text file goes out as an embedded resource.
- [ ] With `embeddedContext: false`, it goes out as a resource link.

## Tests
- [ ] `Tests/AgentViewKitTests/Input/PromptCapabilitiesTests.swift`: the content build for each capability combination (pure function test).
- [ ] One hosted test that reads the sent frames of the scripted agent.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.