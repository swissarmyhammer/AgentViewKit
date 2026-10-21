---
assignees:
- claude-code
depends_on:
- 01M5E8VGGTR59NGWNVHSDKM4QT
position_column: todo
position_ordinal: aa80
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

- [ ] `FloatingGlassContainer` owns one `@Namespace` and gives it to its content through an internal environment value (for example `\.floatingGlassNamespace`). A nested `FloatingGlassContainer` makes no second container today: it must also keep the outer namespace.
- [ ] Add an internal `enum FloatingGlassID: Hashable` with the cases of the kit: `.composerField`, `.editorMenu` (AVK-8ah adds `.scrollPill` and `.suggestion(Int)`).
- [ ] Add `agentFloatingGlass(id: FloatingGlassID)`. It applies the glass and then `.glassEffectID(id, in: namespace)` when the namespace is in the environment. The old `agentFloatingGlass()` stays only if a caller has no id; otherwise remove it.
- [ ] Use `.composerField` at `PromptInputView.swift:374` and `.editorMenu` at `:422`.
- [ ] Reduce Motion: do not add an animation of your own. The morph runs only in the animation of the state change; with Reduce Motion on, use no `withAnimation` for the show and hide, or give `nil` as the animation (plan.md §6). Record the method in the DocC comment.
- [ ] Remove `theComposerAddsNoGlassMorph` and `glassEffectIdentityCall`. Add tests: `PromptInputView.swift` gives the ids `.composerField` and `.editorMenu` (one code line each); `FloatingGlassContainer.swift` has one `@Namespace`.
- [ ] Add a `GlassForm` for `.glassEffectID(` in `GlassPlacementTests`: it shows only in `Theme/AgentSurfaces.swift` and in the floating control files that AVK-8ah names.
- [ ] Change the doc comment of `ComposerGlassStructureTests` (`:19-20`): the composer has morphs now (D113).

## Acceptance

- The new structure tests pass. `theComposerAddsNoGlassMorph` is gone.
- A unit test proves that the namespace reaches a child of a nested `FloatingGlassContainer` (the inner value is the outer value), with an environment read in a test view.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8