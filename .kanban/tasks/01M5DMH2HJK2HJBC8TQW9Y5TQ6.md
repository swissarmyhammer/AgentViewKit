---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5e8e1hckbapd1j2ej67m82t
  text: |-
    ### plan update for D111 step 7 (TestudoApp 1c6c202)
    D111 (7): "`.tint` only on the primary action." This card plans `materialLevel.glass.tint(accent)` on each floating glass for the `.tinted` test look. That is the `Glass.tint(_:)` API, not the `.tint(_:)` view modifier, and it is only a test seam for the system Tinted look. It is open question 7 on ^b316bqv. Do this card as written. If the person says that the rule covers `Glass.tint`, change only the doc comment, not the seam. AVK-8t (^78jx8yr) does not report `glass.tint(`.
  timestamp: 2026-10-21T03:35:15.244706+00:00
- actor: claude-code
  id: 01m5e8z6cwpea70qvcrbaq390r
  text: 'Closed as replaced by D113 (testudoapp-4c), answers 3 and 6. The Clear and Tinted looks are system settings. The kit must not copy them: the floating glass is always `.regular`, and no glass gets `Glass.tint(_:)`. A test cannot turn the system setting on deterministically, so the check of the two looks is the manual screenshot check of AVK-8u (^8q34yt8). No source or test file changed for this card: the planned `AgentGlassLook` value was never written, and `Sources/AgentViewKit` has no `Glass.tint` today. AVK-8p (^gqztxta) no longer depends on this card. AVK-8t (^78jx8yr) guards against a new `Glass.tint`.'
  timestamp: 2026-10-21T03:44:37.276092+00:00
depends_on: []
position_column: done
position_ordinal: ffff8880
title: 'AVK-8a1 Replaced by D113: no kit environment value for the glass look (Clear or Tinted), and no Glass.tint'
---
## Status: replaced by D113 answer 6. No work to do.

## Old plan

AVK-8a (^dbbyg9w) found that SwiftUI has no API for the Clear or Tinted look of the system setting. The old plan was a public `AgentGlassLook` environment value, and `materialLevel.glass.tint(accent)` on all floating glass for the Tinted look, as a test seam for AVK-8p.

## Why it is replaced

D113 answer 6 (testudoapp-4c): "Remove `Glass.tint(accent)` everywhere. The Tinted look is a system setting; the kit must not copy it. A test cannot turn the system setting on deterministically, so the Tinted check is the manual screenshot check (AVK-8u)." `style.md` "Tint": "No glass gets `Glass.tint(_:)` for the Tinted look."

D113 answer 3: "Floating glass is always `.regular`. The Clear look is a system setting that the system applies to `.regular` glass, so a theme does not select the variant." Thus the kit also has no value for the Clear look.

## Result

- [x] No `AgentGlassLook`, no `\.agentGlassLook`, no `agentGlassLook(_:)`.
- [x] No `Glass.tint(_:)` in `Sources/AgentViewKit`. A search on 2026-10-20 found none: no code to remove. AVK-8t (^78jx8yr) adds a guard so that none comes.
- [x] AVK-8p (^gqztxta) tests only Reduce Transparency and Increase Contrast. The Tinted look and the Clear look are checks of AVK-8u (^8q34yt8). #avk-8