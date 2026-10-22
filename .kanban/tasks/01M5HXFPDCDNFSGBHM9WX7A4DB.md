---
assignees:
- claude-code
depends_on:
- 01M5HXESH97KEWN99B5M1DSRZ2
- 01M5HXEYDEHRNJMA657BBYFN3T
- 01M5HXF3GSNBTTYA4AR18B2DE3
- 01M5HXF83SCATJDWEPBW648FVD
- 01M5HXFDTZHPHP89NQDRGQNVWG
- 01M5HXFH8JWZX1DWXNKMZWHNBV
position_column: todo
position_ordinal: a580
title: 'AVK-14g Structure test: each view file has a #Preview, or an allow-list entry with a reason'
---
## Goal

Keep the preview coverage complete. A new view with no `#Preview` must make a test fail.

## Change

- [ ] Add a structure test in `Tests/PackageStructureTests`. It finds each file in `Sources/AgentViewKit` that declares a type that conforms to `View`. Each such file must contain `#Preview`, or be in an allow list.
- [ ] The allow list holds each file with a reason. The start list is the views that have no look of their own: `Theme/FloatingGlassContainer.swift` (a container), `Accessibility/ThreadAccessibility.swift` (`SessionAnnouncementObserver`), `Content/MathMarkdownParser.swift` (`MathSpanAccessibility`) and `Citations/CitationProse.swift` (`InlineCitationAccessibility`).
- [ ] A test fails if a file on the allow list gets a `#Preview` or no longer declares a view, so that the list stays exact.
- [ ] Use the shared helpers: `CodeForm.swift`, `SourceLineScanner` and the fixture pattern (a clean fixture and a violating fixture).
- [ ] Do a mutation check: remove one `#Preview`, confirm that the test fails, then put it back.

## Order

Do this card after AVK-14a to AVK-14f. Until they are done, this test fails for their files.

## Rules

- Write the test and comments in ASD-STE100 Simplified Technical English.
- The full suite passes with the window monitor. #avk-14