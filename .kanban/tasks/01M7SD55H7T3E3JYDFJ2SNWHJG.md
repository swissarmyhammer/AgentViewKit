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