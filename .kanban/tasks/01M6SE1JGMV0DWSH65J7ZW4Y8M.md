---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: Breadcrumb test and docs follow EK's no-wrap collapse
---
EK ^zeyyr69 (2eb4b01a) changed EditorBreadcrumbBar: a crumb never wraps; a last crumb with no room moves into the overflow, whose menu lists the whole path. AVK CI run 42292592822 fails AgentInfoHeaderBreadcrumbHostedTests.aSqueezedCrumbCollapsesIntoTheOverflowAndThenWraps (lines 216–217), which pinned the old wrap. The docs (SessionTree.md, SessionBreadcrumb, AgentInfoHeader) still say the last crumb wraps.

- [x] Re-pin the hosted test to the new rule (overflow holds root + last crumb; neither shows in the bar)
- [x] Docs say a last crumb without room collapses into the overflow, never wraps