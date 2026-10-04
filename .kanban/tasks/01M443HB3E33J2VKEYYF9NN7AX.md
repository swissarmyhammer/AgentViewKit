---
assignees:
- claude-code
depends_on:
- 01M443H1PVEMMXJ3E2VK9MXMEM
- 01M443HJ8XEQKPMRJR6GHD93YP
- 01M443HR0D8NZ2PZ35A9BYNJ0M
position_column: todo
position_ordinal: '8480'
title: Remove the AgentViewKitFoundationModels target and the FoundationModels demo support
---
## What
FoundationModels is not a direct dependency of an ACP client kit. A FoundationModels agent reaches the kit through FoundationModelsACPAgent and ACP. Source: update.md §1, §7 items 1, 2, 4. The benchmark task and the demo tab task run first, so the CI gates stay green.

- [ ] Delete `Sources/AgentViewKitFoundationModels/` and `Tests/AgentViewKitFoundationModelsTests/`.
- [ ] Delete `Sources/DemoSupport/FoundationModelsDemoSession.swift`, `FakeLanguageModel.swift` and `DemoTools.swift`. Remove the FoundationModels launch options from `DemoLaunchOptions.swift`.
- [ ] In `Package.swift`: remove the `AgentViewKitFoundationModels` product, target and test target, and remove it from `DemoSupport` and `ReadmeSnippetsTests`. Change the header and target comments.
- [ ] Delete `Examples/ReadmeSnippets/Snippets/FoundationModelsQuickStart.swift`. Remove the FoundationModels quick start and launch flags from `README.md`. Run `Scripts/extract-readme-snippets.sh`.
- [ ] Remove `AgentViewKitFoundationModels` from `PACKAGE_PRODUCTS` in `Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb`, and make the Xcode project again.

## Acceptance Criteria
- [ ] No file in `Sources/`, `Tests/`, `Examples/` or `Benchmarks/` imports `FoundationModels` or `AgentViewKitFoundationModels`.
- [ ] `swift build --build-tests`, `swift test`, `Scripts/check-readme.sh`, `Scripts/check-benchmarks.sh` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Tests
- [ ] `Tests/PackageStructureTests/ManifestTests.swift`: the expected product list is `AgentViewKit` and `AgentViewKitACP`.
- [ ] `Tests/PackageStructureTests/ImportBoundaryTests.swift`: add the rule that no target in `Sources/` imports `FoundationModels`.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.