---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5e95xbja12brmkype2e5rne
  text: |-
    ### decision (testudoapp-4c, style.md "How the steps apply") — this answers the minimap question
    - A user tick is `.primary`. An agent tick is `.secondary`. Only the current item uses the accent.
  timestamp: 2026-10-21T03:48:17.394885+00:00
depends_on:
- 01M5DFBC5CXFEGX6P4XB316BQV
position_column: todo
position_ordinal: ae80
title: 'AVK-8ak Accent in content, part 2: the pending request badge and the minimap user tick do not use editorTheme.accent (PendingRequestCountBadge.swift:82,85, ThreadMinimapView.swift:438) (D113 answer 5)'
---
## Why

D113 answer 5: "In content, the theme accent marks only a link, the selection or the current item." A search on 2026-10-20 found these accent uses in content:

| File:line | Use | D113 |
|---|---|---|
| `Citations/InlineCitation.swift:253`, `:257` | the citation chip is a link (a `Button` that selects its source, `:152`) | permitted (link) |
| `Citations/SourcesView.swift:147` | the highlight of the current source | permitted (current item) |
| `Elicitation/ElicitationLayout.swift:161` | the selected tab | permitted (selection) |
| `Thread/ThreadMinimapView.swift:223` | the band of the visible rows | permitted (current item) |
| `Sessions/PendingRequestCountBadge.swift:82`, `:85` | a count badge: text and capsule fill | NOT permitted |
| `Thread/ThreadMinimapView.swift:438` | the tick of a user message | NOT permitted |

(The decorative symbols are in AVK-8aj.)

## What to do

- [ ] `PendingRequestCountBadge.swift:82`: use `.foregroundStyle(.secondary)`. `:85`: replace the accent capsule fill with `.background(.quaternary, in: Capsule())`, the semantic fill of the other chips of the kit (`Items/ToolCallView.swift:750`). Remove `fillOpacity` if it has no other use.
- [ ] `ThreadMinimapView.swift:436-446`: `.userMessage` must not use `editorTheme.accent`. Use `Color.primary`. If the user tick and the agent tick then look the same, check that `tick.mark` gives them different shapes. If the shapes are the same, write a comment on this card and ask the person; do not choose a new color.
- [ ] Add a code comment at each permitted use in the table above: it names D113 and the reason (link, selection or current item). AVK-8t uses these files as its allow list.

## Acceptance

- A render test of `PendingRequestCountBadge` with `DistinctRolesTheme` finds no pixel of the accent role.
- A unit test of the minimap tick color for `.userMessage` gives `Color.primary` (make `tint(of:)` internal and static if necessary).
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8