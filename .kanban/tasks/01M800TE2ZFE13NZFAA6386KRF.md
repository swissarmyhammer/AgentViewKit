---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m802fbkbw5rttah2z3wa5rft
  text: |-
    ### EditorKit cards (2026-11-21)
    - editorkit-7a made one card for each item. The work waits for the go of its user.
      - Message focus: EditorKit 01M802EEE5E1B804BJ5B9DFX60 (opt-in modifier, for example .editorTakesScopeFocus(false)).
      - Math value: EditorKit 01M802EKSZ0C1HQ06D2SZRQ82J (the "Math" element value is the TeX source, with a hosted test).
      - Linked text: EditorKit 01M802ESXSSD17W8GBVPXCTNE7 (an EditorView API for the linked elements of its hosted text view).
      - Bounded HostedViewHarness.render(when:): EditorKit 01M802E3Q7836FRWDXSCFA062Q.
    - This card is blocked until EditorKit sends the sha of each fix. Then AVK uses the new API in RenderedMarkdownView and the three tests run in CI.
  timestamp: 2026-11-21T22:08:50.283799+00:00
position_column: todo
position_ordinal: '8780'
title: EditorKit gaps that keep three AVK hosted tests red (message focus, math value, linked text)
---
Found on ^dnq1d84 (Integration CI red). AVK cannot fix these alone. Each needs an EditorKit change, then AVK uses it.

- [ ] Message focus. Since AVK a92da599, the text of a message is a read-only, selectable EditorView. `GeometryProbeView.requestFocus(yieldingTo:)` (EditorCommandsUI/GeometryRegistry.swift) gives the focus of the item scope to that text view (`contentResponder` or `ownTextView`), not to the beacon. Thus a message has no focus ring. EditorKit 905d321a fixed the same symptom for the SwiftUI text selection overlay. Proposal: an opt-in modifier (for example `.editorTakesScopeFocus(false)`) that keeps a reading text view out of the scope focus; AVK sets it in `RenderedMarkdownView`. Tests: AgentItemFocusHostedTests `.message` cases (theFirstResponderCoversAFocusedItem, theBeaconOfAnItemWithNoFocusableViewHoldsTheFocus, aFocusedItemWithNoSurfaceShowsItsScopeRing).
- [ ] Math value. The "Math" element of `MathWidget` (EditorSwiftUI/Math/MathWidget.swift) has a nil value in the hosted tree. The old AVK MathView added `.accessibilityAddTraits(.isStaticText)`. Probable fix: add that trait, with an EditorKit hosted test of the value. Test: ThreadAccessibilityHostedTests.anAnswerReadsItsMathAtItsPlaceAndKeepsTheMathElement (the value check).
- [ ] Linked text elements. `.accessibilityLinkedGroup` on the SwiftUI frame does not reach the hosted NSTextView. EditorKit needs an API for the linked elements of its text view (as `accessibilityValueProvider`). Then AVK `RenderedMarkdownView` passes the reading group. Or the user decides that the links are no longer required, and the test and Docs/decisions/accessibility.md change. Test: ThreadAccessibilityHostedTests.theTextsOfTheBlocksOfOneMessageLinkEachOther.