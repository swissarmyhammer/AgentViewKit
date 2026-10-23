---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5k2jevt241spddcv83k1zhr
  text: 'Research: `Tests/PackageStructureTests/PreviewCoverageTests.swift` already exists (from ^84a4nr5). It checks only PUBLIC views, and checks that a preview body names each one. This card is a separate per-file check over every type (internal too) in `Sources/AgentViewKit` that conforms to `View`. A survey of the 92 files in `Sources/AgentViewKit` that declare a View found exactly 4 with no `#Preview`, the card''s 4: Theme/FloatingGlassContainer.swift, Accessibility/ThreadAccessibility.swift, Content/MathMarkdownParser.swift, Citations/CitationProse.swift. No source uses `extension X: View` or a `where … : View` clause. The shared pattern to follow is ContentFillTests: a form enum that conforms to SampledCodeForm + FixtureCodeForm, scan `.text` (SourceLineScanner.codeMatchStarts blanks comments and string literals), Fixtures/<Name>/{Clean,Violating}. The PackageStructureTests target excludes `Fixtures`, so fixture files do not compile. The allow list must stay exact: each listed file must still declare a view and have no `#Preview` (the ContentFillTests.eachAllowedFileUsesItsForm pattern, which reads the file through ThreadBottomBarStructureTests.code(of:)).'
  timestamp: 2026-10-23T00:29:00.666407+00:00
- actor: claude-code
  id: 01m5k34he2fxngcsg74t5025hs
  text: |-
    Implementation landed. New suite `ViewPreviewTests` (Tests/PackageStructureTests/ViewPreviewTests.swift) with a `ViewPreviewForm` enum (`viewDeclaration`, `preview`) that conforms to SampledCodeForm + FixtureCodeForm and scans with `CodeScan.text`, so SourceLineScanner.codeMatchStarts blanks the comments and string literals. The declaration pattern finds struct/class/enum/actor/extension with `View` or `SwiftUI.View` in the list of conformances, also when the list continues on the next lines. It skips a generic constraint (`<Content: View>`), a `where` clause, `ViewModifier`, `protocol X: View` and `View.Body`. Fixtures: Fixtures/ViewPreview/Clean/ViewPreviewInText.swift and Violating/{NoPreview,WithPreview,NotAView}.swift. The exactness test is `eachAllowedFileDeclaresAViewAndHasNoPreview`.

    Discovery: the scan found a 5th file with no preview that the card's list did not name: `Infrastructure/PreviewSymbolSheet.swift` (added by AVK-14f ^mzwhnbv). An earlier rg survey missed it because of its generic clause. It has a look of its own (a title, then a grid of icon and name rows), so it got a preview, NOT an allow-list entry. The new fixture `PreviewFixtures.statusSymbolNames` (the 8 status symbols of SharedSymbol) came with a test written first, `theStatusSymbolNamesAreDifferentSystemSymbols`, which checks that the names are not empty, that each is different, and that NSImage resolves each one. It failed to compile on the missing member (RED), then passed. The preview uses `DecorativeSymbolImage`, so no raw `Image(systemName:)` goes into the kit. The allow list holds exactly the card's 4 files.

    RED for the structure test: with an empty allow list, `eachViewFileOfTheKitHasAPreview` failed and the fixture and pattern tests passed.

    Mutation checks: (1) I removed the `#Preview` from Items/ToolStatusImage.swift. `eachViewFileOfTheKitHasAPreview` failed with missing == ["Sources/AgentViewKit/Items/ToolStatusImage.swift"]. I restored it, and git shows no diff. (2) I put Items/ToolStatusImage.swift (which has a preview) on the allow list. `eachAllowedFileDeclaresAViewAndHasNoPreview` failed with "Sources/AgentViewKit/Items/ToolStatusImage.swift has a #Preview". I reverted it. That failure also dumped the whole Regex DSL tree, so the test now binds `declaresAView`/`hasAPreview` before `#expect`.
  timestamp: 2026-10-23T00:38:53.122934+00:00
- actor: claude-code
  id: 01m5k34q47nftxhyz2y0atjzft
  text: |-
    ### implement — changed
    - evidence: 9 files. New: Tests/PackageStructureTests/ViewPreviewTests.swift, Fixtures/ViewPreview/Clean/ViewPreviewInText.swift, Fixtures/ViewPreview/Violating/{NoPreview,WithPreview,NotAView}.swift. Modified: Sources/AgentViewKit/Infrastructure/PreviewSymbolSheet.swift (new #Preview), Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift (`statusSymbolNames`), Tests/AgentViewKitTests/Infrastructure/PreviewFixturesTests.swift (1 new test). Allow list = the card's 4 files, no additions; PreviewSymbolSheet.swift (not on the card's list) got a preview instead. Mutation check: removing ToolStatusImage's #Preview failed eachViewFileOfTheKitHasAPreview naming that file; restored byte-identical. Full `swift test` exit 0: 1675 tests in 205 suites passed (3 known issues, the existing withKnownIssue tests), 227 tests in 30 suites (PackageStructureTests) passed, 1 ReadmeSnippets test passed; 0 failures. The only warning is the existing mlx-swift "missing creator" SwiftPM notice.
    - next: /review
  timestamp: 2026-10-23T00:38:58.951013+00:00
- actor: claude-code
  id: 01m5k39tpa6t90t04qhpa9h7ar
  text: |-
    ### test — green
    - evidence: `swift test` after touching PreviewFixtures.swift and PreviewSymbolSheet.swift (AgentViewKit recompiled, no project warnings; only the known mlx-swift "missing creator" notice). XCTest: 0 tests, 0 failures. Swift Testing: 1 test in 1 suite passed; 227 tests in 30 suites passed (includes ViewPreviewTests suite); 1675 tests in 205 suites passed. 0 failures, 0 skipped. The 3 "known issues" are pre-existing withKnownIssue tests that assert deliberate failures (SnapshotStoreTests, HostedLayoutExpectationsTests, ThemeHeightExpectationsTests). theStatusSymbolNamesAreDifferentSystemSymbols passed.
    - next: review
  timestamp: 2026-10-23T00:41:46.442321+00:00
depends_on:
- 01M5HXESH97KEWN99B5M1DSRZ2
- 01M5HXEYDEHRNJMA657BBYFN3T
- 01M5HXF3GSNBTTYA4AR18B2DE3
- 01M5HXF83SCATJDWEPBW648FVD
- 01M5HXFDTZHPHP89NQDRGQNVWG
- 01M5HXFH8JWZX1DWXNKMZWHNBV
position_column: doing
position_ordinal: '8380'
title: 'AVK-14g Structure test: each view file has a #Preview, or an allow-list entry with a reason'
---
## Goal

Keep the preview coverage complete. A new view with no `#Preview` must make a test fail.

## Change

- [x] Add a structure test in `Tests/PackageStructureTests`. It finds each file in `Sources/AgentViewKit` that declares a type that conforms to `View`. Each such file must contain `#Preview`, or be in an allow list.
- [x] The allow list holds each file with a reason. The start list is the views that have no look of their own: `Theme/FloatingGlassContainer.swift` (a container), `Accessibility/ThreadAccessibility.swift` (`SessionAnnouncementObserver`), `Content/MathMarkdownParser.swift` (`MathSpanAccessibility`) and `Citations/CitationProse.swift` (`InlineCitationAccessibility`).
- [x] A test fails if a file on the allow list gets a `#Preview` or no longer declares a view, so that the list stays exact.
- [x] Use the shared helpers: `CodeForm.swift`, `SourceLineScanner` and the fixture pattern (a clean fixture and a violating fixture).
- [x] Do a mutation check: remove one `#Preview`, confirm that the test fails, then put it back.

## Order

Do this card after AVK-14a to AVK-14f. Until they are done, this test fails for their files.

## Rules

- Write the test and comments in ASD-STE100 Simplified Technical English.
- The full suite passes with the window monitor. #avk-14