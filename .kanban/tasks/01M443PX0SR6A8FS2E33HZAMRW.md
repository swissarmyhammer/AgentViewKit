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
- actor: claude-code
  id: 01m497bwvd2s16vtsd82ymg337
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — PromptContent (new) builds the prompt from ConnectionModel promptCapabilities at the time of use; \.connectionModel environment entry; not-accepted chip mark; 13 files
    - test: green — swift test, 1313 passed; demo UI gate passed
    - commit: ecd1999
    - review: findings — Tests/AgentViewKitTests/Input/PromptCapabilitiesTests.swift:11, Tests/AgentViewKitTests/Input/PromptCapabilitiesTests.swift:17
  timestamp: 2026-10-06T18:24:42.349991+00:00
- actor: claude-code
  id: 01m497bz3fa6hjdm02qt56exbc
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (ecd1999), 2 findings — Tests/AgentViewKitTests/Input/PromptCapabilitiesTests.swift:11 `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.; Tests/AgentViewKitTests/Input/PromptCapabilitiesTests.swift:17 `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
    - next: /implement — replace the magic numbers in PromptCapabilitiesTests.swift with named constants in the full file, then /review again.
  timestamp: 2026-10-06T18:24:44.655624+00:00
- actor: claude-code
  id: 01m497m29wt5r3n784fbq4dps7
  text: |-
    Review findings fixed (magic numbers in PromptCapabilitiesTests.swift).
    - RED: swiftlint 0.65.1 `no_magic_numbers` with `allowed_numbers: [0, 1, -1, 100]` (the rule config) reported 9 literals in the two `Data([...])` array literals.
    - Fix: `AttachedFiles` now has named `static let` constants with doc comments: `pngSignatureFirstByte` (0x89), `pngSignatureLetters` ("PNG"), `zipHeaderLetters` ("PK"), `zipHeaderThirdByte` (0x03), `zipHeaderFourthByte` (0x04), `notUTF8Byte` (0xFF). `imageBytes` and `archiveBytes` are built from them. The bytes are the same as before.
    - Discovery: swiftlint does not report a literal that is the direct value of a `static let`, but it reports each literal inside an array literal argument, also in a `static let`. A string `.utf8` view gives the ASCII bytes with no number literal.
    - Note: `Tests/AgentViewKitTests/ACP/ACPThreadActionsTests.swift` has the same `Data([0x89, 0x50, 0x4E, 0x47])` line, but that file is not in this task scope and is not part of the findings, so it did not change.
    - Gates: swiftlint on the file reports 0 findings; `swift test --filter PromptCapabilitiesTests` 8 tests pass; `swift test` 1313 tests in 121 suites pass, 0 failures (only the known mlx-swift build warning).
  timestamp: 2026-10-06T18:29:10.076826+00:00
- actor: claude-code
  id: 01m497m3z2nkw6ky8hgvdfv6ys
  text: |-
    ### implement — changed
    - evidence: 1 file — Tests/AgentViewKitTests/Input/PromptCapabilitiesTests.swift. swiftlint no_magic_numbers 0 findings; `swift test --filter PromptCapabilitiesTests` 8 passed; `swift test` 1313 passed, 0 failed. Both review findings set to [x].
    - next: /review
  timestamp: 2026-10-06T18:29:11.778215+00:00
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

## Review Findings (2026-10-06 13:20)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 13 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Tests/AgentViewKitTests/Input/PromptCapabilitiesTests.swift:11` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitTests/Input/PromptCapabilitiesTests.swift:17` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
