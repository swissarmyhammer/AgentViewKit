---
assignees:
- claude-code
position_column: todo
position_ordinal: 8c80
title: 'Inspector path rows for lists: ToolCallEntry locations and SessionModel additional directories (needs an EK list-of-paths kind)'
---
Found in ^hpxbqhx (2026-11-04). EK's inspector has a `.path` kind for one `URL` (`Field` with `Value == URL`, a `PathChip`), but no kind for a list of URLs. An `Inspection` is static, so AVK cannot make one row per location or per directory, and style.md ("The inspector") forbids a host drawing its own row.

Two waiting rows of ^e4857xj therefore still wait:
- `ToolCallEntry.locations: [ToolCallLocation]` (each a path and an optional line).
- `SessionModel.additionalDirectories: [AbsolutePath]` (folders).

The single-path rows are done in ^hpxbqhx: the working directory of `TerminalEntry` and `SessionModel` (`InspectionPath.workingDirectory`).

## What
- Ask EK (editorkit-b5) for a list-of-paths field kind, for example `Field` with `Value == [URL]` drawing one `PathChip` per URL in a wrapping row, with an optional line per entry for tool call locations, and Mixed for differing lists.
- Once it lands: add a Locations row to the ToolCallEntry inspection and an Additional Directories row to the SessionModel inspection, and drop `InspectionText.location(_:)` if the new kind covers the `path:line` text.
- Decision needed if EK declines: show the first location only, or a text row.

## Tests
- [ ] Unit: each row is of the new kind (as InspectionPathTests does for `.path`).
- [ ] Hosted: each row shows its paths (ClientModelInspectionHostedTests).
- [ ] Gallery: the inspector images of ToolCallEntry and SessionModel show the rows, light and dark.