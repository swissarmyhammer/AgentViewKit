---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5ewv61ej5v517g2eshk69mz
  text: |-
    Research done.
    - `FloatingGlassContainer` makes a `GlassEffectContainer` only when `floatingGlassContainerCount` is zero. The nested branch returns `content` with no change, so an environment value that only the outer branch sets stays the outer value in a nested container.
    - `ReadingScopeModifier` (`Accessibility/ThreadAccessibility.swift`) is the pattern to follow: an `@Entry var ...: Namespace.ID? = nil` and an `@Namespace` that a modifier gives to its subtree.
    - `RequestDeck.swift` (deck in a bar) calls `agentFloatingGlass()` with no id. Thus `agentFloatingGlass()` stays, and `agentFloatingGlass(id:)` is the second form. `AgentSurfacesTests` also calls `agentFloatingGlass()`.
    - The kit has no `withAnimation` for the show and the hide of the editor menu. Thus the kit adds no animation, and the morph runs only in an animation that the host gives.
    - AVK-8ah (^zm1hm5q) adds its two files to the `.glassEffectID(` allow list itself. Thus this card allows only `Theme/AgentSurfaces.swift`.
    - `SourceLineScanner.codeMatches` reads only directories (`PackageFiles.swiftFiles(in:)` throws on a file). A scan of one file scans its directory and keeps the lines of that file.
    - `docs/decisions/accessibility.md` ("Reduce Motion") says "The kit has no glass morphing". That text needs a change for D113.
  timestamp: 2026-10-21T09:31:57.358347+00:00
- actor: claude-code
  id: 01m5ex74gqtbscze2g1mtkhddf
  text: |-
    Implementation landed (not committed).
    - `FloatingGlassContainer` has one `@Namespace` and sets `\.floatingGlassNamespace` only in the branch that makes the `GlassEffectContainer`. A nested container keeps the outer value.
    - `FloatingGlassID` (`.composerField`, `.editorMenu`) is in `FloatingGlassContainer.swift`. It must be `nonisolated`: with default MainActor isolation, the `Hashable` conformance is MainActor-isolated, and `glassEffectID` requires `Hashable & Sendable` ("main actor-isolated conformance ... cannot satisfy conformance requirement for a 'Sendable' type parameter").
    - `AgentFloatingGlass` has `let id: FloatingGlassID?`. `agentFloatingGlass()` stays for `RequestDeck` (no id). `agentFloatingGlass(id:)` adds `glassEffectID` only when the environment has a namespace. The DocC comment records the Reduce Motion method: no own animation.
    - `ComposerGlassStructureTests` now uses `GlassPlacementTests.uses` (`SourceLineScanner.codeMatches`) and the `GlassForm` patterns. It scans the directory of the file and keeps the lines of the file. `isCode` and the text constants are gone.
    - `GlassForm.glassEffectID` allows only `Theme/AgentSurfaces.swift`. AVK-8ah adds its two files. The violating fixture has a new line 14 and a `@Namespace` property; the clean fixture comment names `.glassEffectID(`.
    - `docs/decisions/accessibility.md` "Reduce Motion" now tells about the morph ids.
    - Not done: a hosted test that reads the `glassEffectID` itself. The SDK gives no accessibility element or value for a glass id. The structure tests and the hosted namespace test cover it.
  timestamp: 2026-10-21T09:38:29.015664+00:00
- actor: claude-code
  id: 01m5ex77z6v0mhj2ngrkwan9se
  text: |-
    ### implement — changed
    - evidence: 9 files — Sources/AgentViewKit/Theme/FloatingGlassContainer.swift, Sources/AgentViewKit/Theme/AgentSurfaces.swift, Sources/AgentViewKit/Input/PromptInputView.swift, Docs/decisions/accessibility.md, Tests/PackageStructureTests/ComposerGlassStructureTests.swift, Tests/PackageStructureTests/GlassPlacementTests.swift, Tests/PackageStructureTests/Fixtures/GlassPlacement/Violating/Placement/ContentView.swift, Tests/PackageStructureTests/Fixtures/GlassPlacement/Clean/GlassInText.swift, Tests/AgentViewKitTests/Theme/FloatingGlassContainerHostedTests.swift. `swift test`: 1475 tests in 184 suites passed with 2 known issues; 179 tests in 23 suites passed; 1 test passed. Only the mlx bundle warning, which existed before.
    - next: /review
  timestamp: 2026-10-21T09:38:32.550237+00:00
- actor: claude-code
  id: 01m5excvf92kqpk2ntqk0mp013
  text: |-
    ### test — green
    - evidence: swift test, 111 s. Swift Testing: 1475 tests in 184 suites passed, 0 failed, 0 skipped, 2 known issues (same as before). PackageStructureTests ran and passed: 179 tests in 23 suites, includes ComposerGlassStructureTests and GlassPlacementTests. FloatingGlassContainerHostedTests passed. XCTest: 0 tests, 0 failures.
    - warnings: Changed files built again with swift build --build-tests. No new warning. Only the known mlx bundle warning stays.
    - changes: No file changed by this step.
    - next: review
  timestamp: 2026-10-21T09:41:36.361888+00:00
- actor: claude-code
  id: 01m5exg4hr6nejtbb3cd4g4tge
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (fa26af5). 0 findings, 0 confirmed, 0 refuted. 7 validator runs, 0 failed. Not reviewed: 2 .kanban files (ignore rule), Docs/decisions/accessibility.md (no validator matches).
    - next: The task is in done.
  timestamp: 2026-10-21T09:43:23.960824+00:00
- actor: claude-code
  id: 01m5exgf1mt0qe51kqh8pr78v1
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 9 files
    - test: green — swift test, 1475 passed, 2 known issues that were there before; 179 structure tests passed
    - commit: fa26af5
    - review: clean — 0 findings
  timestamp: 2026-10-21T09:43:34.708376+00:00
depends_on:
- 01M5E8VGGTR59NGWNVHSDKM4QT
position_column: done
position_ordinal: ffff9880
title: 'AVK-8ag Glass morph, part 1: a @Namespace in FloatingGlassContainer, agentFloatingGlass(id:), and glassEffectID on the composer field and the editor menu; replace theComposerAddsNoGlassMorph (D113 answer 2)'
---
## Why

D113 answer 2 and `style.md` "Morphs": "When one glass element shows or hides next to another glass element in the same `GlassEffectContainer` (for example the pill beside the composer, or a tool tray), give both a `glassEffectID(_:in:)`, so the change morphs and does not jump."

Today no file of the kit has a glass morph. `Tests/PackageStructureTests/ComposerGlassStructureTests.swift:46-47` and `:99-101` (`theComposerAddsNoGlassMorph`) forbid `.glassEffectID(` in the composer. The editor menu (`PromptEditorMenuLayer`, `Sources/AgentViewKit/Input/PromptInputView.swift:229-233`, glass at `:422`) shows and hides next to the field glass (`:226`, `PromptFieldSurface`, glass at `:374`) in one container.

## Files and lines

- `Sources/AgentViewKit/Theme/FloatingGlassContainer.swift` (the one `GlassEffectContainer` of the kit).
- `Sources/AgentViewKit/Theme/AgentSurfaces.swift:75-83`, `:121-134` (`AgentFloatingGlass`, `agentFloatingGlass()`).
- `Sources/AgentViewKit/Input/PromptInputView.swift:374`, `:422`.
- `Tests/PackageStructureTests/ComposerGlassStructureTests.swift`, `Tests/PackageStructureTests/GlassPlacementTests.swift`.

## What to do

- [x] `FloatingGlassContainer` owns one `@Namespace` and gives it to its content through an internal environment value (for example `\.floatingGlassNamespace`). A nested `FloatingGlassContainer` makes no second container today: it must also keep the outer namespace.
- [x] Add an internal `enum FloatingGlassID: Hashable` with the cases of the kit: `.composerField`, `.editorMenu` (AVK-8ah adds `.scrollPill` and `.suggestion(Int)`).
- [x] Add `agentFloatingGlass(id: FloatingGlassID)`. It applies the glass and then `.glassEffectID(id, in: namespace)` when the namespace is in the environment. The old `agentFloatingGlass()` stays only if a caller has no id; otherwise remove it.
- [x] Use `.composerField` at `PromptInputView.swift:374` and `.editorMenu` at `:422`.
- [x] Reduce Motion: do not add an animation of your own. The morph runs only in the animation of the state change; with Reduce Motion on, use no `withAnimation` for the show and hide, or give `nil` as the animation (plan.md §6). Record the method in the DocC comment.
- [x] Remove `theComposerAddsNoGlassMorph` and `glassEffectIdentityCall`. Add tests: `PromptInputView.swift` gives the ids `.composerField` and `.editorMenu` (one code line each); `FloatingGlassContainer.swift` has one `@Namespace`.
- [x] Add a `GlassForm` for `.glassEffectID(` in `GlassPlacementTests`: it shows only in `Theme/AgentSurfaces.swift` and in the floating control files that AVK-8ah names.
- [x] Change the doc comment of `ComposerGlassStructureTests` (`:19-20`): the composer has morphs now (D113).

## Acceptance

- The new structure tests pass. `theComposerAddsNoGlassMorph` is gone.
- A unit test proves that the namespace reaches a child of a nested `FloatingGlassContainer` (the inner value is the outer value), with an environment read in a test view.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8