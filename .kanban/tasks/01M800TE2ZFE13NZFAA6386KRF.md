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
- actor: claude-code
  id: 01m820s4t7x0xrwmw6y33pq50d
  text: |-
    ### EditorKit status (2026-11-22)
    - The math fix is on EditorKit main: 874c51e8 (b9064c95). The Math element has the TeX source as its value in the AppKit tree. EditorKit CI run 45041505277 is green.
    - AgentViewKit possibly needs no code change for ThreadAccessibilityHostedTests:267, because the value now comes from EditorKit. Only a hosted run or CI can prove it.
    - The linked group (056cd8f2) and the scope focus opt-out (351a5a91) are committed in EditorKit but not pushed yet.
    - Next: when the other 2 shas come, use the new API in RenderedMarkdownView, and then do one CI run for all 3 items.
  timestamp: 2026-11-22T16:17:42.727117+00:00
- actor: claude-code
  id: 01m821jcqpadzq2khbk93bwpk2
  text: |-
    ### EditorKit APIs are on main (2026-11-22)
    - EditorKit main 351a5a91 has all 3 fixes (math 874c51e8 is earlier).
    - 056cd8f2: `.editorAccessibilityLinkedGroup(id:in:)` (a Namespace and an id). The hosted text view gives the other text views of the group in accessibilityLinkedUIElements. A text view leaves its group when it leaves its window.
    - 351a5a91: `.editorTakesScopeFocus(false)`. A nav focus or a jump focus does not go into the read-only text view. Thus the beacon becomes first responder and the ring shows. A click still selects text.
    - Math: the Math element has the TeX source as its value. AgentViewKit possibly needs no change for it.
    - Next: use the two modifiers in RenderedMarkdownView (and in each read-only text view of a transcript item that the AgentItemFocus .message tests use). Update EditorKit with `swift package update EditorKit` in the root, IntegrationTests and ScreenshotTests.
  timestamp: 2026-11-22T16:31:30.038906+00:00
- actor: claude-code
  id: 01m821vwaq9c9t9825vt5dps6y
  text: |-
    ### Research (implement, 2026-11-22)
    - The card had no depends_on. Moved to doing.
    - `swift package update EditorKit` in the root, IntegrationTests and ScreenshotTests: all three pin 351a5a91 now. Package.resolved is in .gitignore, so git shows no change for it.
    - EditorKit API (EditorSwiftUI, macOS): `EditorSlotComposing.editorAccessibilityLinkedGroup(id:in:)` takes a Hashable id and a `Namespace.ID`. `EditorSlotComposing.editorTakesScopeFocus(_:)` takes a Bool. Both write internal `EditorSlots` fields, and `CommandScopeTextViews` has package access. Thus AVK cannot read the effect headless; only the hosted tests can.
    - The user message text and the answer text both go through TextBlockView -> ResponseView -> RenderedMarkdownView. Thus RenderedMarkdownView is the one place for both modifiers.
    - ResponseView applies `.accessibilityReadingGroup(messageGroupID ?? id)` (SwiftUI linked group) on its frame. That reaches the placeholder element of a far row, but not the NSTextView. ConversationView applies the same modifier to each row with the thread group id. If the text views took the group of any enclosing reading group, the text of an attachment in a row would link the text of other rows. Docs/decisions/accessibility.md says only the text of the text blocks of one message link. Thus the plan: the reading group modifier gives the group to the environment only when the caller asks for it (ResponseView), and RenderedMarkdownView reads it.
    - Math: AVK sets no value on the "Math" element. The only AVK value on `response-text` is the placeholder of a far row. No AVK change for the math value.
  timestamp: 2026-11-22T16:36:40.919765+00:00
- actor: claude-code
  id: 01m822b1ea8r9rkvxp6sk589kb
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift, Sources/AgentViewKit/Content/RenderedMarkdownView.swift, Sources/AgentViewKit/Content/ResponseView.swift, Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityTests.swift. EditorKit pinned at 351a5a91 in the root, IntegrationTests and ScreenshotTests (Package.resolved is gitignored). `swift test` (root): 1611 tests in 183 suites and 54 tests in 11 suites passed, no warning. `swift build --build-tests` in IntegrationTests and ScreenshotTests: Build complete, no warning.
    - What changed: new `AccessibilityReadingGroup` (id + reading namespace, nil when one is missing) and the environment value `accessibilityEditorTextReadingGroup`. `accessibilityReadingGroup(_:includingEditorText:)` gives the group to the environment only when `includingEditorText` is true; ResponseView sets it, the thread rows do not. RenderedMarkdownView applies `.editorAccessibilityLinkedGroup(id:in:)` with that group (helper `linkingText(in:)`) and `.editorTakesScopeFocus(false)`. No AVK change for the math value: AVK sets no value on the Math element.
    - RED: the new unit test did not compile (no `AccessibilityReadingGroup`). GREEN: it passes. The other effects are only visible in a window (EditorKit slot fields are internal, `CommandScopeTextViews` is package), so the hosted tests (ThreadAccessibilityHostedTests theTextsOfTheBlocksOfOneMessageLinkEachOther and anAnswerReadsItsMathAtItsPlaceAndKeepsTheMathElement, AgentItemFocusHostedTests .message cases) must prove them in CI. They were not run here, by the rule of the user.
    - next: /review, then a CI run of the integration suite.
  timestamp: 2026-11-22T16:44:57.674031+00:00
position_column: doing
position_ordinal: '80'
title: EditorKit gaps that keep three AVK hosted tests red (message focus, math value, linked text)
---
Found on ^dnq1d84 (Integration CI red). AVK cannot fix these alone. Each needs an EditorKit change, then AVK uses it.

- [x] Message focus. Since AVK a92da599, the text of a message is a read-only, selectable EditorView. `GeometryProbeView.requestFocus(yieldingTo:)` (EditorCommandsUI/GeometryRegistry.swift) gives the focus of the item scope to that text view (`contentResponder` or `ownTextView`), not to the beacon. Thus a message has no focus ring. EditorKit 905d321a fixed the same symptom for the SwiftUI text selection overlay. Proposal: an opt-in modifier (for example `.editorTakesScopeFocus(false)`) that keeps a reading text view out of the scope focus; AVK sets it in `RenderedMarkdownView`. Tests: AgentItemFocusHostedTests `.message` cases (theFirstResponderCoversAFocusedItem, theBeaconOfAnItemWithNoFocusableViewHoldsTheFocus, aFocusedItemWithNoSurfaceShowsItsScopeRing).
- [x] Math value. The "Math" element of `MathWidget` (EditorSwiftUI/Math/MathWidget.swift) has a nil value in the hosted tree. The old AVK MathView added `.accessibilityAddTraits(.isStaticText)`. Probable fix: add that trait, with an EditorKit hosted test of the value. Test: ThreadAccessibilityHostedTests.anAnswerReadsItsMathAtItsPlaceAndKeepsTheMathElement (the value check).
- [x] Linked text elements. `.accessibilityLinkedGroup` on the SwiftUI frame does not reach the hosted NSTextView. EditorKit needs an API for the linked elements of its text view (as `accessibilityValueProvider`). Then AVK `RenderedMarkdownView` passes the reading group. Or the user decides that the links are no longer required, and the test and Docs/decisions/accessibility.md change. Test: ThreadAccessibilityHostedTests.theTextsOfTheBlocksOfOneMessageLinkEachOther.