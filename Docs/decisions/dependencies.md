# Dependencies

Status: decided. Source: plan.md §4 and §11 decision 1.

This file records each package dependency, its version requirement, and the
products that AgentViewKit uses. `Tests/PackageStructureTests/ManifestTests.swift`
reads the Textual row and compares it with `Package.swift` and
`Package.resolved`. Keep the form of that row.

| Package | URL | Requirement | Products |
|---|---|---|---|
| textual | https://github.com/gonzalezreal/textual | exact 0.5.0 | `Textual` |
| EditorKit | git@github.com:swissarmyhammer/EditorKit.git | branch main | `EditorSwiftUI`, `EditorCore`, `EditorText`, `EditorTheme`, `EditorCommands`, `EditorCommandsUI`, `EditorCommandsTestSupport`, `EditorComplete`, `EditorDecorations` |
| FoundationModelsACP | git@github.com:swissarmyhammer/FoundationModelsACP.git | branch main | `FoundationModelsACP` |
| FoundationModelsACPClient | git@github.com:swissarmyhammer/FoundationModelsACPClient.git | branch main | `FoundationModelsACPClient` |
| FoundationModelsRouter | git@github.com:swissarmyhammer/FoundationModelsRouter.git | branch main | `FoundationModelsRouter` |
| FoundationModelsExtras | git@github.com:swissarmyhammer/FoundationModelsExtras.git | branch main | `FoundationModelsExtras` |

## Textual

- The product name comes from the `Package.swift` of Textual at tag 0.5.0:
  `.library(name: "Textual", targets: ["Textual"])`.
- The package identity is `textual`, from the last part of the URL. The manifest
  refers to the product as `.product(name: "Textual", package: "textual")`.
- Textual is a 0.x package. A 0.x minor release can break the API, so the pin is
  `exact`.

## The in-family packages

- Each in-family package uses the SSH URL and `branch: "main"`. This is the form
  that each sibling package uses. A version requirement would conflict for an
  app that also depends on another in-family package.
- EditorKit is pre-1.0 and has no tag (plan.md §4.1).

## Target boundaries

| Target | Can import |
|---|---|
| `AgentViewKit` | EditorKit products, `Textual` |
| `AgentViewKitFoundationModels` | `AgentViewKit`, the `FoundationModels` framework |
| `AgentViewKitRouter` | `AgentViewKit`, `FoundationModelsRouter`, `FoundationModelsExtras` |
| `AgentViewKitACP` | `AgentViewKit`, `FoundationModelsACP`, `FoundationModelsACPClient` |

`Tests/PackageStructureTests/ImportBoundaryTests.swift` enforces the two
forbidden lists of plan.md §11 decision 1.
