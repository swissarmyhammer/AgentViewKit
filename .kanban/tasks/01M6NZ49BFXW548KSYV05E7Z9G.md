---
assignees:
- claude-code
position_column: doing
position_ordinal: '9280'
title: Move AVK's hosted tests onto EditorKit's harness.perform(_:on:)
---
EK ^e0jrvyt is on EK origin at 2b0d42e2: `harness.perform(.press | .increment | .custom(name) | .focus | .pick(…), on: id)` in EditorTestSupport. It's headless: no activation, no window brought front, no key window, and menus show for one run-loop turn then close. Its lookup is stricter, requiring exactly one match.

About 42 AVK test files call EK's older `press(identifier:)`, `increment(identifier:)` and `performCustomAction(named:identifier:)`. Those still work and run the same path.

**Order:** start after the accessibility card ^b2h8hpz and the other in-flight cards merge, because they touch the same test files.

## What
- `swift package update` (all dependencies together).
- Rename every call to `perform(_:on:)`. Where the exactly-one-match lookup now fails, fix the duplicate ids in the view, or the test, rather than loosening the lookup.

## Tests
- [ ] The full AVK suite is green, with zero warnings in AVK targets, and no hosted test steals focus.