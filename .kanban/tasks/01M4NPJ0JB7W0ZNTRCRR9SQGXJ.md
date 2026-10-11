---
assignees:
- claude-code
depends_on:
- 01M4NPHNFGP5JDZS02XHHE6BE3
position_column: todo
position_ordinal: '8380'
title: 'SF Symbols: rendering mode, symbol effects, scalable usage ring, and accessibility text'
---
## What
An audit on 2026-10-11 found differences in how symbols are drawn, and missing accessibility text. Paths are below `Sources/AgentViewKit/` unless stated.

## Work
- [ ] Use the same rendering mode for the tool call, timeline and diff icons as for the other views (`.hierarchical` in ErrorView, StatusBar, SessionNoticeBanner, TaskListView, CompactionEntryView).
- [ ] A running tool call shows a spinner and a pulsing symbol at the same time (`Items/ToolCallView.swift:389`, `:396`). Keep one.
- [ ] `circle.dotted` (`Status/TaskListView.swift:199`) never shows, because a `ProgressView` replaces it. Remove the dead name or use it.
- [ ] Give the running and replaying banners a symbol effect (`Status/StateBanner.swift:164`, `Status/SessionStreamBanner.swift:146`). Turn the effect off under Reduce Motion, as `ToolCallView.swift:398` does.
- [ ] Usage ring: replace the drawn 16 pt ring (`Status/UsageRingView.swift:25`, `:139-145`) with a view that scales with the text size (for example a `Gauge` or a variable-value symbol). Give it an accessibility label (`:128` has a value and a hint only). Show the full state with a signal that is not only the failure color (`:151`).
- [ ] Elicitation radio buttons: localize the accessibility value "selected", or use `Picker` with `.radioGroup` (`Elicitation/ElicitationFieldViews.swift:625-640`).
- [ ] Demo: use the theme color in place of `.red` (`Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift:352`).
- [ ] Tests for each change.