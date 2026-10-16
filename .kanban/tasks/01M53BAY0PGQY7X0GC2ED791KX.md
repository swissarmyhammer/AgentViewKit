---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m53bshfqrr8zzxwayv09gztp
  text: |-
    Research: the kit writes localized text as `String(localized: "...")` with string interpolation for an argument and no bundle and no comment (ElicitationWhoAsks.swift, ElicitationView.swift `failureText(reason:)` and `title(server:)`). ElicitationView.swift `agentServer` uses a `static let` with `String(localized:)`, so the constants stay `static let`. The package has no .xcstrings, .strings or .stringsdict file, Package.swift has no defaultLocalization, and no test checks localized strings. So there is nothing to keep correct and nothing was added.

    Implementation: each constant and each message function of `ElicitationValidator.Message` now uses `String(localized:)`. The functions with a count or a bound interpolate the value, so the key is a format string with the value as an argument (an Int gives `%lld`, the bound text gives `%@`). The English text did not change. `tooShort(_:)` and `tooLong(_:)` have a doc comment: the count is in Unicode code points (`PendingElicitation.codePointLength(_:)`), and the text for the user says "characters". The Message enum doc comment tells that each message is localized.

    TDD note: the behavior did not change, and with no string catalog no test can fail first. The existing tests in ElicitationValidatorTests and ElicitationFieldViewsHostedTests assert each exact English message, so they are the guard.
  timestamp: 2026-10-16T22:02:18.999766+00:00
- actor: claude-code
  id: 01m53bsn50355psd1a9t93pj7k
  text: |-
    ### implement — changed
    - evidence: 1 file — Sources/AgentViewKit/Elicitation/ElicitationValidator.swift. `swift build --build-tests`: Build complete, 0 warnings in Sources/ or Tests/ (1 build-system warning only: "missing creator for mutated node" on .build/out/Products/Debug/mlx-swift_Cmlx.bundle/Contents/MacOS, a dependency bundle). `swift test --skip-build --filter 'ElicitationValidatorTests|ElicitationViewHostedTests'`: 61 tests in 2 suites passed. Full `swift test --skip-build`: XCTest 0 tests; Swift Testing runs of 1 test in 1 suite, 127 tests in 16 suites, and 1293 tests in 151 suites, all passed; 0 failures; 2 known issues (existing `withKnownIssue` tests aWrappedTextWithAFixedVerticalSizeFails and aViewThatIgnoresTheThemeFails). No localized-string test exists.
    - next: review
  timestamp: 2026-10-16T22:02:22.752759+00:00
- actor: claude-code
  id: 01m53bta95c3tga569akn1tm99
  text: |-
    ### test — green
    - evidence: the implement step ran the full suite one time after the change: swift test --skip-build, 1293 tests in 151 suites, 127 tests in 16 suites and 1 test in 1 suite passed, 0 failures, 2 known issues (the same as before). swift build --build-tests: no warning in Sources/ or Tests/. It was not run again (no repeat runs).
    - next: commit, review, push.
  timestamp: 2026-10-16T22:02:44.389469+00:00
position_column: doing
position_ordinal: '80'
title: Localize the ElicitationValidator messages
---
Request of the step owner after D-1 (^t8fwhx2, commit c7e3ddd). Write all text in STE.

## Fact
- The messages in `ElicitationValidator.Message` (Sources/AgentViewKit/Elicitation/ElicitationValidator.swift) are plain String constants. They are not localized. Other kit text uses `String(localized:)`.
- The length messages say "characters". Since D-1, the lengths count Unicode code points.

## Decision of the step owner
- Localize each message with `String(localized:)`, in the same form as the other kit text.
- Keep the word "characters" in the messages for the user (Extras uses the same word). Say "code points" only in the doc comment.

## To do
- [x] Localize each constant and each message function of `ElicitationValidator.Message` (the functions with a count or a bound use a format string with the value as an argument).
- [x] Doc comment of the length messages: the count is in Unicode code points; the user text says "characters".
- [x] If the package has a string catalog or a check of localized strings, keep it correct.
- [x] Tests: the existing message tests still pass with the same English text. Fixed order; no clock wait, sleep, poll, retry or timeLimit. #elicitation-phase-6