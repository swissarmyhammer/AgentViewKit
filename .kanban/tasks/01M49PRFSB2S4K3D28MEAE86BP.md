---
assignees:
- claude-code
depends_on:
- 01M48MQS1Q5HBNDFMBD2CT0C6C
position_column: todo
position_ordinal: b880
title: Key the content block registry on the ACP ContentBlock
---
## What
`ContentBlockRegistry` (`Sources/AgentViewKit/Thread/Registries.swift`) is `KeyedViewRegistry<ContentBlock.Kind, ContentBlock>` of the kit `ContentBlock`. Since ^2ct0c6c, `ContentBlockView(block: FoundationModelsACP.ContentBlock, id:)` shows the ACP blocks of the transcript entries with no conversion to the kit type. Thus a host registration with `.contentBlockView(for:)` does not apply to the content of a `SessionModel` entry: the ACP path always shows the default view.

Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. A host override must get the ACP value that the entry holds.

- [ ] Change the key of the registry to a kind of the ACP `ContentBlock` (text, image, audio, resource link, resource, unknown) and the renderer input to `FoundationModelsACP.ContentBlock`.
- [ ] `ContentBlockView` resolves the registry for an ACP block before the default view.
- [ ] Update the README table row of `.contentBlockView(for:)` and `Examples/ReadmeSnippets/Snippets/HostApp.swift`.

## Acceptance Criteria
- [ ] A host registration for resource links shows in place of the default link card in the row of an agent message entry from the scripted agent.

## Tests
- [ ] `Tests/AgentViewKitTests/Thread/RegistryResolutionTests.swift`: a registration resolves for an ACP block.
- [ ] `Tests/AgentViewKitTests/Content/WireContentBlockViewHostedTests.swift`: a registered view replaces the default view of an ACP block.
- [ ] `swift test` and `Scripts/check-readme.sh` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.