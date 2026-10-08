# Dependencies

Status: decided. Source: plan.md §1, §4 and §11 decision 1, and
`Docs/decisions/acp-client-kit.md`.

This file records each direct package dependency, its version requirement,
and the products that AgentViewKit uses. `Tests/PackageStructureTests/ManifestTests.swift`
reads the Textual row and compares it with `Package.swift` and
`Package.resolved`. Keep the form of that row.
`Tests/PackageStructureTests/DecisionRecordTests.swift` reads the first cell
of each row, and compares the set with the direct dependencies of the kit.

| Package | URL | Requirement | Products |
|---|---|---|---|
| textual | https://github.com/gonzalezreal/textual | exact 0.5.0 | `Textual` |
| swiftui-math | https://github.com/gonzalezreal/swiftui-math | exact 0.1.0 | `SwiftUIMath` |
| EditorKit | git@github.com:swissarmyhammer/EditorKit.git | branch main | `EditorSwiftUI`, `EditorCore`, `EditorText`, `EditorTheme`, `EditorCommands`, `EditorCommandsUI`, `EditorCommandsTestSupport`, `EditorComplete`, `EditorDecorations`, `EditorExtensions`, `EditorDiff` |
| FoundationModelsACP | git@github.com:swissarmyhammer/FoundationModelsACP.git | branch main | `FoundationModelsACP` |
| FoundationModelsACPClient | git@github.com:swissarmyhammer/FoundationModelsACPClient.git | branch main | `FoundationModelsACPClient` |

## The ACP packages

- FoundationModelsACPClient holds `ConnectionModel` and `SessionModel`. The
  views bind to these models (`Docs/decisions/acp-client-kit.md`).
- The kit also lists the `FoundationModelsACP` product, because
  `ClientSideConnection`, `InMemoryTransport` and the ACP v2 schema types are
  in that package.
- FoundationModels, FoundationModelsRouter and FoundationModelsExtras are not
  direct dependencies. FoundationModelsExtras stays in the package graph only
  because the library target of FoundationModelsACPClient depends on it. The
  kit does not import it.

## Textual

- The product name comes from the `Package.swift` of Textual at tag 0.5.0:
  `.library(name: "Textual", targets: ["Textual"])`.
- The package identity is `textual`, from the last part of the URL. The manifest
  refers to the product as `.product(name: "Textual", package: "textual")`.
- Textual is a 0.x package. A 0.x minor release can break the API, so the pin is
  `exact`.

## swiftui-math

- `Docs/decisions/math-engine.md` records the choice of the math engine.
- Textual 0.5.0 depends on the same package with `from: "0.1.0"`. The kit
  pins it `exact`, because it is a 0.x package and the kit uses its
  `Textual` SPI.

## The in-family packages

- Each in-family package uses the SSH URL and `branch: "main"`. This is the form
  that each sibling package uses. A version requirement would conflict for an
  app that also depends on another in-family package.
- EditorKit is pre-1.0 and has no tag (plan.md §4.1).

## Target boundaries

| Target | Can import |
|---|---|
| `AgentViewKit` | EditorKit products, `Textual`, `SwiftUIMath`, `FoundationModelsACP`, `FoundationModelsACPClient` |

`AgentViewKit` is the one library target and the one library product
(plan.md §11 decision 1).

`Tests/PackageStructureTests/ImportBoundaryTests.swift` enforces the
forbidden list: no target in `Sources/` imports `FoundationModels`,
`FoundationModelsRouter` or `FoundationModelsExtras` (plan.md §11 decision 1).
