---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m81j7rmjc3cw9fkbxppf9qbv
  text: |-
    User approval (2026-11-21, relayed by the orchestrator): MarkdownFence uses the shared CodeFenceLine reader and accepts only a backtick run. Delete MarkdownFence.backtickRun(_:) and its two constants. The behavior does not change: a tilde line is not a fence for MarkdownFence, and the citation paragraph numbers do not change.

    Note: the earlier sentence "Do not change MarkdownFence" was an agent rule, not a user decision.

    Research: MarkdownParagraphs.Builder is the only caller of MarkdownFence.opening(_:), MarkdownFence.closes(_:_:) and MarkdownFence.Opening. No test uses MarkdownFence directly. CodeFenceLine.opening(_:) already rejects a backtick info string that holds a backtick, and CodeFenceLine.closes(_:_:) already requires the same run character as the opening. Thus MarkdownFence.Opening can hold one CodeFenceLine.Opening, opening(_:) keeps only a backtick run, and closes(_:_:) forwards to CodeFenceLine.closes(_:_:). A tilde line then cannot open a fence and cannot close a backtick fence.
  timestamp: 2026-11-22T12:03:33.138059+00:00
- actor: claude-code
  id: 01m81jh48zsh9npjecahx1rmvc
  text: |-
    TDD record. (1) New test MarkdownParagraphsTests.aTildeFenceIsProseForTheParagraphIndex passed on the old code, as a behavior guard must. (2) MarkdownFence moved to CodeFenceLine with no backtick filter: the new test failed (the tilde lines became one fence paragraph). This proves that the test catches a tilde fence. (3) The backtick filter was added to MarkdownFence.opening(_:): green. closes(_:_:) forwards to CodeFenceLine.closes(_:_:), which requires the same run character, so a tilde line also cannot close a backtick fence. MarkdownFence.Opening now holds one CodeFenceLine.Opening (field `line`). backtickRun(_:), maximumIndent and minimumLength are deleted. The CodeFenceLine doc comment now names MarkdownFence as a second user.

    Note: each build prints the SwiftPM build-system line "warning: missing creator for mutated node: ...mlx-swift_Cmlx.bundle/Contents/MacOS". It comes from the mlx-swift dependency bundle, not from source code. The compiler gives 0 warnings.
  timestamp: 2026-11-22T12:08:39.967272+00:00
- actor: claude-code
  id: 01m81jh6wzfzpxvarya2sqdfhw
  text: |-
    ### implement — changed
    - evidence: 3 files — Sources/AgentViewKit/Content/MarkdownFence.swift, Sources/AgentViewKit/Content/MarkdownCodeFences.swift (doc comment), Tests/AgentViewKitTests/Content/MarkdownParagraphsTests.swift. `swift test` (root): 1609 tests in 183 suites passed, plus 54 tests in 11 suites passed, 0 failures. `swift build --build-tests` in IntegrationTests and ScreenshotTests: Build complete. `swift format lint --strict` on the 3 files: exit 0.
    - next: /review
  timestamp: 2026-11-22T12:08:42.655951+00:00
position_column: doing
position_ordinal: '80'
title: MarkdownFence uses the fence run of CodeFenceLine, so the two fence scanners have one run rule
---
## What
`MarkdownFence` (`Sources/AgentViewKit/Content/MarkdownFence.swift`, the fence rules of `MarkdownParagraphs` for the paragraph index of a `CitationMarker`) and `CodeFenceLine` (`Sources/AgentViewKit/Content/MarkdownCodeFences.swift`, task ^4g2xbx1) both read the indent and the fence run at the start of a line. `MarkdownFence.backtickRun(_:)` is a near copy of `CodeFenceLine.run(in:)`: the same indent limit (3), the same minimum run (3), and the same "nothing but whitespace after a closing run" rule. Only the fence characters are different (`MarkdownFence` knows only backticks). If one copy changes, the other can drift.

Task ^4g2xbx1 did not change `MarkdownFence`, because of the sentence "Do not change MarkdownFence or the citation paragraph numbers." That sentence was an agent rule, not a user decision.

## User Approval
2026-11-21: the user approved this task. `MarkdownFence` uses the shared `CodeFenceLine` reader and accepts only a backtick run. Delete `MarkdownFence.backtickRun(_:)` and its two constants. The behavior does not change: a tilde line is not a fence for `MarkdownFence`, and the citation paragraph numbers do not change.

- [x] Make `MarkdownFence.opening(_:)` and `MarkdownFence.closes(_:_:)` use `CodeFenceLine` and accept only a backtick run. Delete `MarkdownFence.backtickRun(_:)` and its two constants.
- [x] Do not change the behavior: a tilde line is still not a fence line for `MarkdownFence`, and the paragraph numbers of citations do not change.

## Acceptance Criteria
- [x] The current tests of `MarkdownParagraphs`, `MarkdownFence` and the citations pass with no change.
- [x] A new test: a tilde fence is not a fence of `MarkdownParagraphs` (it stays prose for the paragraph index).

## Tests
- [x] Run `swift test` in the repo root. Expected: all tests pass, 0 failures.

## Workflow
- Use `/tdd`. The user approved the change on 2026-11-21 (see User Approval).