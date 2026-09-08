---
position_column: todo
position_ordinal: '80'
title: 'Package skeleton: four targets, dependencies, import-boundary test (plan §11#1)'
---
## What
Create `Package.swift` and the empty target tree for the package, per plan.md §11 decision 1.

- `swift-tools-version: 6.2`, `platforms: [.macOS("27.0")]`, Swift 6 language mode, `.defaultIsolation(MainActor.self)` on the UI targets (the EditorKit rule).
- Library targets and products: `AgentViewKit` (model and views), `AgentViewKitFoundationModels`, `AgentViewKitRouter`, `AgentViewKitACP`. The `AgentViewKitTestSupport` target comes in its own task.
- Test targets: `AgentViewKitTests`, `AgentViewKitFoundationModelsTests`, `AgentViewKitRouterTests`, `AgentViewKitACPTests`, plus `PackageStructureTests`.
- Dependencies, in the sibling form (`git@github.com:swissarmyhammer/<Repo>.git`, `branch: "main"`): EditorKit (products `EditorSwiftUI`, `EditorCore`, `EditorText`, `EditorTheme`, `EditorCommands`, `EditorCommandsUI`, `EditorCommandsTestSupport`, `EditorComplete`, `EditorDecorations`), FoundationModelsACP, FoundationModelsACPClient, FoundationModelsRouter, FoundationModelsExtras. Textual from `https://github.com/gonzalezreal/textual` at exact `0.5.0`. Read the product name from its `Package.swift` and write it into `Docs/decisions/dependencies.md` with the version.
- One placeholder public symbol per target so the package builds.
- Import boundaries: `Sources/AgentViewKitACP` must not import `FoundationModels`, `FoundationModelsRouter`, or `FoundationModelsExtras`. `Sources/AgentViewKit` must not import `FoundationModels`, `FoundationModelsACP`, `FoundationModelsACPClient`, `FoundationModelsRouter`, or `FoundationModelsExtras`.
- Add `.gitignore` for `.build/`, `.swiftpm/`, `*.xcodeproj`, `DerivedData/`.

## Acceptance Criteria
- [ ] `swift package resolve` exits 0 and `Package.resolved` lists Textual 0.5.0.
- [ ] `swift build` succeeds on macOS 27 with Xcode 27.
- [ ] `swift test` runs and passes with the placeholder tests.
- [ ] `Tests/PackageStructureTests/ImportBoundaryTests.swift` scans both `Sources/AgentViewKitACP` and `Sources/AgentViewKit` and fails on a forbidden import in either.
- [ ] `Tests/PackageStructureTests/ManifestTests.swift` asserts the four library products, the nine EditorKit products, and the macOS 27 floor by reading `Package.swift`.

## Tests
- [ ] `Tests/PackageStructureTests/ImportBoundaryTests.swift`: a scanner over both source roots with a fixture that proves it catches a violation.
- [ ] `Tests/PackageStructureTests/ManifestTests.swift`: products, platform floor, and the Textual product name read from `Docs/decisions/dependencies.md`.
- [ ] `swift test` exits 0 with zero warnings.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #foundation