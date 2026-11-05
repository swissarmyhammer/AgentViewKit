---
assignees:
- claude-code
position_column: todo
position_ordinal: 8d80
title: Audit AVK for text built in code; move it to format strings or templates
---
User direction (2026-11-05): text assembled in code is wrong. "swift damned well has format strings", "there are certainly template libraries that can be used too … in fact we are using template libraries for our skills" (Stencil is in the graph via FoundationModelsSkills).

## Rule
- **Short display text:** ONE localized catalog format string with Foundation `FormatStyle`s interpolated (Date, Duration, number, list). Separators, order and wording live in the catalog.
- **Longer or structured text** (multi-part summaries, descriptions, anything with conditions or loops, and any text sent to an agent): a template, using Stencil like the skills packages do, rendered from a model. Never concatenate in code.
- If an EK view assembles text by hand, report it to editorkit-b5; don't patch EK.

## What
- Grep Sources/ for string building:
  - `+` on String or Text;
  - `"\(a) \(b)"` with literal separators;
  - `joined(separator:)` for display text;
  - `Text(...) + Text(...)`;
  - hand-written plurals.
- Classify each as a format string, a template, or fine (an id or key, not display text).
- Fix the display cases, adding catalog entries with comments and removing dead strings.
- The timing line is card ^b59f4y; skip it here.

## Tests
- [ ] Text tests for each converted site with a fixed locale. Drive through accessibility; no mouse, no focus stealing.
- [ ] Full AVK suite green.