---
assignees:
- claude-code
depends_on:
- 01M5E8WCXKPRJWZ9XMPSPYDP18
- 01M5E8W08CXBJD9CHP8EKR44GZ
position_column: todo
position_ordinal: ab80
title: 'AVK-8ah Glass morph, part 2: glassEffectID on the scroll-to-bottom pill and the suggestion chips (D113 answer 2)'
---
## Why

D113 answer 2: "When one glass element shows or hides beside another in the same GlassEffectContainer (the pill beside the composer, the tool tray), give both a glassEffectID with a @Namespace."

Facts:
- The pill (`ConversationPill`, `Sources/AgentViewKit/Thread/ConversationView.swift:422`; button in `Sources/AgentViewKit/Thread/ScrollToBottomPill.swift:51-52`) shows and hides above the composer in the container of `AgentThreadView.floatingControls` (`Sources/AgentViewKit/Thread/AgentThreadView.swift:235-247`).
- The suggestion chips (`Sources/AgentViewKit/Input/SuggestionsView.swift:45-55`) hide while the agent runs (`Input/DefaultPromptAccessory.swift:111-113`).
- The kit has no tool tray today (no `tray` in Sources). If one comes later, it uses the same method.

## What to do

- [ ] Add the cases `.scrollPill` and `.suggestion(Int)` to `FloatingGlassID` (AVK-8ag).
- [ ] Give the pill button `.glassEffectID(FloatingGlassID.scrollPill, in: namespace)` with the namespace of the environment from AVK-8ag. Check that `glassEffectID` works on a `.buttonStyle(.glass)` button. If it does not, record it in a comment on this card, and change the pill to a plain button with `agentFloatingGlass(id: .scrollPill)` in a `.capsule` shape (then add a shape parameter to `agentFloatingGlass`), and change the allow lists of `GlassPlacementTests`.
- [ ] Give each suggestion chip `.glassEffectID(FloatingGlassID.suggestion(index), in: namespace)`.
- [ ] Do not write `.glassEffect(` in `AgentThreadView.swift`: `ComposerGlassStructureTests.theThreadViewWritesNoGlassOfItsOwn` stays true.
- [ ] Add the two files to the `.glassEffectID(` allow list of `GlassPlacementTests` (AVK-8ag).

## Acceptance

- A structure test holds one id use for `.scrollPill` (in the pill file) and one for `.suggestion(` (in `SuggestionsView.swift`), on code lines.
- `GlassPlacementTests` and `ComposerGlassStructureTests` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8