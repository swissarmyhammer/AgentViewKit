# Focus audit

Status: decided. Source: the user rule of 2026-11-25 for each view kit,
relayed by testudoapp-9a (card ^b0a65bh):

> we need a 'focus ring' -- one style -- and a 'focus background' like we do
> for the cards and chips -- again ONE STYLE. I'm ok if we decide to use 'ring
> and background' together, but I'm not OK with multiple different 'ring' and
> 'background' focus styles.

EditorKit defines the one focus ring and the one focus background. This file
lists each focus visual of `Sources/AgentViewKit` and
`Sources/AgentViewKitStyle`, what it draws, and its target. A second card
adopts the EditorKit API. That card changes only
`Sources/AgentViewKitStyle/Theme/SelectableSurface.swift`.

## The rule

- The kit has one focus look. An item with a surface shows the focus fill of
  `SelectableSurface`. An item with no surface shows the focus ring of its
  scope.
- A request card (a permission card, an elicitation form or a URL consent
  card) takes the keyboard focus with `.requestCardFocus()`: `.focusable()`,
  `.focusEffectDisabled()` and the focus fill, in one modifier.
- Only `SelectableSurface.swift` asks EditorKit for a focus ring or a focus
  fill. A view of the kit calls `.selectableSurface(_:corners:)`,
  `.selectableSurface(_:isFocused:corners:)` or `.surfaceFocusRing(_:)`.
- No view of the kit shows a system focus effect. A focusable card or row
  has `.focusEffectDisabled()` on the same view as its `.focusable()`. A
  button, a menu, a field, a disclosure group or a list has
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
- **Ring target**: the one focus ring of EditorKit.
- **Background target**: the one focus background of EditorKit.

## Shared modifiers

| Place | Before this card | Now | Target |
|---|---|---|---|
| `SelectableSurface.swift`, `SelectableSurface` (`.selectableSurface`) | Fill | Fill; it also gives `SelectableSurfaceFocusKey` | Background target |
| `SelectableSurface.swift`, `.surfaceFocusRing(_:)` | Did not exist | Scope ring in the corners of a surface | Ring target |
| `SelectableSurface.swift`, `.withoutSystemFocusEffect()` | Did not exist | No system ring | Ring target for a control that takes the focus itself |
| `SelectableSurface.swift`, `.selectionSurface(_:corners:)` | Selection fill only, no focus | Selection fill only, no focus | No focus visual |
| `AgentItemScope.swift`, `AgentItemFocusLook.ring` | Own ring (`.scopeFocusRing(cornerRadius:)`) | Scope ring (`.surfaceFocusRing(_:)`) | Ring target |
| `AgentItemScope.swift`, `AgentItemFocusLook.fill` | Fill | Fill | Background target |
| `AgentItemScope.swift`, `AgentItemFocusLook.contentSurface` | Fill of the content | Fill of the content | Background target |
| `AgentControlScope.swift`, `AgentControlCorners.control` | Scope ring in the shape of the control, and a system ring on the control | Scope ring in the shape of the control, no system ring | Ring target |
| `AgentControlScope.swift`, `AgentControlCorners.surface` | Own ring (`.scopeFocusRing(cornerRadius:)`), and a system ring on the control | Scope ring (`.surfaceFocusRing(_:)`), no system ring | Ring target |

## Items

| Place | Before this card | Now | Target |
|---|---|---|---|
| Message row (`TranscriptMessageView`, `.ring(.card)`) | Own ring | Scope ring | Ring target |
| Tool call card (`ToolCallView`, `.ring(.card)`) | Own ring | Scope ring | Ring target |
| Attachment actions and attachment inspector (`AttachmentActions`, `AttachmentInspector`, `.ring(.card)`) | Own ring | Scope ring | Ring target |
| Attachment chip (`AttachmentChip`, `.fill`) | Fill | Fill | Background target |
| Side question card (`SideCardScope`, `.fill(.card)`) | Fill | Fill | Background target |
| File view of an attachment, image, artifact, tool call location chip (`AttachmentView`, `ImageView`, `ArtifactView`, `ToolCallLocationChips`, `.contentSurface`) | Fill | Fill | Background target |
| List of an `AgentRowList` (the list scope) | Own ring (`.scopeFocusRing(radius:)`) | Scope ring | Ring target |
| Row of an `AgentRowList` (`.focusable()`, `@FocusState`) | Fill, no system ring | Fill, no system ring | Background target |
| Permission card (`PermissionView`, `RequestCardFocus`) | Fill, no system ring | Fill, no system ring | Background target |
| Elicitation form (`ElicitationView`, `RequestCardFocus`) | No focus visual, no system ring | Fill, no system ring | Background target |
| URL consent card (`ElicitationURLConsentView`, `RequestCardFocus`) | No focus visual, no system ring | Fill, no system ring | Background target |
| Card of a `RequestDeck` (the fill at the frame of the deck card) | Fill of a permission card only | Fill of each request card | Background target |
| Tab chip of a form (`ElicitationTabChip`, `.selectionSurface`) | Selection fill, no system ring (in the form) | Selection fill, no system ring | No focus visual (a part with no scope) |
| File chip of a diff (`DiffView`, `PathChip`, `.selectionSurface`) | Selection fill, system ring | Selection fill, no system ring | Ring target for the chip button |
| Load More of a session list (`SessionListView`, leaf control scope) | Scope ring, system ring | Scope ring, no system ring | Ring target |
| Empty state text (`ConversationEmptyState`, `.targetable(false)`) | No focus visual | No focus visual | No focus visual |
| VoiceOver focus (`ThreadAccessibility`, `@AccessibilityFocusState`) | The VoiceOver cursor of the system | The VoiceOver cursor of the system | Out of scope: not a keyboard focus |

## Controls

Each control below showed a system ring before this card, and shows none now.
The target of each one is the ring target.

| File | Controls |
|---|---|
| `Commands/AgentControlScope.swift` | Each bar control: Send and Stop (`CircleAction`), the scroll pill and the suggestions (`FloatingGlassAction`), the status bar buttons (`AgentStatusBarActionStyle`), the sign-in buttons (`AgentAuthView`), the permission mode picker, the remove button of a composer attachment chip, the composer editor |
| `Items/MessageActions.swift` | The action buttons of a message |
| `Items/ToolCallView.swift` | The row toggle, the answer button, the open session button |
| `Items/ReasoningView.swift` | The show reasoning toggle |
| `Items/JSONDisclosure.swift` | The disclosure group |
| `Code/CodeBlockView.swift` | The copy button |
| `Content/CommandOutputView.swift` | The copy button |
| `Content/OutputChrome.swift` | The show all button |
| `Content/Blocks/LinkView.swift` | The link card button |
| `Citations/InlineCitation.swift` | The citation pill |
| `Citations/SourcesView.swift` | The disclosure group and the links in it |
| `Diff/DiffView.swift` | The file chips, attach, accept, reject |
| `HumanInTheLoop/RequestDeck.swift` | The previous and next buttons of the deck |
| `Config/ConfigOptionsView.swift` | The session options menu |
| `Input/ToolToggles.swift` | The tools menu |
| `Sessions/SessionListView.swift` | Refresh, New Session, Load More |
| `Sessions/SessionBreadcrumb.swift` | The choice buttons, the children menu |
| `Sessions/SessionJumpList.swift` | The field, the list and its rows |
| `Activity/ActivityTimeline.swift` | The row button |
| `Attachments/AttachmentActions.swift` | The action buttons |
| `Thread/ConversationView.swift` | Load Earlier |
| `Thread/ThreadHeader.swift` | The header button |
| `Thread/SideQuestionCard.swift` | The card buttons |
| `AgentViewKitStyle/Status/StatusBarActionStyle.swift` | The status bar button |

The controls of a permission card, an elicitation form, a URL consent card
and a row of an `AgentRowList` showed no system ring before this card: the
`.focusEffectDisabled()` of the card or the row is around them.

## Known gap until the adoption card

A control that takes the keyboard focus itself shows no focus look now: a
text field, a list, and a button while Full Keyboard Access is on. Before
this card it showed the system ring. The adoption card gives each such
control the ring target in `.withoutSystemFocusEffect()`.

## Raw controls

Source: card ^8sdsx64 and the user rule of 2026-11-25 for each view kit:
each control of the kit is an EditorKit component or an EditorKit wrapper,
so that each control follows the theme. This table lists each raw SwiftUI
or AppKit control of `Sources/AgentViewKit`, `Sources/AgentViewKitStyle`
and `Sources/AgentViewKitDemoSupport`. `Sources/AgentViewKitStyle` and
`Sources/AgentViewKitDemoSupport` have no raw control.

A state of "Changed" means that the place uses the EditorKit component of
EditorKit main now. A state of "Waits for ^id" means that the EditorKit
component is not on EditorKit main yet. The EditorKit card ^id adds it. A
state of "Not changed; a person decides" means that the component of the
table does not fit the place as it is, and the row tells why.

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
| `Activity/ActivityTimeline.swift`, the row header | `Button` that opens and closes the row | `EditorDisclosure` with a custom label | Not changed; a person decides. `EditorDisclosure` puts the identifier of a host on its container, not on its header, and its header has no hint. So the row loses the identifier that a press finds (`ActivityTimeline.rowIdentifier(for:)`, which the hosted tests press) and the hint "Shows the details". `EditorPlainButton` keeps both |
| `Items/ToolCallView.swift`, the row toggle | `Button` that opens and closes the row | `EditorDisclosure` with a custom label | Not changed; a person decides. The header (`ToolCallHeader`) and the body of a tool call are two views, and the header has the MCP status and the background caption beside its button. `EditorDisclosure` holds a header and its body in one view, and puts the identifier on its container, not on the header (`ToolCallView.toggleIdentifier(for:)`). `EditorPlainButton` fits the header as it is |
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
| `Commands/HostPathContextMenu.swift` | `Button` in `.contextMenu` for each command at a host path | `EditorMenuItem` (`.commandContextMenu(system)` builds its menu only at the path of an ancestor scope) | Waits for ^ndeex7s |
| `Sessions/SessionBreadcrumb.swift`, a choice of the children menu | `Button` in an `EditorMenuButton` | `EditorMenuItem` | Waits for ^ndeex7s |
| `Lists/AgentRowList.swift`, the preview | `Button` in `.contextMenu` | `EditorMenuItem` | Waits for ^ndeex7s |
| `Lists/AgentRowList.swift`, the list | `ScrollView` of a list scope that takes the focus | `EditorScrollView` | Waits for ^3q46xdt |
| `Attachments/AttachmentView.swift` | `Button` in `.accessibilityActions` (a named accessibility action, not a drawn control) | None. EditorKit `ChoiceField` uses the same form for its actions | Not a control; a person decides |

The other scroll views of the kit (the chip rows, the timeline, the form
pages and the text blocks) are not in a focus scope, so the table does not
list them.

The changed controls keep their behavior, with this change:

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

`Tests/AgentViewKitTests/Elicitation/ElicitationFieldControlTests.swift` and
`Tests/AgentViewKitTests/Sessions/SessionJumpListFieldTests.swift` check
that each changed view mounts the EditorKit control, and that the control
takes the face of a custom theme (`EnlargedRoleTheme`). Two theme values
are not visible in a unit test:

- The accent of a check box or a switch. A window that is not key draws no
  accent, and a unit test never makes a key window.
- The `ui` face of a `ChoiceField` in the menu style. The pop-up button
  keeps the same size with the enlarged `ui` face of a theme. EditorKit must
  look at this.

## Tests

`Tests/AgentViewKitTests/Style/FocusLookTests.swift` checks the behavior,
with no source scan:

- Each view of the audit, laid out in a hosting view with no window, shows no
  system focus ring: no SwiftUI focus ring view, no AppKit control that
  draws its ring, and no scroll view of a list that draws the ring of the
  list.
- A permission card, an elicitation form, a URL consent card, the
  elicitation card of a `RequestDeck` and a row of an `AgentRowList`, in a
  window that is never ordered in, show the focus fill
  (`SelectableSurfaceFocusKey`) after the key view loop of the window gives
  them the focus.
- An item that shows the focus of its scope, such as an attachment chip, gets
  the focus only from the beacon of its scope, through a jump or a `nav.*`
  move. No unit test gives that focus. The fill of such an item is the same
  `SelectableSurface`.

Review checks the code for other focus looks.
