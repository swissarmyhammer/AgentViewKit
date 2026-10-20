---
assignees:
- claude-code
depends_on:
- 01M5DF8JJZ3JT3Q6XB30047RNQ
- 01M5DF8PPC1R7XN9M4SAR6MVJR
- 01M5DF8W1QPEPFE42Y4T6GSEM6
- 01M5DF911BGXPB97KE073V151H
- 01M5DF9554SMT439RB23DS9WV4
- 01M5DF9B6T1N6JXDM0BB4A7PDR
- 01M5DF9SKZ4BRGBD6BFG5XY664
- 01M5DF9Z1D6E1VEHSXTMS64VBV
- 01M5DFA593MWNN971T9F2GCJ20
- 01M5DFADQHSHCRAQW0709TVAPV
position_column: todo
position_ordinal: '9680'
title: 'AVK-8n Structure test: glass only on the floating controls and the request card buttons'
---
## Why

D110 (b), (c). After AVK-8c to AVK-8l, a test must keep the glass rules true. A source scan is deterministic and fast.

## Files

- New: `Tests/PackageStructureTests/GlassPlacementTests.swift`, with fixtures in `Tests/PackageStructureTests/Fixtures/GlassPlacement/`.
- Pattern to copy: `Tests/PackageStructureTests/ImportBoundaryTests.swift`.

## Rules that the test checks in `Sources/AgentViewKit`

- [ ] `.glassEffect(` shows only in `Theme/AgentSurfaces.swift` (the body of `agentFloatingGlass()`).
- [ ] `agentFloatingGlass()` shows only in the floating control files: `Input/PromptInputView.swift` and the file that draws the pill container of AVK-8l.
- [ ] `GlassEffectContainer` shows in `Input/PromptInputView.swift` and in the container of AVK-8l.
- [ ] `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` show only in an allow list: the floating controls (`Input/DefaultPromptAccessory.swift`, `Input/SuggestionsView.swift`, `Input/SpeechInputButton.swift`, `Thread/ScrollToBottomPill.swift`) and the action buttons of request cards and notices (`HumanInTheLoop/PermissionView.swift`, `Elicitation/ElicitationView.swift`, `Elicitation/ElicitationURLConsentView.swift`, `Connections/AgentAuthView.swift`, `Status/SessionNoticeBanner.swift`, `Status/StatusBar.swift`).
- [ ] In `Sources/AgentViewKit/Input/`, `.glassProminent` shows exactly once: the Send button.
- [ ] The scanner ignores comments and string literals.

## Acceptance

- `GlassPlacementTests` passes on the sources after the cards this card depends on.
- Fixture tests prove that the scanner reports a `.glassEffect` in a content file, a `.buttonStyle(.glass)` outside the allow list, and a second `.glassProminent` in `Input/`, each with the file and the line.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8