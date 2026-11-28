---
assignees:
- claude-code
position_column: todo
position_ordinal: 8a80
title: Flat moving rows for diffs, outputs and the other row kinds
---
Follow-up of ^9ync5h3 (2026-11-28). The flat form (`TranscriptFlatRow`) covers user and agent messages (prose and code fences), closed thoughts and closed tool calls. These rows still keep the views of their real row in their static form, so each one builds and measures its real chrome when it comes into a moving list:

- A diff (expanded tool call with a diff): EditorKit has no off-main picture of a diff (only `EditorLayoutMeasure.render(markdown:...)` and `render(code:...)`), so the diff slot shows `StaticCodeText`, and the row has no picture of each text part. Needs EditorKit work: a `render(diff:...)` with the lanes, the change bars and the folds of the diff view.
- An expanded tool call body: the JSON blocks (`Input`, `Output`) have no chrome line, and a command output has no chrome line for its command line and its exit label.
- Terminal, plan, error notice, compaction notice, session message: no chrome line (their rules use lines of views side by side and narrowed labels, which `TranscriptFlatRowPlan` does not place).
- An output with ANSI color runs: no picture (the code picture draws no color run).

## What
- [ ] EditorKit: an off-main picture of a diff, then a picture part for the diff slot.
- [ ] Chrome lines for the body of an expanded tool call (JSON block headers with their titles, the command output header and exit label).
- [ ] Chrome lines (or line placement) for terminal, plan, error, compaction and session message rows.

## Tests
- [ ] For each new kind: a row that enters while moving builds no view of its real row, and a pixel test of the flat row against the real row (light and dark) in the `RowPixels` limits.

#perf