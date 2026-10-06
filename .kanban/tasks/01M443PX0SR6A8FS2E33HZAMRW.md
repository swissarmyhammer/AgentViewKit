---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4966h2zjxj5zbt9jhz7d37k
  text: |-
    Research (implement step):
    - In ACP v2 (FoundationModelsACP fe0d82d) the prompt capabilities are at `ConnectionModel.agentCapabilities?.session?.prompt` (`SessionCapabilities.prompt: PromptCapabilities?`). `image` and `embeddedContext` are marker objects, not Bool: a value that is not nil means "true". An absent `prompt` means only text and `resource_link`.
    - `EmbeddedResource.resource` is `EmbeddedResourceResource`, which is a typealias of `FoundationModelsACP.JSONValue`. The kit must write the `uri`, `mimeType` and `text` or `blob` keys itself.
    - The environment has `\.sessionModel` but no connection model entry. The plan adds `@Entry public var connectionModel: ConnectionModel?`. `EnvironmentComposerTurn` and `AttachmentChips` read it, and read the capabilities at the time of use.
    - Callers of `SessionModel.sendPrompt(with:)`: `ComposerTurn.startPrompt`, `ACPThreadActions.send` (it has its own connection model), and `SessionModel.reply(to:_:)` (a text comment only, so no attachment).
    - `ACPThreadActionsTests.sendSendsAPromptWithTextImageAndResourceLinkBlocks` expects an image block. Its scripted agent advertises no `prompt.image`, so that test must advertise `image` after this change.
    - `ScriptedSession.open(configure:)` runs `configure` after it sets the `initialize` result, so a test can give other capabilities.
  timestamp: 2026-10-06T18:04:17.887317+00:00
- actor: claude-code
  id: 01m496y302rn9j7zmz9zskgq17
  text: |-
    Implementation landed (TDD: RED was a compile failure on the missing `PromptContent`, `connectionModel` and `notAcceptedIdentifier`; GREEN after the change).
    - New `Sources/AgentViewKit/Input/PromptContent.swift`: `PromptContent.makeBlocks(for:accepting:)` (the content build, no state) and `PromptContent.isAccepted(attachmentAt:by:)` (the chip and the build use the same rule). An image goes out only with `image`; else it is not accepted and does not go out. With `embeddedContext`, a readable file goes out as an embedded `resource` (UTF-8 text file: `text`; other file: base64 `blob`); else a `resource_link`. A file that cannot be read goes out as a `resource_link`. The internal `ConnectionModel.promptCapabilities` reads `agentCapabilities?.session?.prompt` at each call (no copy).
    - New environment entry `\.connectionModel` (`SessionTranscriptEnvironment.swift`). `EnvironmentComposerTurn` and `AttachmentChips` read it. `ComposerTurn.startPrompt` reads the capabilities at submit time. `AttachmentChips` reads them in `body` and shows the "not accepted" mark (`notAcceptedIdentifier(for:)`).
    - `SessionModel.sendPrompt(with:accepting:)` replaces `sendPrompt(with:)`; the old `promptBlocks(for:)` and `attachmentBlock(for:)` are removed. Callers: `ComposerTurn`, `ACPThreadActions.send` (reads its own connection model), `SessionModel.reply(to:_:)` (comment text only, passes `nil`).
    - Decision: with no connection model in the environment, the composer reads no capability (ACP: an absent capability means "not supported"), so an image chip shows the mark and no image goes out. The demo now sets `.environment(\.connectionModel, session.connectionModel)` in `ACPTabView.boundThread`. README has no composer, so it did not change.
    - Test changes: `ACPThreadActionsTests` initialize result now advertises `prompt.image` (the image block needs it). `ScriptedSession.makeInitializeResult(promptCapabilities:)` added. `AttachmentChipsTestModel` and `AttachmentComposerHost` are now internal so the composer hosted tests reuse them.
    - Gates: `swift test` 1313 tests + 77 tests pass (only the expected mlx-swift warning); `Scripts/test-examples.sh AgentViewKitDemo` passed.
  timestamp: 2026-10-06T18:17:09.890144+00:00
- actor: claude-code
  id: 01m496y5enr3mbp5pnqdntg2zb
  text: |-
    ### implement — changed
    - evidence: new Sources/AgentViewKit/Input/PromptContent.swift, Tests/AgentViewKitTests/Input/PromptCapabilitiesTests.swift; changed ThreadActionTasks.swift, AttachmentChips.swift, PromptInputView.swift, SessionTranscriptEnvironment.swift, ACPThreadActions.swift, PendingRequestReplies.swift, ScriptedSession.swift, ComposerSessionModelHostedTests.swift, AttachmentChipsHostedTests.swift, ACPThreadActionsTests.swift, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift. `swift test` green (1313 + 77 tests), `Scripts/test-examples.sh AgentViewKitDemo` passed.
    - next: /review
  timestamp: 2026-10-06T18:17:12.405699+00:00
depends_on:
- 01M443PGJC9H955A0M1QSS6FR3
- 01M48MQ0BVDHNY798PTF3VYEQH
position_column: doing
position_ordinal: '80'
title: Examine promptCapabilities before the composer sends image and embedded resource blocks
---
## What
At present, image blocks go out always, and embedded `resource` blocks never go out. Source: update.md §9.4 (first row). Owner rule (2026-10-06): the composer binds directly to the observable model of FoundationModelsACPClient. It reads the capabilities from `ConnectionModel` at the time of use, and keeps no copy of them.

- [x] Read `promptCapabilities` from `ConnectionModel.agentCapabilities` directly, at the time of the content build and in the chip view. Do not store the capabilities in the composer, in `@State` or in a kit object.
- [x] In the content build of the composer (`Sources/AgentViewKit/Input/ThreadActionTasks.swift` `promptBlocks(for:)` and the attachment chips), send an image block only when `promptCapabilities.image` is true. Send an attached file as an embedded `resource` block when `promptCapabilities.embeddedContext` is true; else send a `resource_link`. The content build is a pure function of the input and the capabilities.
- [x] When the agent does not accept an attachment kind, show it as not accepted on its chip, and do not send it.

## Acceptance Criteria
- [x] With `image: false` in the `initialize` answer, a pasted image is not sent and its chip shows the not-accepted state.
- [x] With `embeddedContext: true`, an attached text file goes out as an embedded resource.
- [x] With `embeddedContext: false`, it goes out as a resource link.
- [x] A second connection with other capabilities changes the chip state with no other step (the view reads the model).

## Tests
- [x] `Tests/AgentViewKitTests/Input/PromptCapabilitiesTests.swift`: the content build for each capability combination (pure function test).
- [x] One hosted test in `Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift` that reads the sent frames of the scripted agent, and that the chip state follows `ConnectionModel.agentCapabilities`.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.