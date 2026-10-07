---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4an45fd36e87njzv8p8bbke
  text: |-
    Research done.
    - FoundationModelsACP `ContentBlock` (pin fe0d82d) has no kind type. The cases are text, image, audio, resourceLink, resource, unknown(String, JSONValue).
    - Plan: add a public nested `FoundationModelsACP.ContentBlock.Kind` and a `kind` property in a kit extension. `ContentBlockRegistry` becomes `KeyedViewRegistry<FoundationModelsACP.ContentBlock.Kind, FoundationModelsACP.ContentBlock>`. `ContentBlockView` resolves the registry for an ACP block (the `.wire` source) before the default view. This also applies to the ACP content blocks of tool call entries, because `ToolCallView` uses the same view.
    - The kit `ContentBlock` path (the `.record` source: `ThreadMessageItemView` and the record path of `ToolCallView`) cannot use the ACP-keyed registry without a conversion. No host can write to an internal kit-keyed registry, so a kit-keyed form has no writer and is dead code. Thus a kit block always shows its default view. That path goes away with ^gzj5cye / ^71k836q.
    - Callers of the public modifier: README, `Examples/ReadmeSnippets/Snippets/HostApp.swift`, `RegistryResolutionTests`, `ContentBlockViewHostedTests.aRegisteredResourceLinkViewReplacesTheDefault` (kit block; it moves to the ACP test file). plan.md also shows the modifier; ^g95wwbs owns plan.md.
  timestamp: 2026-10-07T07:44:23.533662+00:00
- actor: claude-code
  id: 01m4anhbv14qyc10ygfbsrw6hq
  text: |-
    Implementation landed (not committed).
    - New file `Sources/AgentViewKit/Content/WireContentBlockKind.swift`: public `FoundationModelsACP.ContentBlock.Kind` (text, image, audio, resourceLink, resource, unknown) and the public `kind` property. It is a key with no values, not a copy of model data.
    - `Registries.swift`: `ContentBlockRegistry` is now `KeyedViewRegistry<FoundationModelsACP.ContentBlock.Kind, FoundationModelsACP.ContentBlock>`; `resolve(kind:)` and `.contentBlockView(for:_:)` take the ACP kind, and the closure gets the ACP block.
    - `ContentBlockView.swift`: the `.wire` source resolves the registry before the default view. This also applies to the ACP content parts of tool call entries. The `.record` (kit block) source always shows its default view. No kit-keyed form stays: no host can write to an internal kit-keyed registry, so such a form would have no writer. The old callers that show kit blocks are `ThreadMessageItemView` and the record path of `ToolCallView`; they go away with ^gzj5cye / ^71k836q.
    - The private kind-name switch `identifier(of block:)` is gone. The new internal `identifier(of kind:)` and the public `identifier(for:)` share one private helper. The label `of` keeps the kit test calls `identifier(for: .text)` free of overload ambiguity under `@testable import`.
    - Tests: `ContentBlockViewHostedTests.aRegisteredResourceLinkViewReplacesTheDefault` (a kit block) moved to `WireContentBlockViewHostedTests` as ACP tests: one registration test for each ACP kind, one test that the closure gets the ACP link, and the acceptance test (an agent message entry from the scripted agent with a resource link, shown by `ItemRow`, shows the registered view and no link card). `WireContentBlockViewHostedTests.makeWireBlock(of:)` now takes the ACP kind. `RegistryResolutionTests` content block tests use ACP blocks.
    - README: the snippet uses `if case .resourceLink(let link) = block`; the table row says the closure gets the ACP `ContentBlock` of the entry. `Examples/ReadmeSnippets/Snippets/HostApp.swift` regenerated with `Scripts/extract-readme-snippets.sh`. plan.md still shows an old sketch of the modifier; ^g95wwbs owns plan.md.
    - RED: `swift build --build-tests` failed on the missing `Kind`, the missing `identifier(of:)` and the kit-keyed closure type. GREEN: the three suites passed (43 tests).
    - Gates: `Scripts/check-readme.sh` passed. `swift test` passed: 1297 tests in 125 suites, with only the expected mlx-swift `missing creator for mutated node` warning. ^zcktrsh and ^vhp5fv7 did not fail. The demo did not change, so `Scripts/test-examples.sh` was not needed.
  timestamp: 2026-10-07T07:51:36.033343+00:00
- actor: claude-code
  id: 01m4anhfe3hqve3s8kdy1cqhgp
  text: |-
    ### implement — changed
    - evidence: 8 files — Sources/AgentViewKit/Content/WireContentBlockKind.swift (new), Sources/AgentViewKit/Thread/Registries.swift, Sources/AgentViewKit/Content/ContentBlockView.swift, Tests/AgentViewKitTests/Content/WireContentBlockViewHostedTests.swift, Tests/AgentViewKitTests/Content/ContentBlockViewHostedTests.swift, Tests/AgentViewKitTests/Thread/RegistryResolutionTests.swift, README.md, Examples/ReadmeSnippets/Snippets/HostApp.swift; `swift test` 1297 passed, `Scripts/check-readme.sh` passed
    - next: /review
  timestamp: 2026-10-07T07:51:39.715387+00:00
- actor: claude-code
  id: 01m4anx4zrfpwtp6c2rr5bxaz2
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 241c9b5) — 0 findings (7 files reviewed; README.md had no matching validator; .kanban/ files are ignored by .reviewignore)
    - next: none — task moved to done
  timestamp: 2026-10-07T07:58:02.232797+00:00
- actor: claude-code
  id: 01m4anx6j5e0jhfre8h6ksfm4v
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — ACP ContentBlock.Kind (new); the content block registry keys the ACP kind and gives the ACP block; README and HostApp snippet updated; 8 files
    - test: green — swift test, 1297 passed; README gate passed
    - commit: 241c9b5
    - review: clean — 0 findings
  timestamp: 2026-10-07T07:58:03.845872+00:00
depends_on:
- 01M48MQS1Q5HBNDFMBD2CT0C6C
position_column: done
position_ordinal: ff8580
title: Key the content block registry on the ACP ContentBlock
---
## What
`ContentBlockRegistry` (`Sources/AgentViewKit/Thread/Registries.swift`) is `KeyedViewRegistry<ContentBlock.Kind, ContentBlock>` of the kit `ContentBlock`. Since ^2ct0c6c, `ContentBlockView(block: FoundationModelsACP.ContentBlock, id:)` shows the ACP blocks of the transcript entries with no conversion to the kit type. Thus a host registration with `.contentBlockView(for:)` does not apply to the content of a `SessionModel` entry: the ACP path always shows the default view.

Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. A host override must get the ACP value that the entry holds.

- [x] Change the key of the registry to a kind of the ACP `ContentBlock` (text, image, audio, resource link, resource, unknown) and the renderer input to `FoundationModelsACP.ContentBlock`.
- [x] `ContentBlockView` resolves the registry for an ACP block before the default view.
- [x] Update the README table row of `.contentBlockView(for:)` and `Examples/ReadmeSnippets/Snippets/HostApp.swift`.

## Acceptance Criteria
- [x] A host registration for resource links shows in place of the default link card in the row of an agent message entry from the scripted agent.

## Tests
- [x] `Tests/AgentViewKitTests/Thread/RegistryResolutionTests.swift`: a registration resolves for an ACP block.
- [x] `Tests/AgentViewKitTests/Content/WireContentBlockViewHostedTests.swift`: a registered view replaces the default view of an ACP block.
- [x] `swift test` and `Scripts/check-readme.sh` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.