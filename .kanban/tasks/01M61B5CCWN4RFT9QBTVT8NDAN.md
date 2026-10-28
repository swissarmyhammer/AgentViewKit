---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m61npc2dnj93m9fseqbbre19
  text: |-
    ### review — clean
    - evidence: review sha cf88bff..eea49d0 (d19df89, eea49d0; merged as ae52adf) — findings 0, confirmed 0, refuted 1, attempted 7, failed 0. Not reviewed (no validator matches): README.md, Sources/AgentViewKit/Resources/Localizable.xcstrings, plan.md. Tests on main after merge: 282 + 1898 + 37 passed, 0 skipped (mlx-swift_Cmlx dependency warnings excluded by user decision).
    - note: the session model has no stream error besides the resume error, so reload-failed is the only failure message. Stale failure after missed updates clear elsewhere is tracked on its own card.
    - next: none; card moved to done.
  timestamp: 2026-10-28T16:32:33.869833+00:00
position_column: done
position_ordinal: fffff580
title: SessionStreamBanner gets a reload-failed phase and shows the stream error in its explanation, as KVK's stream banner does
---
From kanbanviewkit-2c's audit for ^qpbamj2: KVK's stream banner has a reload-failed phase and shows the stream error inside its explanation. AVK's SessionStreamBanner does neither. Both build on the shared StatusBar and StateBanner.Message (with severity) from AgentViewKitStyle, so the two kits should behave the same.

## Work
- [x] After ^qpbamj2 lands, read KVK's banner logic (../KanbanViewKit, BoardStreamBanner) for the phases and wording
- [x] SessionStreamBanner: when a reload fails, show a reload-failed message with `.failure` severity and the Reload action. Every failure message's explanation includes the stream error's localized description.
- [x] Hosted tests for the reload-failed phase and for the error text in the explanation. Re-record any snapshot that changes.
- [x] `swift test` is green

Order: after ^qpbamj2.