---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6qdmj9age41e75yreng11f7
  text: Asked EditorKit (editorkit-b5) for a crumb or breadcrumb menu component. It should be one AX element and a jump target, open through `.showMenu`, truncate its title in the middle, take an optional warning mark, have no host styling, and ideally lay out a bar with a "…" overflow. This card waits for its SHA.
  timestamp: 2026-11-06T03:15:03.594881+00:00
- actor: claude-code
  id: 01m6qdn4aaf57bm4x1053qsq8y
  text: |-
    EK is building `EditorBreadcrumbBar`. When it lands, AVK's breadcrumb moves onto it whole:
    - **Crumbs:** each has a localized title, an optional warning or status mark, and a menu builder. It is one AX element and a jump target, and `.showMenu` opens its menu.
    - **Overflow:** the oldest ancestors collapse into a leading "…" crumb. The last crumb never collapses.
    - **Squeezed:** the last crumb's title wraps and the bar grows. Titles never truncate, because a cut-off caption is never acceptable.
    - **Spoken path:** built with ListFormatStyle.

    Replace `AgentInfoHeaderBreadcrumbHostedTests.aLongCrumbTruncatesInANarrowPane` with a test that a squeezed crumb collapses into the overflow and then wraps. This card waits for EK's SHA.
  timestamp: 2026-11-06T03:15:22.058552+00:00
- actor: claude-code
  id: 01m6qhf46f93bvwn4apj6bd2wb
  text: |-
    Research (EK 5fdc7f83):
    - `EditorBreadcrumbBar` has its own collapse into the overflow and its own wrap. AVK's `BreadcrumbSegment`, its `collapsed` flag, the three-shape `ViewThatFits` in `AgentBreadcrumb`, and `dropdown` all go. `BreadcrumbCollapse` was already dead in production (only its tests read it), so it goes too.
    - An EK crumb is labelled with its title only, and the mark's label is its AX value. So the crumb no longer speaks the session state ("Reviewer, In progress"). The warning mark carries `SessionStateText.needsAttention` as the value, and the bar speaks the whole path as its ListFormatStyle label. The sibling menu rows still speak each state. As a result, `SessionBreadcrumb.accessibilityLabel(for:)` goes.
    - The jump segment of a crumb is now EK `breadcrumb:<id>`. `AgentScopeKind.crumb` / `.crumb(_:)` in Commands/AgentCommandPlacement.swift lose their only caller. Commands/ is out of bounds for this card, so their removal goes on a follow-up card.
    - The Children menu stays beside the bar as an `EditorMenuButton`. The bar's crumbs are path crumbs, and a Children crumb would make the shown session collapsible.
  timestamp: 2026-11-06T04:21:59.631807+00:00
- actor: claude-code
  id: 01m6qj8t5s54x4bac3pvam0y8m
  text: |-
    ### implement — changed
    - evidence: commit 145c5cfd on worktree-agent-addaad93593c2d50f. 11 files: Sources/AgentViewKit/Sessions/SessionBreadcrumb.swift, Sources/AgentViewKit/Connections/AgentInfoHeader.swift, Sources/AgentViewKit/Sessions/BreadcrumbCollapse.swift (deleted), Sources/AgentViewKit/Resources/Localizable.xcstrings, ARCHITECTURE.md, Tests/.../SessionBreadcrumbTests.swift, Tests/.../SessionPathAccessibilityTests.swift, Tests/.../BreadcrumbCollapseTests.swift (deleted), Tests/.../ViewValueLayoutTests.swift, IntegrationTests/.../AgentInfoHeaderBreadcrumbHostedTests.swift, IntegrationTests/.../SpokenListLabelsHostedTests.swift.
    - tests: root `swift test` 1055 + 50 passed. IntegrationTests `swift test` 1015 passed (5 known issues, all already there). ScreenshotTests build complete. No AVK warnings.
    - notes:
      - The EK bump to 5fdc7f83 added `EditorStyle.breadcrumbs` and `Buttons.crumbCaptionStyle`, so `ViewValueLayoutTests` now lists them and has a new Breadcrumbs test.
      - `AgentBreadcrumb`'s trailing Spacer became `.frame(maxWidth: .infinity, alignment: .leading)`, so the bar doesn't split the width with the Spacer.
      - The crumb's AX label is now its title alone. The session state is no longer spoken on the crumb.
      - The removal of the dead `AgentScopeKind.crumb` in Commands/ is on follow-up ^gdwdcnj.
    - next: /review
  timestamp: 2026-11-06T04:36:01.337289+00:00
- actor: claude-code
  id: 01m6qjy4dxaw8m7cd53v8s22ev
  text: |-
    ### implement — changed
    - finding: `SessionBreadcrumb.swift:62` completeness: the body always drew the leading disclosure separator. So when the header showed the agent alone, a stray chevron and an empty `EditorBreadcrumbBar` appeared after the agent name.
    - fix: `AgentBreadcrumb.body` now mounts `SessionBreadcrumb` only for a non-empty path (`else if !path.isEmpty`), so the rule lives in one place. New hosted test `theAgentAloneShowsNoBreadcrumbBar` checks there is no `session-breadcrumb` element. It failed before the fix and passes after.
    - evidence: f11836ec, on top of main (fast-forwarded to ef509eb0). Root `swift test` 1070 + 50 passed. IntegrationTests 1026 passed with 5 known issues, all already there. No AVK warnings.
  timestamp: 2026-11-06T04:47:39.965186+00:00
position_column: done
position_ordinal: ffffffbe80
title: 'Session crumbs and overflow menu: decide their EK menu component'
---
^5a173ex moved the children menu of `SessionBreadcrumb` onto EK `EditorMenuButton`. The crumbs of the sessions and the "…" overflow still use the shared `dropdown`: a raw SwiftUI `Menu` with `.menuStyle(.borderlessButton)`, `.menuIndicator(.hidden)` and a custom label (headline title that truncates in the middle, plus a warning mark).

`EditorMenuButton` takes a caption and a symbol only and hides the whole caption when squeezed, while a crumb is a session title with no symbol that truncates by design (`AgentInfoHeaderBreadcrumbHostedTests.aLongCrumbTruncatesInANarrowPane`, D142). The rule "buttons collapse, never clip" and per-call menu styling both apply.

- [x] Decide the crumb component: an EK titled menu (crumb) component in EditorKit, or `EditorMenuButton` for the overflow ("More of the path", ellipsis symbol) and an EK crumb for the session crumbs
- [x] Drop the per-call menu styling from `SessionBreadcrumb.dropdown`
- [x] Hosted tests through accessibility: each crumb is one element and opens its menu through `.showMenu`