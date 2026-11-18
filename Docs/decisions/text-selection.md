# Text selection

Status: decided. Source: plan.md §9 A, §11 decision 8, §14 research R10.
Task ^h41qtbk. Date: 2026-09-17.
Revision: one selection in the thread. Date: 2026-11-15.

This file records how far a text selection goes in a thread on macOS 27.
The `mode:` line matches `MessageActions.selectionMode`.

mode: `perMessage`

## Probe

The probe was a hosted test in `AgentViewKitTests`. The test was removed after
the run, because the probe is research output and not a criterion.

- A `ScrollView` held a `LazyVStack` with two rows. Each row had a height of
  40 points.
- Variant 1: each row was a Textual `StructuredText`, with
  `.textual.textSelection(.enabled)` on the stack. This is the text path of
  `ResponseView`.
- Variant 2: each row was a SwiftUI `Text`, with `.textSelection(.enabled)` on
  the stack.
- The test sent a mouse down in the first row, ten mouse drags to a point in
  the second row, and a mouse up, to the view at the start point. Then it sent
  `copy(_:)` to the first responder and read the general pasteboard. The test
  kept the pasteboard contents and put them back after the read.

## Result

| variant | view under each row | text of a drag in one row | text of a drag across two rows |
|---|---|---|---|
| Textual `StructuredText` | one `NSTextInteractionView` for each row | `Alpha first` | `Alpha first` (no text from the second row) |
| SwiftUI `Text` | one `AppKitTextInteractionView` for each row | none | none |

- Each row has its own interaction view and its own selection model. A drag
  that starts in one row does not go into the next row.
- The SwiftUI `Text` copy did not write to the pasteboard in the hosted window.
  The views are also one for each row, so the result for that variant is the
  same: no selection across rows.

## Decision

- The kit selects text in one message at a time (`perMessage`). This agrees
  with plan.md §11 decision 8.
- `MessageActions` gives Copy for one message and Copy thread for all
  messages, so that the user can copy text from more than one message.
- Examine this decision again when Textual or SwiftUI gives one selection model
  for more than one view.

## Revision: one selection in the thread (2026-11-15)

### Defect

The user saw two defects in a thread with two responses:

1. A selection in one text area stayed when the user selected text in a
   different text area. The thread showed more than one selection.
2. The user could not select the text of a thought, of a tool result, and of
   some other parts of the transcript.

### Cause

- Textual 0.5.0 gives each `StructuredText` its own selection model and its
  own coordinator (`StructuredText.swift`, `TextSelectionCoordinator.swift`).
  The types are internal. The kit shows one `StructuredText` for each
  paragraph, so each paragraph had its own selection. A click in a
  paragraph clears only the selection of that paragraph.
- Each EditorKit `EditorView` (code block, command output) also has its own
  selection. A SwiftUI `Text` with `.textSelection(.enabled)` has its own
  selection too, and the kit cannot clear it.
- Only `MessageLayout` turned on the Textual selection. A thought, a tool
  result, a session message and an attachment text are not in a
  `MessageLayout`.

### Decision

- A thread has one selection. `ThreadTextSelection` is the coordinator. It
  conforms to the EditorKit `TextSelectionRegion`, and `.threadTextSelection()`
  puts it in the environment (`textSelectionRegion`) of `AgentThreadView`
  and of `ConversationView`, when the environment has no region.
- Each text area is an owner. When the user starts a selection in an area,
  the area claims the selection. The claim clears the selection of the
  previous owner. A claim from the current owner does nothing.
- An EditorKit `EditorView` claims when its text view becomes the first
  responder, and clears with `EditorModel.collapseSelection()`. A code
  block, a command output and each `PreviewField` take part with no other
  change.
- A Textual text takes part through `.selectableTextualRegion()`. The
  modifier turns on the Textual selection, and puts a probe view in the
  background of the text. The probe observes the first responder of its
  window. When the Textual interaction view (`NSTextInteractionView`) in the
  frame of the probe becomes the first responder, the area claims the
  selection. To clear, the area gives the `StructuredText` a new identity
  (`.id(generation)`), because Textual 0.5.0 has no public function that
  clears a selection. The text parses again.
- `MarkdownProse` (each paragraph of a message, a thought, a tool result and
  a session message), `AttachmentTextContent` and `SelectableText` apply the
  modifier. `MessageLayout` does not turn on the selection any more.
- A plain text of the transcript that the user can select is a
  `SelectableText` (plan entry, hunk header, terminal command and working
  directory, sender line of a session message, compaction error, the text of
  a permission or elicitation prompt). JSON (error data, JSON disclosure)
  shows in an EditorKit `PreviewField(.code)`.
- `AgentViewKitStyle` has no Textual. Its selectable text (the explanation of
  a `StatusTitleLayout`) shows in the `SelectableTextStyle` of the
  environment. The thread sets a style that shows a `SelectableText`.
- The kit uses no SwiftUI `.textSelection(.enabled)` in a thread. A unit test
  (`SelectableTranscriptTextTests`) makes sure of this, and makes sure that
  each `StructuredText` applies the region modifier.

### Limits

- A drag selection stays in one text area: one paragraph, one code block or
  one label. It does not go across paragraphs or messages. This needs one
  selection layer for the thread and a change in Textual. It is a
  follow-up. `MessageActions.selectionMode` stays `perMessage`, because a
  selection does not go across messages.
- A clear makes the `StructuredText` again. The text parses again. The kit
  shows the clear only in the area that lost the selection, so the user sees
  no change in the area that has the selection. A Textual change that reads
  the coordinator from the environment removes this. It is a follow-up.
- The probe finds the Textual interaction view by its type name. The pin of
  Textual is exact, so a new pin must check the name
  (`TextualSelectionProbeView.interactionTypeName`).


## Revision: EditorKit labels (2026-11-17)

Task AVK-9.5 (^01M7NEPD). Decision D185: EditorKit renders the text of a
thread, in place of Textual.

### Decision

- Each Markdown text (an answer, a thought, a tool result, a session
  message) is a read-only EditorKit `EditorView` (`RenderedMarkdownView`).
  It claims the selection of the thread for itself.
- Each plain text that the user can select is an EditorKit `EditorLabel`
  (EditorSwiftUI): the plan entry, the hunk header, the terminal command and
  working directory, the sender line of a session message, the compaction
  error, the text of an attachment, and the text of a permission or
  elicitation prompt. The label is light: it has no `EditorModel`. It joins
  the `TextSelectionRegion` of the environment, so a selection in one label
  clears the selection of the area that had it.
- A selectable text of a view that shows on glass and in content (a request
  card, the explanation of a `StatusTitleLayout`) is a `PlacedLabel`
  (`AgentViewKitStyle`): an `EditorLabel` in the text color of its place
  (EditorKit `style.md`, rule 6).
- A right click on a label shows the item menu of the kit (D193 (f)). The
  label adds no menu of its own: its `menu(for:)` gives the menu of the
  nearest view above it that has one.
- The kit removed `SelectableText`, `.selectableTextualRegion()`, the probe
  view of the first responder, the context menu monitor of Textual
  (`TextualContextMenu`), and the `SelectableTextStyle` of
  `AgentViewKitStyle`. The style library shows its selectable text in a
  `PlacedLabel` directly.
- The unit test `SelectableTranscriptTextTests` makes sure that the kit uses
  no SwiftUI `.textSelection(.enabled)`, and that the plain text and the
  Markdown text of an attachment are EditorKit views.

### Limits

- A drag selection stays in one text area: one Markdown text, one code
  block or one label. `MessageActions.selectionMode` stays `perMessage`.
- The label has no line limit and no truncation: its text wraps at the
  proposed width.
- On glass and chrome, a `PlacedLabel` has the vibrant foreground of its
  role (EditorKit `editorLabelForeground(.vibrant(_:))`, D110). Its text
  draws in the system label colors (`NSColor.labelColor`,
  `NSColor.secondaryLabelColor`) with the vibrancy of the glass behind it.
  The label is an AppKit view, so it does not use the SwiftUI hierarchical
  styles (`.primary`, `.secondary`) of the other text on glass. Content text
  keeps the theme colors.
- The Textual limits of the 2026-11-15 revision (the probe of the first
  responder, the new identity that clears a selection, and the type name of
  the Textual interaction view) do not apply any more.
