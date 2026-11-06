---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: Remove the dead AgentScopeKind.crumb scope kind
---
^dax7gt3 moved the session crumbs onto EK `EditorBreadcrumbBar`. Each crumb is now a jump target at EK's `breadcrumb:<sessionId>` (`FocusSegment.editorBreadcrumb(id:)`), not at AVK's `agentCrumb:<sessionId>`.

That left `AgentScopeKind.crumb` (the public `"agentCrumb"` kind) and `AgentScopeKind.crumb(_:)` in Sources/AgentViewKit/Commands/AgentCommandPlacement.swift with no caller. ^dax7gt3 stayed out of Commands/ because other agents were working there in parallel.

- [ ] Delete `AgentScopeKind.crumb(_:)` and its doc
- [ ] Delete the public `AgentScopeKind.crumb` kind once no sibling kit (Testudo) reads it. Check the sibling kits first, because public API removal waits for them
- [ ] Check whether `AgentControlScope`'s free `segment:` init still has a reason to exist, now that `agentControlScope(_:)` is its only caller