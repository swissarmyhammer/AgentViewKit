---
assignees:
- claude-code
position_column: todo
position_ordinal: a180
title: Mark links and the current item without the theme accent (accent only for selection and focus)
---
User decision (2026-10-24, relayed by kanbanviewkit-84), shared style rules 1 and 2:
- Rule 2, strict: the accent is only for the selection and the focus.
- Rule 1: the accent fill of the citation chip is a permitted exception.

To do:
- `Citations/InlineCitation.swift`: keep the accent fill of the citation chip. Remove any other use of the accent, for example an accent text color.
- `Citations/SourcesView.swift`: a link does not use the accent as its text color. Mark a link in a different way, for example with an underline or a link symbol. The current source has no accent and no fill if it has no focus and is not the selection. If the current source is the selection or has the focus, use the system selection or focus look.
- `Thread/ThreadMinimapView.swift` and `Elicitation/ElicitationLayout.swift`: make sure that each accent read marks only the selection or the focus. If not, change it.
- Remove `Citations/SourcesView.swift` ("the current item") from the allow list of `ContentFillTests`, unless its fill now marks the selection or the focus. Change the reason text in the test to "the selection or the focus".
- `ThemeInjectionTests`: set the permitted accent files and their counts to match. Give the reason of each permitted use: the selection, the focus, or the citation chip fill.

Acceptance:
- A hosted test shows that a link in the sources list has no accent color and has its new mark. Another hosted test shows that a current source with no focus and no selection has no fill.
- `swift test` is green, and the demo builds.
- Re-record only the snapshots whose look changes. List each one by name, with its PNG path. #avk-8