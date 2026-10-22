---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5jjxhx7crfarx85pqdwf200
  text: 'Research: following 5771ed6 (^m1dsrz2) — previews sit at the end of each view file and read values from PreviewFixtures; each new fixture gets a PreviewFixturesTests test. Findings: TextBlockView has no citation input (it passes only markdown to ResponseView), so its citation is a Markdown quote that cites its source; MarkdownProse takes [CitationPlacement], which PreviewFixtures.citations.placementsByParagraph() gives for citedResponse. The exit model has a signal: TerminalView.ExitSummary (.code / .signal / .unknown) with label, symbolName and outcome — the same inputs TerminalView''s footer passes to OutputExitLabel. OutputCapRow takes CommandOutputView.VisibleRows(output:limit:). EditorKitDiffRenderer.diff(of:file:) parses with EditorDiff, so the tests can count DiffLine kinds. ResourceBlockView reads raw JSON members (uri, mimeType, text, blob); the blob chip writes no file. Swiftlint no_magic_numbers applies to Sources (previews too): only 0, 1, -1, 100 inline.'
  timestamp: 2026-10-22T19:55:27.015371+00:00
- actor: claude-code
  id: 01m5jke69ja4a7k51tmfcrh1xh
  text: |-
    ### implement — changed
    - evidence: 7 files — Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift (formattedMarkdown, citedQuote, longParagraph, citationPlacements, text/binary/long-URI resources, small/large/added-only/removed-only patches, cappedOutputRows, exitSummaries; concurrencySourceURL extracted so citations and citedQuote share it), Content/Blocks/TextBlockView.swift (3 previews), Content/MarkdownProse.swift (4), Content/Blocks/ResourceBlockView.swift (3), Diff/DiffRendererSlot+EditorKit.swift (4), Content/OutputChrome.swift (2), Tests/AgentViewKitTests/Infrastructure/PreviewFixturesTests.swift (+13 tests). RED seen (fixtures missing), then GREEN: PreviewFixturesTests 36/36. Full `swift test`: exit 0 — 1620 tests/201 suites passed (3 known issues, pre-existing), 219/29 passed, 1/1 passed. Only warning is the SwiftPM build-graph note "missing creator for mutated node ... mlx-swift_Cmlx.bundle", from the mlx dependency, not from these files.
    - notes: TextBlockView takes no citations, so its citation preview is a Markdown quote with a source link; MarkdownProse shows real pills via citations.placementsByParagraph(). OutputExitLabel previews use TerminalView.ExitSummary (.code 0, .code 1, .signal SIGTERM). No public API added.
    - next: /review
  timestamp: 2026-10-22T20:04:32.178555+00:00
- actor: claude-code
  id: 01m5jknahs08p4t6er9q9a5qys
  text: |-
    ### test — green
    - evidence: `swift test` — 1620 tests in 201 suites passed, 0 failed, 0 skipped. The 3 "known issues" are the intentional withKnownIssue negative-path tests (SnapshotStoreTests, HostedLayoutExpectationsTests, ThemeHeightExpectationsTests). The only warning is the known SwiftPM mlx-swift "missing creator" notice. After touching the changed Sources and the test file, `swift build --build-tests` recompiled them with zero project-code warnings.
    - next: review/commit
  timestamp: 2026-10-22T20:08:25.913979+00:00
- actor: claude-code
  id: 01m5jktgszrzxbkrt9bp6e46n3
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (ad959a5) — 0 findings, 0 confirmed, 0 refuted; 7 files attempted, 0 failed; 4 .kanban/ files excluded by .reviewignore
    - next: task moved to done
  timestamp: 2026-10-22T20:11:16.159659+00:00
- actor: claude-code
  id: 01m5jktvebxct7ct1d40p0bkny
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 16 previews in TextBlockView, MarkdownProse, ResourceBlockView, DiffRendererSlot+EditorKit and OutputChrome; PreviewFixtures + 13 PreviewFixturesTests (red first)
    - test: green — swift test 1620 passed, 0 failed, 0 skipped; changed files recompiled with 0 project warnings
    - commit: ad959a5 (local, not pushed)
    - review: clean — 0 findings, task in done
  timestamp: 2026-10-22T20:11:27.051216+00:00
position_column: done
position_ordinal: ffffb680
title: 'AVK-14e Add #Preview blocks for the content block views and the command output rows'
---
## Goal

The user examines the look of each component in the Xcode canvas. These content views have no `#Preview`:

- `Sources/AgentViewKit/Content/Blocks/TextBlockView.swift` — `TextBlockView`
- `Sources/AgentViewKit/Content/Blocks/ResourceBlockView.swift` — `ResourceBlockView`
- `Sources/AgentViewKit/Content/MarkdownProse.swift` — `MarkdownProse`
- `Sources/AgentViewKit/Diff/DiffRendererSlot+EditorKit.swift` — `EditorKitDiffRenderer`
- `Sources/AgentViewKit/Content/OutputChrome.swift` — `OutputCapRow`, `OutputExitLabel`

## Change

Add `#Preview` blocks in the same file as each view. Use `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift`, and add to it if a value is missing. Give each preview a name that tells its state.

- [x] `TextBlockView` and `MarkdownProse`: headings, lists, a table, inline code, links, a citation, and a very long paragraph.
- [x] `ResourceBlockView`: a text resource, a binary resource, and a resource with a long URI.
- [x] `EditorKitDiffRenderer`: a small diff, a large diff, a diff that only adds, and a diff that only removes.
- [x] `OutputCapRow`: the row that tells that the output was cut.
- [x] `OutputExitLabel`: exit code 0, a code that is not 0, and a stop by a signal, if the model has it.

The white fill of the EditorKit text area (^m231ph5, stuck) shows in the diff and code previews. Do not try to fix it here.

## Rules

- No new public API. No backward compatibility code (ARCHITECTURE.md).
- The package builds with 0 warnings. The full suite passes with the window monitor. #avk-14