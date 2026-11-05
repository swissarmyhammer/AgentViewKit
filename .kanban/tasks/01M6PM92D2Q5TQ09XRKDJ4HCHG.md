---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6pm9t8nkmddqa51w32t8aj4
  text: |-
    EK ^a0rwxe1 is in progress (editorkit-b5):
    - EditorButton and EditorToolbarButton take a symbol variable value (live `Image(systemName:variableValue:)`).
    - A busy state: a themed spinner in the icon slot, caption kept, button disabled, accessibility value "In progress". When squeezed, the spinner stays and the caption hides.
    Waiting on the SHA.
  timestamp: 2026-11-05T19:52:16.917868+00:00
- actor: claude-code
  id: 01m6pqqh04fafdstmfw2k1ccve
  text: |-
    Unblocked: EK c5ac566a (^a0rwxe1) is on origin.
    - **Live level:** every icon, toggle and command init of EditorButton and EditorToolbarButton takes `variableValue: Double? = nil`, which drives `Image(systemName:variableValue:)` live with the same identity.
    - **Busy state:** the same inits take `isBusy: Bool = false`. A spinner covers the icon slot with no layout jump; size comes from `EditorStyle.Buttons.spinnerSizes`. The button is disabled, its accessibility value is a localized "In progress", and when squeezed the spinner stays and the caption hides.
    - **Limits:** a caption-only EditorButton has no busy state.
    - **New token:** `spinnerSizes` must be added to `theButtonTokensHaveNoPaddingByte`.
    Start after the button migration ^v1bmh1p's fixes merge, since it touches the same buttons.
  timestamp: 2026-11-05T20:52:11.908005+00:00
- actor: claude-code
  id: 01m6prvmr9kk2t0jc0cr1y5f03
  text: |-
    Picked up in worktree agent-aaf9752759133a0b2, HEAD contains 493dd08e; root, IntegrationTests and ScreenshotTests resolve EK c5ac566a.
    Research:
    - `SpeechInputButton` drops `.level` events (comment says EK button draws a fixed symbol). Plan: `Phase.recording(level: Double?)`, so the phase models the level with no second optional; each level change is a phase change reported through `speechInputPhaseReport`, which also lets a hosted test wait for the level with no clock. The listening symbol gets `variableValue: level`; the accessibility value reads "Recording" before the first level and "Recording, input level 50%" after it (catalog string).
    - `AgentAuthView.actionButton` wraps a `ProgressView` + `.disabled` in an HStack; replace with `EditorButton(..., isBusy:)`. EK sets the "In progress" value and disables the button.
    - Hosted sign-in busy test: `ScriptedWireAgent.heldMethods = ["auth/login"]` holds the login, so the Sign In button stays busy.
    - Gallery: `ReviewGallery.record(suite:named:size:settle:content:)` with an accessibility press in the settle (`AccessibilityAction.press.perform(on:in:)`), in light and dark.
  timestamp: 2026-11-05T21:11:55.401469+00:00
position_column: doing
position_ordinal: '9e80'
title: Microphone live level and sign-in busy state on EditorButton
---
**Blocked** on EK (requested from editorkit-b5, 2026-11-05). Gaps from the button migration ^v1bmh1p:
- The microphone button no longer shows the live input level while recording, because EditorButton takes a fixed SF Symbol. AVK needs a symbol variable value or an EditorSymbol with a value on EditorButton.
- The sign-in buttons' spinner sits next to a disabled button instead of inside it. AVK needs a busy state on EditorButton.

## What
- When EK lands these, use them. No AVK button styling.

## Tests
- [ ] Hosted: while recording, the microphone button's accessibility value carries the level. While signing in, the button reads as in progress.
- [ ] Gallery recording and signing-in states, light and dark.