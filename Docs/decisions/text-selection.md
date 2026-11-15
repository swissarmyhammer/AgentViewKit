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

