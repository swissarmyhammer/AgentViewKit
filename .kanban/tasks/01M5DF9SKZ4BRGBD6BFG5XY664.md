---
assignees:
- claude-code
depends_on:
- 01M5DF892NSFBA3B087C5MVVT4
position_column: todo
position_ordinal: '9080'
title: 'AVK-8i Composer: put the field and the accessory cluster in one GlassEffectContainer, with no glass on glass'
---
## Why

D110 (c). The composer is a floating control, so it can use glass. Today `PromptInputView` puts one `.glassEffect` on the whole VStack (chips, editor and accessory). The accessory buttons (Send, Stop, dictation, suggestion chips) use the `.glass` and `.glassProminent` styles inside that glass. That is glass on glass. There is no `GlassEffectContainer` in the kit today.

## Files

- `Sources/AgentViewKit/Input/PromptInputView.swift` body, about lines 167-195. Line 189: `.glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))`.
- `Sources/AgentViewKit/Input/DefaultPromptAccessory.swift` body, about lines 61-80 (suggestions at line 64, the button row with `SpeechInputButton` at 73, Stop, Send).
- No change in `Input/SuggestionsView.swift` line 52 and `Input/SpeechInputButton.swift` line 67. They keep `.buttonStyle(.glass)`.

## What to do

- [ ] Wrap the body of `PromptInputView` in `GlassEffectContainer(spacing: theme.spacing.s)`.
- [ ] Put `agentFloatingGlass()` (AVK-8b) on the field only: the attachment chips and the editor.
- [ ] Put the accessory below the field, as a sibling in the container, not inside the field glass. Its buttons keep their glass button styles. The container blends the shapes.
- [ ] Give the field surface an accessibility identifier, for example `prompt-field-surface`, so a hosted test can read its frame.
- [ ] Keep `.disabled(isSessionClosed)`, the drop destination and the environment values on the whole composer.
- [ ] With Reduce Motion on, add no glass morph (plan.md §6).

## Acceptance

- `PromptInputView.swift` has one `GlassEffectContainer` and no direct `.glassEffect` call. The field uses `agentFloatingGlass()`.
- A hosted test (`HostedViewHarness`) shows `PromptInputView` with `DefaultPromptAccessory`. The frame of the submit button (`prompt-submit`) does not intersect the frame of `prompt-field-surface`.
- All tests in `Tests/AgentViewKitTests/Input/` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event. After each key press, the test waits for its result before the next step. #avk-8