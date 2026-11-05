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
- actor: claude-code
  id: 01m6pvb21sq5r7rp836576yfw1
  text: |-
    Implementation landed in 0fcd76cb (worktree-agent-aaf9752759133a0b2, not pushed or merged).
    - Mic: `Phase.recording(level: Double?)`; `variableValue: level` on the EditorButton; value "Recording" then "Recording, input level 50%" (new catalog key "Recording, input level %@").
    - Sign-in: `actionButton` is `EditorButton(..., isBusy: calls[operation] != nil)`; the HStack + ProgressView + `.disabled` are gone.
    - `\.spinnerSizes` added to `theButtonTokensHaveNoPaddingByte`.
    - Tests: unit `SpeechInputButtonValueTests` (4), hosted `whileRecordingTheValueCarriesTheLastInputLevel` and `whileSigningInTheSignInButtonReadsInProgress` (agent holds `auth/login`); existing phase expectations updated to `.recording(level: nil)`.
    - Gallery: `GlassSnapshotTests/composer-field-recording` and `HostedSnapshotTests/sign-in-card-signing-in`, light and dark, both added to `recordSnapshots`.
    What did not work: the first sign-in capture shared one ScriptedSession across both looks. The light card's sign-in was cancelled when the card went away, so the dark image showed "Sign-in failed / Request cancelled". Fixed by giving each look its own held session.
    Note: the first IntegrationTests RED run took 865 s on one test. This looks like waiting on the machine-wide hosted lock that other worktrees hold. The same test took 0.29 s when it went GREEN.
  timestamp: 2026-11-05T21:55:17.689686+00:00
- actor: claude-code
  id: 01m6pvb64bhnpkvse5j72bqk7w
  text: |-
    ### implement — changed
    - evidence: 0fcd76cb; 12 files — Sources/AgentViewKit/Input/SpeechInputButton.swift, Sources/AgentViewKit/Connections/AgentAuthView.swift, Sources/AgentViewKit/Resources/Localizable.xcstrings, Tests/AgentViewKitTests/Infrastructure/ViewValueLayoutTests.swift, Tests/AgentViewKitTests/Input/SpeechInputButtonValueTests.swift, IntegrationTests/.../SpeechInputButtonHostedTests.swift, IntegrationTests/.../AgentAuthViewHostedTests.swift, IntegrationTests/.../ThreadBarControlJumpHostedTests.swift, ScreenshotTests/.../RecordingComposer.swift, GlassSnapshotTests.swift, HostedSnapshotTests.swift, ReviewGalleryScreenTests.swift. Root `swift test`: 1024 + 50 passed. IntegrationTests: 987 passed (5 known issues are the pre-existing FontRoleExpectationsTests negatives). Gallery page test passed. No warnings from AVK's own targets.
    - next: /review
  timestamp: 2026-11-05T21:55:21.867032+00:00
position_column: done
position_ordinal: ffffffb880
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