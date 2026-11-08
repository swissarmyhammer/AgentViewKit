---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: 'Button focus ring follows the bezel: use EK .editorButtonBorderShape (EK ^zw631dd)'
---
EK ^zw631dd is on EditorKit main 4e673e2c. The ring of a landed EditorButton now follows the real bezel of its style. SwiftUI cannot read a host `.buttonBorderShape(_:)`, so a kit must tell EditorKit the shape with `.editorButtonBorderShape(_:)` (EditorSwiftUI, Sources/EditorSwiftUI/EditorButtonBezel.swift; cases include `.capsule` and `.circle`). Otherwise the ring is a 6 pt rounded rectangle around a capsule or circle bezel.

Other EK changes in ^zw631dd: `.selectableCapsule(isSelected:)` and `.selectableCapsule(isSelected:isFocused:)` for a capsule item; an infinite radius is also a capsule; a click on a button with `.focusesScopeOnClick()` focuses the leaf scope of the button.

## Changes in AgentViewKit
Step 0: Update the EditorKit pin to 4e673e2c or later in the root package, IntegrationTests and ScreenshotTests (`swift package --package-path <p> update EditorKit`). Package.resolved is git-ignored.
1. Sources/AgentViewKit/Theme/FloatingGlassAction.swift:24: use `.editorButtonBorderShape(.capsule)` in place of `.buttonBorderShape(.capsule)`, if `.editorButtonBorderShape` also sets the SwiftUI bezel shape; else keep both. Read the EK source to decide.
2. Sources/AgentViewKit/Input/DefaultPromptAccessory.swift:131 and Sources/AgentViewKit/Input/SpeechInputButton.swift:71: the same for `.buttonBorderShape(.circle)` → `.editorButtonBorderShape(.circle)`.
3. Find other buttons in a scope whose bezel is not the default (for example `.agentControlScope` users) and check their ring shape.
4. Check if a capsule item of AVK (for example PendingRequestCountBadge, InlineCitation) is selectable or focusable. If yes, use `.selectableCapsule`. If no, no change.
5. Hosted test: the ring of a landed FloatingGlassAction is a capsule, and the ring of the speech button is a circle (read the ring shape from the scope, no pixels).
6. Record all screenshots again (`swift test --package-path ScreenshotTests`), check them, and give the changed PNG paths to the user.

Test rules: no clock/sleep/poll/retry/timeLimit/XCUITest; tests never show a window or take focus. No magic numbers, no duplicated code.

Commit only. Do not push: the user of AVK decides the push.