# Focus audit

Status: decided. Source: the user rule of 2026-11-25 for each view kit,
relayed by testudoapp-9a (card ^b0a65bh):

> we need a 'focus ring' -- one style -- and a 'focus background' like we do
> for the cards and chips -- again ONE STYLE. I'm ok if we decide to use 'ring
> and background' together, but I'm not OK with multiple different 'ring' and
> 'background' focus styles.

EditorKit defines the one focus ring and the one focus background. This file
lists each focus visual of `Sources/AgentViewKit` and
`Sources/AgentViewKitStyle`, what it draws, and its target. Card ^0d2xs1r
adopts the EditorKit API.

## The EditorKit API

EditorKit names its focus look with `EditorFocusIndicatorKind` (EditorKit
^b3enzg5, `Sources/EditorCommandsUI/EditorFocusIndicator.swift`):

- `.ring`: the one focus ring, a band of `EditorStyle.focusRingWidth` inside
  the shape of the view, in the theme accent at `EditorStyle.focusRingOpacity`.
- `.background`: the one focus background, the accent at
  `EditorStyle.focusedSelectionOpacity` in a key window, and the inactive
  grey in a window that is not key.
- `.ringAndBackground`: the ring over the background.

`.editorFocusIndicator(_:isFocused:radius:)` and
`.editorFocusIndicator(_:isFocused:cornerRadius:)` draw a kind on a view
whose host gives the focus. In a command scope, EditorKit draws the same two
kinds with these APIs:

- `.selectableItem(isSelected:isFocused:cornerRadius:)` draws the
  `.background` kind (EditorKit `EditorFocusLook.ofSelectableItem`), and the
  selection fill of EditorKit. It also tells the scope that an item surface
  shows the focus, so the scope draws no ring, and it tells a base fill of
  the item to step aside (`\.isItemStateFillShown`).
- `.scopeFocusRing(cornerRadius:)` gives the corners of the ring of a scope,
  the `.ring` kind (EditorKit `EditorFocusLook.ofScopeRing`).
- An EditorKit button component (`EditorButton`, `EditorToolbarButton`,
  `EditorPlainButton`, `EditorMenuButton`) turns off the system focus effect
  of its control. While the control holds the SwiftUI focus, it draws the
  `.ring` kind in the shape of its bezel. A landed jump gives the focus to the
  beacon of its leaf scope, and the scope draws the `.ring` kind.

The kit uses the two kinds only through `.selectableItem` and
`.scopeFocusRing`, from `SelectableSurface.swift`, and through the EditorKit
button components. The kit does not call
`.editorFocusIndicator(.background, ...)` directly. That modifier does not
tell the scope around the item that an item surface shows the focus (the
internal `ScopeItemSurfaceKey` of EditorKit). A card or a chip in a
`.commandScope` would then show the ring of the scope over the fill: two
focus looks at a time. `.selectableItem` also draws the focus of the scope
itself, so `.editorFocusIndicator(.background, ...)` beside it would stack a
second fill. This gap went to EditorKit as a possible change: an
`.editorFocusIndicator` form that tells the scope about the item surface.

## The rule

- The kit has one focus look. An item with a surface shows the focus
  background of EditorKit (`.background`) through `SelectableSurface`. An
  item with no surface shows the focus ring of EditorKit (`.ring`) through
  the ring of its scope.
- A request card (a permission card, an elicitation form or a URL consent
  card) takes the keyboard focus with `.requestCardFocus()`: `.focusable()`,
  `.focusEffectDisabled()` and the focus fill, in one modifier.
- Only `SelectableSurface.swift` asks EditorKit for a focus ring or a focus
  fill. A view of the kit calls `.selectableSurface(_:corners:)`,
  `.selectableSurface(_:isFocused:corners:)` or `.surfaceFocusRing(_:)`.
- No view of the kit shows a system focus effect. A focusable card or row
  has `.focusEffectDisabled()` on the same view as its `.focusable()`. An
  EditorKit button, toolbar button or menu button turns off its own system
  focus effect, so the kit adds no `.withoutSystemFocusEffect()` to it. Each
  other control, such as a SwiftUI `List`, a `PathChip` (its control is a
  plain SwiftUI `Button`) or a raw `Button` in a menu, has
  `.withoutSystemFocusEffect()`, or stands in a card or a row that has
  `.focusEffectDisabled()`.
- Put `.withoutSystemFocusEffect()` on the control, inside each
  `.commandScope` that draws a ring. A scope under `.focusEffectDisabled()`
  draws no ring.
- A view of EditorKit in the kit, such as an `InspectorView`, an `EditorView`
  or a `PreviewField`, keeps the focus look that EditorKit gives it.

## The words of the table

- **System ring**: the focus ring that SwiftUI or AppKit draws for a
  focusable view.
- **Own ring**: a ring that the kit asks EditorKit for with
  `.scopeFocusRing` from a file other than `SelectableSurface.swift`.
- **Scope ring**: the focus ring of a command scope, from
  `SelectableSurface.swift` (`.surfaceFocusRing(_:)`), or the ring in the
  shape of a leaf control that EditorKit draws with no request.
- **Fill**: the focus fill of a selectable surface (`SelectableSurface`, which
  wraps EditorKit's `.selectableItem`).
- **Ring target**: the one focus ring of EditorKit, `EditorFocusIndicatorKind.ring`.
- **Background target**: the one focus background of EditorKit,
  `EditorFocusIndicatorKind.background`.
- **EditorKit API**: the EditorKit API that draws the target now.

## Shared modifiers

"Before ^b0a65bh" is the state before the audit card. "Now" is the state
after card ^0d2xs1r.

| Place | Before ^b0a65bh | Now | Target | EditorKit API |
|---|---|---|---|---|
| `SelectableSurface.swift`, `SelectableSurface` (`.selectableSurface`) | Fill | Fill; it also gives `SurfaceFocusIndicatorKey` | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| `SelectableSurface.swift`, `.surfaceFocusRing(_:)` | Did not exist | Scope ring in the corners of a surface | Ring target | `.scopeFocusRing(cornerRadius:)` |
| `SelectableSurface.swift`, `.withoutSystemFocusEffect()` | Did not exist | No system ring, on a control that is not an EditorKit button component | No focus visual of its own | None: SwiftUI's `.focusEffectDisabled()` |
| `SelectableSurface.swift`, `.selectionSurface(_:corners:)` | Selection fill only, no focus | Selection fill only, no focus | No focus visual | `.selectionSurface(_:cornerRadius:)` |
| `RequestCardFocus.swift`, `requestCardOwnSurface(_:)` | Fill | Fill, through `SelectableSurface` | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| `AgentItemScope.swift`, `AgentItemFocusLook.ring` | Own ring (`.scopeFocusRing(cornerRadius:)`) | Scope ring (`.surfaceFocusRing(_:)`) | Ring target | `.scopeFocusRing(cornerRadius:)` |
| `AgentItemScope.swift`, `AgentItemFocusLook.fill` | Fill | Fill | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| `AgentItemScope.swift`, `AgentItemFocusLook.contentSurface` | Fill of the content | Fill of the content | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| `AgentControlScope.swift`, `AgentControlCorners.control` | Scope ring in the shape of the control, and a system ring on the control | Scope ring in the shape of the control, no system ring | Ring target | The ring of a leaf control scope, in the shape that the control reports |
| `AgentControlScope.swift`, `AgentControlCorners.surface` | Own ring (`.scopeFocusRing(cornerRadius:)`), and a system ring on the control | Scope ring (`.surfaceFocusRing(_:)`), no system ring | Ring target | `.scopeFocusRing(cornerRadius:)` |

## Items

| Place | Before ^b0a65bh | Now | Target | EditorKit API |
|---|---|---|---|---|
| Message row (`TranscriptMessageView`, `.ring(.card)`) | Own ring | Scope ring | Ring target | `.scopeFocusRing(cornerRadius:)` |
| Tool call card (`ToolCallView`, `.ring(.card)`) | Own ring | Scope ring | Ring target | `.scopeFocusRing(cornerRadius:)` |
| Attachment actions and attachment inspector (`AttachmentActions`, `AttachmentInspector`, `.ring(.card)`) | Own ring | Scope ring | Ring target | `.scopeFocusRing(cornerRadius:)` |
| Attachment chip (`AttachmentChip`, `.fill`) | Fill | Fill | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| Side question card (`SideCardScope`, `.fill(.card)`) | Fill | Fill | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| File view of an attachment, image, artifact, tool call location chip (`AttachmentView`, `ImageView`, `ArtifactView`, `ToolCallLocationChips`, `.contentSurface`) | Fill | Fill | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| List of an `AgentRowList` (the list scope) | Own ring (`.scopeFocusRing(radius:)`) | Scope ring | Ring target | `.scopeFocusRing(cornerRadius:)` |
| Row of an `AgentRowList` (`.focusable()`, `@FocusState`) | Fill, no system ring | Fill, no system ring | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| Permission card (`PermissionView`, `RequestCardFocus`) | Fill, no system ring | Fill, no system ring | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| Elicitation form (`ElicitationView`, `RequestCardFocus`) | No focus visual, no system ring | Fill, no system ring | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| URL consent card (`ElicitationURLConsentView`, `RequestCardFocus`) | No focus visual, no system ring | Fill, no system ring | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| Card of a `RequestDeck` (the fill at the frame of the deck card) | Fill of a permission card only | Fill of each request card | Background target | `.selectableItem(isSelected:isFocused:cornerRadius:)` |
| Tab chip of a form (`ElicitationTabChip`, `.selectionSurface`) | Selection fill, no system ring (in the form) | Selection fill, no system ring | No focus visual (a part with no scope) | `.selectionSurface(_:cornerRadius:)`; the `EditorPlainButton` draws the ring of its control |
| File chip of a diff (`DiffView`, `PathChip`, `.selectionSurface`) | Selection fill, system ring | Selection fill, no system ring | Ring target for the chip button | `.selectionSurface(_:cornerRadius:)`; the ring of a leaf control scope when a jump lands |
| Load More of a session list (`SessionListView`, leaf control scope) | Scope ring, system ring | Scope ring, no system ring | Ring target | `EditorButton` and the ring of its leaf control scope |
| Empty state text (`ConversationEmptyState`, `.targetable(false)`) | No focus visual | No focus visual | No focus visual | None |
| VoiceOver focus (`ThreadAccessibility`, `@AccessibilityFocusState`) | The VoiceOver cursor of the system | The VoiceOver cursor of the system | Out of scope: not a keyboard focus | None |

## Controls

Each control below showed a system ring before card ^b0a65bh, and shows none
now. The target of each one is the ring target.

An EditorKit button component turns off the system focus effect of its
control, and draws the `.ring` kind in the shape of its bezel while the
control holds the SwiftUI focus (while Full Keyboard Access is on). Card
^0d2xs1r removed the `.withoutSystemFocusEffect()` of the kit from each such
control: the modifier did the work of EditorKit a second time. The column
"Turns off the system focus effect" tells which code does it now.

| File | Controls | Turns off the system focus effect |
|---|---|---|
| `Commands/AgentControlScope.swift` | Each bar control: Send and Stop (`CircleAction`), the scroll pill and the suggestions (`FloatingGlassAction`), the status bar buttons (`AgentStatusBarActionStyle`), the sign-in buttons (`AgentAuthView`), the permission mode picker, the remove button of a composer attachment chip, the composer editor | The kit: `.withoutSystemFocusEffect()` on each control of the scope, because the scope takes each kind of control |
| `Items/MessageActions.swift` | The action buttons of a message (`EditorToolbarButton`) | EditorKit |
| `Items/ToolCallView.swift` | The row toggle (`EditorPlainButton`), the answer button (`EditorToolbarButton`), the open session button (`EditorButton`) | EditorKit |
| `Items/ReasoningView.swift` | The show reasoning toggle (`EditorToolbarButton`) | EditorKit |
| `Items/JSONDisclosure.swift` | The disclosure (`EditorDisclosure`) | EditorKit |
| `Code/CodeBlockView.swift` | The copy button (`EditorToolbarButton`) | EditorKit |
| `Content/CommandOutputView.swift` | The copy button (`EditorToolbarButton`) | EditorKit |
| `Content/OutputChrome.swift` | The show all button (`EditorToolbarButton`) | EditorKit |
| `Content/Blocks/LinkView.swift` | The link card (`EditorLink`) | EditorKit |
| `Citations/InlineCitation.swift` | The citation pill (`EditorPlainButton`) | EditorKit |
| `Citations/SourcesView.swift` | The disclosure (`EditorDisclosure`) and the links in it | EditorKit |
| `Diff/DiffView.swift` | Attach, accept, reject (`EditorButton`) | EditorKit |
| `Diff/DiffView.swift` | The file chips (`PathChip`, a plain SwiftUI `Button`) | The kit: `.withoutSystemFocusEffect()` |
| `HumanInTheLoop/RequestDeck.swift` | The previous and next buttons of the deck (`EditorToolbarButton`) | EditorKit |
| `Config/ConfigOptionsView.swift` | The session options menu (`EditorMenuButton`) | EditorKit |
| `Input/ToolToggles.swift` | The tools menu (`EditorMenuButton`) | EditorKit |
| `Sessions/SessionListView.swift` | Refresh, New Session, Load More (`EditorButton`) | EditorKit |
| `Sessions/SessionBreadcrumb.swift` | The children menu (`EditorMenuButton`) | EditorKit |
| `Sessions/SessionBreadcrumb.swift` | The choices of the menus (`EditorMenuItem`) | EditorKit |
| `Sessions/SessionJumpList.swift` | The field (`AgentOneLineField`), the list (a SwiftUI `List`) and its rows (`EditorPlainButton`) | The kit: `.withoutSystemFocusEffect()` around the field and the list |
| `Activity/ActivityTimeline.swift` | The row button (`EditorPlainButton`) | EditorKit |
| `Attachments/AttachmentActions.swift` | The action buttons (`EditorToolbarButton`) | EditorKit |
| `Thread/ConversationView.swift` | Load Earlier (`EditorButton`) | EditorKit |
| `Thread/ThreadHeader.swift` | The header button (`EditorToolbarButton`) | EditorKit |
| `Thread/SideQuestionCard.swift` | The card buttons (`EditorToolbarButton`) | EditorKit |
| `AgentViewKitStyle/Status/StatusBarActionStyle.swift` | The status bar button (`EditorButton`) | EditorKit |

The controls of a permission card, an elicitation form, a URL consent card
and a row of an `AgentRowList` showed no system ring before card ^b0a65bh:
the `.focusEffectDisabled()` of the card or the row is around them.

## Known gap

An EditorKit button component and an EditorKit field (`SingleLineField`, in
`AgentOneLineField`) draw the `.ring` kind while they hold the SwiftUI focus,
so they show the one ring of EditorKit while Full Keyboard Access is on. The
SwiftUI `List` of a `SessionJumpList` shows no focus look while it holds the
focus itself. EditorKit gives a list of rows as `EditorSelectionList`. A
later card can move the jump list to it.

## Raw controls

Source: card ^8sdsx64 and the user rule of 2026-11-25 for each view kit:
each control of the kit is an EditorKit component or an EditorKit wrapper,
so that each control follows the theme. This table lists each raw SwiftUI
or AppKit control of `Sources/AgentViewKit`, `Sources/AgentViewKitStyle`
and `Sources/AgentViewKitDemoSupport`. `Sources/AgentViewKitStyle` and
`Sources/AgentViewKitDemoSupport` have no raw control.

A state of "Changed" means that the place uses the EditorKit component of
EditorKit main now. Each place has an EditorKit component now, except the
`AttachmentView` accessibility action, which stays raw by decision.

| Place | Raw control | EditorKit component or wrapper | State |
|---|---|---|---|
| `Elicitation/ElicitationFieldViews.swift`, `ElicitationToggleField` | `Toggle` (switch) | `ToggleField` with `.toggleFieldStyle(.switch)` | Changed |
| `Elicitation/ElicitationFieldViews.swift`, `ElicitationMultiChoiceField` | `Toggle` (check box) for each choice | `ToggleField` | Changed |
| `Elicitation/ElicitationFieldViews.swift`, `ElicitationSingleChoiceField` menu | `Picker` (menu) | `ChoiceField` | Changed |
| `Sessions/SessionJumpList.swift`, the filter field | `TextField` | `AgentOneLineField` (`SingleLineField` with a placeholder) | Changed |
| `Code/BlockHeader.swift`, the preview | `Button` with a title and a symbol | `EditorToolbarButton` | Changed |
| `Elicitation/ElicitationFieldViews.swift`, `ElicitationNumberField` with no range | `Stepper` beside a `NumberField` | `StepperField` with `typedValues: .keep` | Changed |
| `Elicitation/ElicitationFieldViews.swift`, `ElicitationNumberField` with a range | `Slider` | `SliderField` | Changed |
| `Elicitation/ElicitationFieldViews.swift`, `ElicitationSingleChoiceField` radio group | `Button` with a custom label for each choice | `EditorPlainButton` | Changed |
| `Elicitation/ElicitationTabChip.swift` | `Button` with a custom label | `EditorPlainButton`, with the selection of the kit (`.selectionSurface`, the wrapper of EditorKit's selection) outside the button | Changed |
| `Citations/InlineCitation.swift` | `Button` with a custom label (the pill) | `EditorPlainButton` | Changed |
| `Sessions/SessionJumpList.swift`, a row (`SessionJumpRow`) | `Button` with a custom label | `EditorPlainButton` | Changed |
| `Content/Blocks/LinkView.swift` | `Button` with a custom label that opens a URL | `EditorLink` with a custom label | Changed |
| `Activity/ActivityTimeline.swift`, the row header | `Button` that opens and closes the row | `EditorPlainButton`, with the row identifier (`ActivityTimeline.rowIdentifier(for:)`) and the hint "Shows the details" (decision of 2026-11-25: `EditorDisclosure` puts the identifier on its container and has no hint) | Changed |
| `Items/ToolCallView.swift`, the row toggle | `Button` that opens and closes the row | `EditorPlainButton`, with the toggle identifier (`ToolCallView.toggleIdentifier(for:)`). The header and the body stay two views (decision of 2026-11-25) | Changed |
| `Items/JSONDisclosure.swift` | `DisclosureGroup` | `EditorDisclosure` | Changed |
| `Citations/SourcesView.swift` | `DisclosureGroup` | `EditorDisclosure` | Changed |
| `Activity/ActivityIndicator.swift` | `ProgressView` | `EditorProgressView` | Changed |
| `Input/DefaultPromptAccessory.swift` | `ProgressView` | `EditorProgressView` | Changed |
| `Elicitation/ElicitationURLConsentView.swift` | `ProgressView` | `EditorProgressView` | Changed |
| `Terminal/TerminalView.swift` | `ProgressView` | `EditorProgressView` | Changed |
| `Content/Blocks/AudioPlayerView.swift` | `ProgressView` | `EditorProgressView` | Changed |
| `Content/Blocks/BlobResourceView.swift` | `ProgressView` | `EditorProgressView` | Changed |
| `Content/Blocks/BlockFileWriteView.swift` | `ProgressView` | `EditorProgressView` | Changed |
| `Attachments/AttachmentPreview.swift` | `ProgressView` | `EditorProgressView` | Changed |
| `Thread/SideQuestionCard.swift` | `ProgressView` | `EditorProgressView` | Changed |
| `Commands/HostPathContextMenu.swift` | `Button` in `.contextMenu` for each command at a host path | `EditorMenuItem` (`.commandContextMenu(system)` builds its menu only at the path of an ancestor scope) | Changed |
| `Sessions/SessionBreadcrumb.swift`, a choice of a crumb menu and of the children menu | `Button` in an `EditorMenuButton`, with a check mark or a circle | `EditorMenuItem` with `isSelected:`. The choice of the shown session shows the system check mark of the menu. The other choices show no mark, as each macOS menu does. A choice that needs the user shows the warning symbol | Changed |
| `Lists/AgentRowList.swift`, the preview | `Button` in `.contextMenu` | `EditorMenuItem` | Changed |
| `Lists/AgentRowList.swift`, the list | `ScrollView` of a list scope that takes the focus | `EditorScrollView` (in the form `EditorScrollStack`) | Changed |
| `Attachments/AttachmentView.swift` | `Button` in `.accessibilityActions` (a named accessibility action, not a drawn control) | None. EditorKit `ChoiceField` uses the same form for its actions | Stays (decision of 2026-11-25): it is an accessibility action, not a drawn control |

The other scroll views of the kit (the chip rows, the timeline, the form
pages and the text blocks) are not in a focus scope, so the table does not
list them.

The changed controls keep their behavior, with these changes:

- The menu of a single-choice field always has the item of no selection, so
  a person can remove the answer of an optional field, as before.
- The stepper of a number field steps in the range of the schema bounds
  (`stepperRange(minimum:maximum:)`, and the whole numbers of that range
  for an integer field). A typed number outside the range stays as typed
  (`typedValues: .keep`), so the validator shows the error of the bound. A
  step from such a number toward the range goes to the nearest bound.
- The label of an `EditorPlainButton` takes the caption font of the button
  tokens. The pill of an `InlineCitation` gets the font of the text around
  it back, so it keeps the size of that text.
- Each spinner has an accessibility label. The spinner of a preview that
  loads or writes its file is one view, `PreviewLoadingSpinner`, with the
  label "Loading". The spinner of the activity indicator has the label
  "Running".
- VoiceOver reads the card of a resource link as a link, not as a button.

The unit tests next to the tests of each changed view check that the view
mounts the EditorKit control, with the `ControlProbe` helper: the stepper
buttons and the slider of a number field, the switch, the check boxes and
the menu of a form (`ElicitationFieldControlTests`), the tab chip
(`ElicitationTabChipTests`), the jump field and the jump row
(`SessionJumpListFieldTests`), the pill of a citation
(`InlineCitationTests`), the link card (`LinkViewTests`), the JSON block
(`JSONDisclosureTests`), the sources footer (`SourcesViewDisclosureTests`),
the spinners (`ActivityIndicatorProgressTests`,
`PreviewLoadingSpinnerTests`) and the scroll view of a row list
(`AgentRowListScrollTests`), the row header of the activity timeline
(`ActivityTimelineRowTests`) and the row toggle of a tool call
(`ToolCallHeaderTests`). A control with text takes the face of a custom
theme (`EnlargedRoleTheme`), or the caption style of custom button tokens.
These theme values are not visible in a unit test:

- The accent of a check box or a switch. A window that is not key draws no
  accent, and a unit test never makes a key window.
- The `ui` face of a `ChoiceField` in the menu style. The pop-up button
  keeps the same size with the enlarged `ui` face of a theme. EditorKit must
  look at this.
- The fill of an `EditorProgressView` and the track of a `SliderField`: the
  secondary color of the theme. A unit test reads no color of a drawn
  control.
- The link color of an `EditorLink`. The link card draws its own text.
- An item of a menu (`EditorMenuItem`). AppKit draws the menu, and the
  menu shows the same rows as before.

## Tests

`Tests/AgentViewKitTests/Style/FocusLookTests.swift` checks the behavior,
with no source scan:

- Each view of the audit, laid out in a hosting view with no window, shows no
  system focus ring: no SwiftUI focus ring view, no AppKit control that
  draws its ring, and no scroll view of a list that draws the ring of the
  list.
- Each EditorKit control that the kit uses with no
  `.withoutSystemFocusEffect()` of its own (`EditorButton` in each look,
  `EditorToolbarButton` as a button and as a toggle, `EditorMenuButton`)
  shows no system focus ring. The census of a plain SwiftUI `Button` finds
  its ring, so the census can find a ring.
- A permission card, an elicitation form, a URL consent card, the
  elicitation card of a `RequestDeck` and a row of an `AgentRowList`, in a
  window that is never ordered in, show the focus background of EditorKit
  after the key view loop of the window gives them the focus.
- An attachment chip shows the focus background of EditorKit after the
  EditorKit focus request of its scope (`GeometryRegistry.requestFocus(at:)`,
  the request of a jump) gives the focus to the beacon of the scope.
- The tests read `SurfaceFocusIndicatorKey`. A `SelectableSurface` gives
  `EditorFocusIndicatorKind.background` while the item has the focus and
  EditorKit's `.selectableItem` draws its state fill: the report reads
  `\.isItemStateFillShown`, which EditorKit sets for the content of the item.

The hosted tests of the IntegrationTests package read the drawn ring and
the drawn fill in a window. Review checks the code for other focus looks.
