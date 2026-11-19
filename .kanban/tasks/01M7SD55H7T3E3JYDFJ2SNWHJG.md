---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7sdbpraqqpp1n06e95vdjrk
  text: |-
    ### implement — changed
    - Fix: the `@` opening of `AtReferenceSource.tokenOpenings` has `body: .nonWhitespace` (EditorKit `CompletionTokenOpening.Body`). The default `.word` stops at `-`.
    - Tests: `anAcceptedHyphenatedMentionReplacesTheWholeToken` (typed `@default-` and `@default-2`) failed before the fix (text was not `ask @default-2 `) and passes after it.
    - Discovery: `anAcceptedHyphenatedFileReplacesTheWholeToken` (`@my-` and `@my-no` to `my-notes.txt`) passed before the fix. File rows already replace the whole token. The test stays as a guard.
    - evidence: swift test 1426 tests in 165 suites pass, and 54 tests in 11 suites pass; IntegrationTests `swift build --build-tests` complete; swift format lint gives no new findings (only findings that HEAD has).
    - Not done in this step: push and send the sha to testudoapp-9a. The dispatcher said do not commit or push.
    - next: review
  timestamp: 2026-11-19T08:04:23.946927+00:00
- actor: claude-code
  id: 01m7sddy723d42hwr2taqj2kdy
  text: |-
    ### test — green
    - evidence: swift test at package root. "Test run with 1426 tests in 165 suites passed after 32.800 seconds." "Test run with 54 tests in 11 suites passed after 0.017 seconds." Exit code 0. No failures, no skips.
    - lint: swift format lint -s on ComposerMentions.swift and ComposerMentionsTests.swift. The findings are the same 5 plus 5 as at HEAD (LineLength and AddLines). Only the line numbers moved. No new finding.
    - not run: IntegrationTests and ScreenshotTests (they take the screen focus).
    - next: review.
  timestamp: 2026-11-19T08:05:37.122097+00:00
- actor: claude-code
  id: 01m7sdkpfm3j8nfbjntxg1bqvf
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (4a50ce0b). 1 finding (1 confirmed, 1 refuted). Tests/AgentViewKitTests/Input/ComposerMentionsTests.swift:138 (reuse/reuse).
    - next: implement the finding. Give `fixture(_:files:sources:)` a `fileSystem:` parameter, and use it in the new file-accept test. Then run `swift test` and review again.
  timestamp: 2026-11-19T08:08:45.812043+00:00
- actor: claude-code
  id: 01m7sdm72vpsq3kt847cmahtb8
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — ComposerMentions.swift (@ opening body .nonWhitespace), ComposerMentionsTests.swift
    - test: green — swift test, 1426 tests in 165 suites + 54 tests in 11 suites passed
    - commit: 4a50ce0b
    - review: findings — ComposerMentionsTests.swift:138 (reuse)
  timestamp: 2026-11-19T08:09:02.811009+00:00
- actor: claude-code
  id: 01m7sdsqzyfkgs0cmrgwx80xxh
  text: |-
    ### implement — changed
    - evidence: Tests/AgentViewKitTests/Input/ComposerMentionsTests.swift. `fixture(_:files:sources:fileSystem:)` has an optional `fileSystem:` parameter (default `FileReferenceSourceTests.fileSystem`). The hyphenated file test calls `Self.fixture(typed, sources: [], fileSystem: files)`. No other copy of the wiring is in the new tests of this task. `swift test`: 1426 tests in 165 suites pass, and 54 tests in 11 suites pass. `swift format lint -s`: the same 5 findings as HEAD, no new finding. The one build warning is from the mlx dependency bundle, not from this code.
    - next: review
  timestamp: 2026-11-19T08:12:03.966497+00:00
- actor: claude-code
  id: 01m7sdvvs2hsdabyem9h8fdz1w
  text: |-
    ### test — green
    - evidence: `swift test` at package root, exit 0. "Test run with 1426 tests in 165 suites passed after 25.137 seconds." "Test run with 54 tests in 11 suites passed after 0.008 seconds." No failures. No skips.
    - lint: `swift format lint -s Tests/AgentViewKitTests/Input/ComposerMentionsTests.swift` gives 5 errors (LineLength x4, AddLines x1). The same 5 errors are in the HEAD version of the file (checked with `git show HEAD:` into a scratch file). The change of this task adds 0 new lint errors. The 5 lines are old lines that this task did not change.
    - next: review. A person must decide if the 5 old lint errors need a fix.
  timestamp: 2026-11-19T08:13:13.378225+00:00
position_column: doing
position_ordinal: '80'
title: '@ mention accept replaces only the part after a hyphen (D199)'
---
Bug report from testudoapp-9a (2026-11-19, TestudoApp UI test run; result bundle /Users/wballard/github/swissarmyhammer/TestudoApp/.build/app/OpenTestudo-sel.xcresult).

Now: in `AtReferenceSource.tokenOpenings` (Sources/AgentViewKit/Input/ComposerMentions.swift:165) the `@` opening uses the default `.word` body, which stops at `-`. Thus to accept `@default-2` replaces only `2`, and the text becomes `@-@default-2`. `body(at:)` already reads the whole run of characters that are not white space.

Do:
- Give the `@` opening `body: .nonWhitespace`, so that the replaced range is the whole token after `@`.
- Check the file-reference path (`@file` rows) too: a file name with `-` or `.` must also replace the whole token.
- TDD unit test: accept a mention row for a token with a hyphenated slug (for example `@default-2`, typed as `@default-` and as `@default-2`) gives `@default-2 ` with no copy of the text before the hyphen. Add the same test for a file name with a hyphen.

Run `swift test`. Push, and send the sha to testudoapp-9a.

## Review Findings (2026-11-19 02:06)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 2 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Tests/AgentViewKitTests/Input/ComposerMentionsTests.swift:138` `reuse/reuse` — The new file-accept test builds its own CompletionFixture instead of extending the existing `Self.fixture` helper. The helper is a near-match: it already builds the same `@` source stack, but it hardcodes `FileReferenceSourceTests.fileSystem` and cannot take the in-memory file system this test needs. The parallel construction duplicates the fixture wiring, and the copy already differs from the helper (it drops `SlashCommandSource`). If the helper took a file system parameter, the test would not need its own copy. Give `fixture(_:files:sources:)` an optional `fileSystem:` parameter that defaults to `FileReferenceSourceTests.fileSystem`, then call `Self.fixture(typed, sources: [...], fileSystem: files)` from the new test. Keep it a single fixture path.
