---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6se589q6vkfysgm85816v0e
  text: |-
    ### review — clean
    - evidence: review sha c3569e44..HEAD — 0 findings (attempted 7, confirmed 0, refuted 0, failed 0); 3 files reviewed; SessionTree.md matched no validator; .kanban/ files ignored by .reviewignore
    - next: none — moved to done
  timestamp: 2026-11-06T22:02:39.287782+00:00
position_column: done
position_ordinal: ffffffc480
title: Breadcrumb test and docs follow EK's no-wrap collapse
---
EK ^zeyyr69 (2eb4b01a) changed EditorBreadcrumbBar: a crumb never wraps; a last crumb with no room moves into the overflow, whose menu lists the whole path. AVK CI run 42292592822 fails AgentInfoHeaderBreadcrumbHostedTests.aSqueezedCrumbCollapsesIntoTheOverflowAndThenWraps (lines 216–217), which pinned the old wrap. The docs (SessionTree.md, SessionBreadcrumb, AgentInfoHeader) still say the last crumb wraps.

- [x] Re-pin the hosted test to the new rule (overflow holds root + last crumb; neither shows in the bar)
- [x] Docs say a last crumb without room collapses into the overflow, never wraps