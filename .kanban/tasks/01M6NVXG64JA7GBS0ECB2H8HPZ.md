---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6nx04wrsxc6p7gxsa9krmrv
  text: |-
    Audit (EK at dc2b242, AVK main a1fe3d0d merged).

    EK helpers that synthesize the mouse or order a window in: `HostedViewHarness.click(at:)` (mouse-down/up straight to the hit view, no key window), `sendClick(atWindowPoint:)` and `sendClick(identifier:)` (queued click; `makeKeyAndOrderFront` off screen), `contextMenu(at:)`/`contextMenu(identifier:)` (builds a right-mouse-down NSEvent only to ask `menu(for:)`; nothing dispatched, no key window), `makeHostedWindow` and `pressKeyThroughApplication` (`makeKeyAndOrderFront`), `InspectorDriver.pick(_:in:)` (AX press, but its popover needs an ordered-in window). EK already has the AX verbs `press(identifier:)`, `increment(identifier:)`, `performCustomAction(named:identifier:)`, so AVK needs no interim helper.

    AVK uses: AgentRowListOpen/Sections/Current beds call `harness.window.makeKeyAndOrderFront(nil)` in every test and click with `sendClick`; ThreadMinimapView uses `click(at:)` on the scrub rail; AgentRowListRowMenu and ThreadHeaderContextMenu use `contextMenu(...)`; ElicitationFieldViews date-time pick used `makeHostedWindow` + `InspectorDriver.pick`. No CGEvent, no `NSApp.activate`, no drags or hovers anywhere. ScreenshotTests: only key events to gallery windows (real-window, left as is). Examples/AgentViewKitDemo XCUITests use `XCUIElement.click()` but are the demo's UI-test target, outside IntegrationTests/ScreenshotTests.
  timestamp: 2026-11-05T13:05:02.872722+00:00
- actor: claude-code
  id: 01m6ny0258e7fqenpqa6h6yptw
  text: |-
    Implementation landed in commit 3cec0af3 on worktree-agent-a18bf166a770b064c (merged a32f8e56 and main a1fe3d0d; not pushed).

    Converted to accessibility, headless (harness window never ordered in or made key):
    - AgentRowListOpenHostedTests: theOpenActionOpensTheRow, theOpenActionOpensARowOfADoubleClickList (new), theSelectActionOfARowThatDoesNotOpenSelectsIt (new); Return and Down Arrow tests now run without a key window.
    - AgentRowListSectionsHostedTests: theOpenActionOpensARowOfTheSecondSection, aHeaderHasNoOpenAction; all key-walk tests now run without a key window.
    - AgentRowListCurrentHostedTests: theOpenActionLeavesTheMarkToTheHost; all current/selection tests run without a key window.
    - ElicitationFieldViewsHostedTests: aPickedDateTimeWritesItsTimeInUTC (makeHostedWindow + InspectorDriver.pick in a popover) became aTypedDateTimeWritesItsTimeInUTC (types "11/5/2026, 2:30 PM" through InspectorDriver.replace + commit in a HostedViewHarness). No ordered-in window. The calendar pick itself is left to EK's own tests. If an AVK test ever needs the pick, DateField needs an accessibility pick action from EK, because InspectorDriver.pick needs a popover in an ordered-in window.

    Control change: AgentRowList rows get the named accessibility action "Open" ("Select" when the list has no onOpen). It is in VoiceOver's Actions menu. Dead end: a default press action (`.accessibilityAction(.default)`) on the row reaches every element of the row content and replaced the press of the delete button of a session row (SessionPickerConnectionModelHostedTests failed: press of session-delete-s2 reported session-row-s2). So the action is a named one. Side effect: each element in a row, the delete button included, lists "Open" in its Actions menu.

    No AVK interim helper. EK dc2b242 already has `press(identifier:)`, `increment(identifier:)` and `performCustomAction(named:identifier:)`, so moving to EK's `harness.perform(...)` is a mechanical rename.

    KEPT real mouse events that need a focused window. `sendClick` queues the click and calls `makeKeyAndOrderFront` off screen. Each one is in a suite whose name ends in `PointerHostedTests`, so it can be selected or skipped with `--filter` / `--skip PointerHostedTests`:
    1. AgentRowListOpenPointerHostedTests.oneClickOnThePaddingOpensTheRow: hit test. A click in the row's inset, outside the content, lands on the row.
    2. AgentRowListOpenPointerHostedTests.aDoubleClickOpensTheRowOnce: the behaviour is the event's click count (`NSApp.currentEvent.clickCount`). Accessibility has no double click.
    3. AgentRowListOpenPointerHostedTests.theFocusStaysOnTheOpenedItemAfterAClick: the behaviour is what the mouse-down does to the first responder (a hit row must not take focus on press).
    4. AgentRowListOpenPointerHostedTests.theFocusStaysOnTheOpenedItemAfterADoubleClick: same, on the second press.
    5. AgentRowListOpenPointerHostedTests.aClickDoesNotSelectTheRowWhenTheHostMovesNoFocus: same mouse-down first-responder behaviour.
    6. AgentRowListOpenPointerHostedTests.byDefaultOneClickSelectsTheRow: `.doubleClick` trigger. One click (click count 1) selects and does not open.
    7. AgentRowListOpenPointerHostedTests.byDefaultADoubleClickOpensTheRow: `.doubleClick` trigger. Click count 2 opens.
    8. AgentRowListInsetPointerHostedTests.aClickOnTheInsetStillOpensAWrappedRow: hit test. The context-menu wrapper around a row does not take the click from the inset.

    KEPT mouse-shaped calls that send no event to the window and take no focus (no key window, headless):
    9. ThreadMinimapViewHostedTests.aClickOnATickScrollsTheConversationToTheRowOfTheEntry: `click(at:)` on the scrub rail. The behaviour is the pointer position mapped to an entry, which is a hit test. The rail's accessibility (increment/decrement) is covered separately by theIncrementActionAnchorsTheNextEntry.
    10. AgentRowListRowMenuHostedTests (aMenuOnTheContentLeavesTheInsetBare, theMenuCoversTheInset x4, theWrapperStandsInTheScopeOfTheRow): `contextMenu(at:)` builds a right-mouse-down NSEvent only to ask `menu(for:)`. The first two are hit tests (which area the menu covers).
    11. ThreadHeaderContextMenuHostedTests (4 tests): `contextMenu(identifier:)` reads the menu items. This is not a hit test. The only accessibility route is AXShowMenu, which pops a modal menu. An EK helper that reads a context menu's items without opening it would let these move. Flagging for EK coordination.

    Focus-stealing audit: the only `makeKeyAndOrderFront` calls in AVK test code were the three row-list beds (removed) and EK's makeHostedWindow in the date-time test (removed). Nothing calls `NSApp.activate`, key- or main-window grabs, or CGEvent. HostedFocusTests uses a subclass that only reports isKeyWindow and is never ordered in. ScreenshotTests (gallery, real window) is unchanged. Examples/AgentViewKitDemo XCUITests use XCUIElement.click() but are outside IntegrationTests/ScreenshotTests.
  timestamp: 2026-11-05T13:22:28.648560+00:00
- actor: claude-code
  id: 01m6ny080nry8rz762qxn6jzhr
  text: |-
    ### implement — changed
    - evidence: commit 3cec0af3. 7 files: Sources/AgentViewKit/Lists/AgentRowList.swift, Sources/AgentViewKit/Resources/Localizable.xcstrings, IntegrationTests/.../Lists/AgentRowListOpenHostedTests.swift, AgentRowListSectionsHostedTests.swift, AgentRowListCurrentHostedTests.swift, IntegrationTests/.../Elicitation/ElicitationFieldViewsHostedTests.swift, ARCHITECTURE.md. Root `swift test`: 969 + 60 passed. IntegrationTests `swift test`: 953 passed (5 pre-existing known issues). Only warning is the allowed mlx-swift_Cmlx one.
    - next: /review. Coordinate with EK on a context-menu read helper (kept case 11) and an optional DateField pick action. When EK's `harness.perform` lands, rename press/performCustomAction calls.
  timestamp: 2026-11-05T13:22:34.645120+00:00
- actor: claude-code
  id: 01m6nz7y8dx4dy7b2d6wk3wvm9
  text: |-
    Review fix landed as b932d8a1 (on top of 3cec0af3, branch worktree-agent-a18bf166a770b064c; main can fast-forward).

    - AgentRowClicks now makes each row one container element: `.accessibilityElement(children: .contain)`, with the new `AgentRowListScope.rowIdentifier(for:)` (`agent-row-<list>/<rowKind>:<id>`, public, with `rowIdentifierPrefix`) and the named Open/Select action. A session row's delete button no longer lists Open.
    - Dead end: the plain `.contain` (and a ZStack, a padded VStack or a background around the content) folded ConnectionRow's own `.contain` container into the row element, so `connection-row-<name>` was overwritten. MCPServersHostedTests failed 4 tests. A probe showed that SwiftUI folds a container whose only child is a container into that child. The fix is a clear overlay hidden from accessibility, with `allowsHitTesting(false)`, as a second child. The row element then stands one level above the content, and no layout or hit area changes.
    - Tests: the converted hosted tests perform the action on the row element's id. New test `SessionPickerConnectionModelHostedTests.theDeleteButtonHasNoActionOfTheRow` asserts the delete button's custom actions have neither Open nor Select (seen RED, then GREEN). `aDeleteSendsSessionDeleteAndTheRowGoesAwayWithTheItem` and `aFailedDeleteShowsTheErrorAndKeepsTheRow` pass.
    - Doc comments on AgentRowList and AgentRowClicks were reworded to describe the row element.

    ### implement — changed
    - evidence: b932d8a1. 5 files: Sources/AgentViewKit/Lists/AgentRowList.swift, IntegrationTests/.../Lists/AgentRowListOpenHostedTests.swift, AgentRowListSectionsHostedTests.swift, AgentRowListCurrentHostedTests.swift, IntegrationTests/.../Sessions/SessionPickerConnectionModelHostedTests.swift. Root swift test: 969 + 60 passed. IntegrationTests: 954 passed (5 known issues, pre-existing). Only the allowed mlx warning.
    - next: fast-forward main to b932d8a1, then /review.
  timestamp: 2026-11-05T13:44:15.373784+00:00
position_column: done
position_ordinal: ffffffa480
title: Drive AVK's hosted UI tests through accessibility, not the mouse
---
User direction for every view kit (relayed by kanbanviewkit-6d, 2026-11-05): "in general, i wish you were doing UI automation testing via accessibility rather than moving the mouse … and like the other view kits too". KVK's matching card is 01M6NVVR….

## Rule
- Hosted tests find an element by its accessibility identifier and perform its accessibility action (press, focus, pick, increment, or a named custom action), then assert behaviour.
- No synthesized mouse moves, clicks or drags aimed with frames.
- Keep a real mouse event only where the behaviour under test IS the hit test (for example, a rounded corner takes no click, or the scroll-to-bottom pill doesn't block clicks it isn't over). List each kept one on this card for the user.
- If a control lacks the accessibility action a test needs, add it to the control. That's real accessibility value, not a test hack.
- Use EK's shared helper for performing an accessibility action if it has one (kanbanviewkit-6d asked editorkit-b5). Don't write an AVK copy of a generic helper.

## What
- Audit every hosted test in IntegrationTests (and the ScreenshotTests fixtures that drive UI) for mouse use. That covers direct NSEvent/CGEvent clicks, drags and moves, plus harness or EK test-support calls that synthesize the mouse under the hood (check each helper's implementation).
- Convert each to accessibility actions, adding missing actions to controls.
- List the hit-test cases that keep a real mouse event, with the reason for each.

## Acceptance Criteria
- [ ] No hosted test synthesizes the mouse except the listed hit-test cases.
- [ ] Every control a test drives has the accessibility action it needs.

## Tests
- [ ] The full AVK suite is green, with zero warnings in AVK targets.