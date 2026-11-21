---
assignees:
- claude-code
position_column: todo
position_ordinal: '8780'
title: EditorKit gaps that keep three AVK hosted tests red (message focus, math value, linked text)
---
Found on ^dnq1d84 (Integration CI red). AVK cannot fix these alone. Each needs an EditorKit change, then AVK uses it.

- [ ] Message focus. Since AVK a92da599, the text of a message is a read-only, selectable EditorView. `GeometryProbeView.requestFocus(yieldingTo:)` (EditorCommandsUI/GeometryRegistry.swift) gives the focus of the item scope to that text view (`contentResponder` or `ownTextView`), not to the beacon. Thus a message has no focus ring. EditorKit 905d321a fixed the same symptom for the SwiftUI text selection overlay. Proposal: an opt-in modifier (for example `.editorTakesScopeFocus(false)`) that keeps a reading text view out of the scope focus; AVK sets it in `RenderedMarkdownView`. Tests: AgentItemFocusHostedTests `.message` cases (theFirstResponderCoversAFocusedItem, theBeaconOfAnItemWithNoFocusableViewHoldsTheFocus, aFocusedItemWithNoSurfaceShowsItsScopeRing).
- [ ] Math value. The "Math" element of `MathWidget` (EditorSwiftUI/Math/MathWidget.swift) has a nil value in the hosted tree. The old AVK MathView added `.accessibilityAddTraits(.isStaticText)`. Probable fix: add that trait, with an EditorKit hosted test of the value. Test: ThreadAccessibilityHostedTests.anAnswerReadsItsMathAtItsPlaceAndKeepsTheMathElement (the value check).
- [ ] Linked text elements. `.accessibilityLinkedGroup` on the SwiftUI frame does not reach the hosted NSTextView. EditorKit needs an API for the linked elements of its text view (as `accessibilityValueProvider`). Then AVK `RenderedMarkdownView` passes the reading group. Or the user decides that the links are no longer required, and the test and Docs/decisions/accessibility.md change. Test: ThreadAccessibilityHostedTests.theTextsOfTheBlocksOfOneMessageLinkEachOther.