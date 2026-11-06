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
position_column: todo
position_ordinal: '80'
title: 'Session crumbs and overflow menu: decide their EK menu component'
---
^5a173ex moved the children menu of `SessionBreadcrumb` onto EK `EditorMenuButton`. The crumbs of the sessions and the "…" overflow still use the shared `dropdown`: a raw SwiftUI `Menu` with `.menuStyle(.borderlessButton)`, `.menuIndicator(.hidden)` and a custom label (headline title that truncates in the middle, plus a warning mark).

`EditorMenuButton` takes a caption and a symbol only and hides the whole caption when squeezed, while a crumb is a session title with no symbol that truncates by design (`AgentInfoHeaderBreadcrumbHostedTests.aLongCrumbTruncatesInANarrowPane`, D142). The rule "buttons collapse, never clip" and per-call menu styling both apply.

- [ ] Decide the crumb component: an EK titled menu (crumb) component in EditorKit, or `EditorMenuButton` for the overflow ("More of the path", ellipsis symbol) and an EK crumb for the session crumbs
- [ ] Drop the per-call menu styling from `SessionBreadcrumb.dropdown`
- [ ] Hosted tests through accessibility: each crumb is one element and opens its menu through `.showMenu`