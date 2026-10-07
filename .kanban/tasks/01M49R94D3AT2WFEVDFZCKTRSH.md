---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4b5tnz1yxz5d066ze66chqe
  text: |-
    Research and cause.

    Environment:
    - `.build/out` was gone after the disk filled, and SwiftPM made all checkouts again. SwiftPM could not remove `.build/checkouts/grpc-swift-2` ("Operation not permitted"). The cause: the sourcekit-lsp of `sah serve` (pid 4888) writes index builds into `.build/checkouts/*/.build` (1.3 GB in `grpc-swift-2` only) while SwiftPM removes the checkout. I paused that process with SIGSTOP for `swift package resolve` only, then sent SIGCONT. After that, `swift build --build-tests` passed. This index data in the checkouts can be the cause of the earlier full disk.

    Repeatable failure:
    - `swift test --filter 'SessionEntryRowsHostedTests|MessageViewsHostedTests|WireContentBlockViewHostedTests' --maximum-repetitions 50 --repeat-until fail`: passed (50 runs of the test, about 250 ms each).
    - Direct run of the test bundle with `swiftpm-testing-helper --test-bundle-path <bin> <bin> --testing-library swift-testing --filter anAppendedErrorShowsItsData` (DYLD_FRAMEWORK_PATH and DYLD_LIBRARY_PATH set to the Xcode platform paths): failed in 1 of 1, then 7 of 10 processes. With `--repetitions 10` in one process: only repetition 1 failed (4 of 5 processes); repetitions 2 to 10 passed. Thus the failure is in the first hosted test of a process.
    - The wait did NOT use the 5 s. The test failed after 0.225 s.

    Cause (temporary print in the test, now removed):
    - When the wait stops, the element with the identifier `error-data` is `AXTextArea` with label nil and value nil. After one more pump (50 ms), the same element is `AXStaticText` with the JSON text as label and value. Seen in 3 of 3 probe runs.
    - The data `Text` in `ErrorView` has `.textSelection(.enabled)`. SwiftUI first builds this selectable text element with the identifier but with no text, and fills it in on the next update. This occurs when the accessibility tree is new in the process.
    - The wait condition checks only that the identifier exists, but the expectation reads the label. So the wait stops on the incomplete element.
    - The cause is not in kit code: the view binds directly to `ErrorEntry.data`. A kit change would have to remove text selection, which lets the user copy the JSON. Fix: the wait checks the same label that the expectation reads. No sleep, and the limit stays at 5 s.
    - `TerminalView` command and the `LinkView` card do not use text selection, and no other test reads `error-data`.
  timestamp: 2026-10-07T12:36:18.529654+00:00
- actor: claude-code
  id: 01m4b68k3v9bckzcfgkvn3p4hx
  text: |-
    ### implement — changed
    - evidence: 1 file, Tests/AgentViewKitTests/Items/SessionEntryRowsHostedTests.swift. The wait and the expectation now use one new helper, `showsErrorData(in:)`, which reads the label of the `error-data` element. The wait limit stays at 5 s. No sleep, no kit change (`ErrorView` binds directly to `ErrorEntry.data`; the incomplete element comes from SwiftUI selectable text).
    - RED: direct bundle run (`swiftpm-testing-helper ... --filter anAppendedErrorShowsItsData`), 7 of 10 processes failed; with `--repetitions 10`, repetition 1 failed in 4 of 5 processes. Earlier `swift test` filter of the 3 suites with `--maximum-repetitions 50 --repeat-until fail` passed (50 runs).
    - GREEN: 30 of 30 new processes, one after the other; 30 of 30 new processes, 5 batches of 6 in parallel; 6 parallel processes with the 3 suites and `--repetitions 20` (120 runs of the test, 37 tests each, all passed); `swift test --filter SessionEntryRowsHostedTests` one time (14 tests passed); full `swift test` one time (1297 + 83 + 1 tests passed). Total runs of the test after the fix: 180 in new or parallel processes, plus the two `swift test` runs. Only warning: the expected mlx-swift `missing creator for mutated node`.
    - Correction to the task facts: the wait did not use the 5 s. It stopped after about 0.2 s on an element that had the identifier and no label.
    - Environment note: the sourcekit-lsp of `sah serve` writes index builds into `.build/checkouts/*/.build` and races SwiftPM when SwiftPM makes the checkouts again. See the earlier comment.
    - next: /review
  timestamp: 2026-10-07T12:43:54.363909+00:00
- actor: claude-code
  id: 01m4b6mygffgevjm11qr8fwbkq
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (commit 08a632b), 1 finding: Tests/AgentViewKitTests/Items/SessionEntryRowsHostedTests.swift:443 `swift/access-control` — Helper function `showsErrorData` should be marked `private`. Change `static func showsErrorData` to `private static func showsErrorData`.
    - next: /implement the open item in the "Review Findings (2026-10-07 07:47)" section. The task stays in review.
  timestamp: 2026-10-07T12:50:39.247929+00:00
- actor: claude-code
  id: 01m4b6n02emg7q13afbke7j7ja
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — the error-data test waits for the label through showsErrorData(in:); cause: SwiftUI first shows an empty AXTextArea on the first view test of a process; RED 7 of 10 new processes, GREEN 60 of 60
    - test: green — swift test, 1297 passed
    - commit: 08a632b
    - review: findings — Tests/AgentViewKitTests/Items/SessionEntryRowsHostedTests.swift:443
  timestamp: 2026-10-07T12:50:40.846300+00:00
- actor: claude-code
  id: 01m4b6wbkxv2pc7086r3nftbhn
  text: |-
    ### implement — changed
    - evidence: 1 file, Tests/AgentViewKitTests/Items/SessionEntryRowsHostedTests.swift. `static func showsErrorData` is now `private static func showsErrorData`. Commit 08a632b added only this one helper. Its only callers are the wait closure and the `#expect` in `anAppendedErrorShowsItsData`, in the same type. No other file calls it. The finding item is now `- [x]`.
    - `swift test --filter SessionEntryRowsHostedTests`: 14 tests in 1 suite passed. Full `swift test`: 1297 tests in 125 suites passed, 83 tests in 12 suites passed, 1 test passed, 0 failures. The one warning is the mlx-swift build-system message `missing creator for mutated node` from a dependency. It was also in the earlier runs on this task.
    - next: /review
  timestamp: 2026-10-07T12:54:42.045575+00:00
- actor: claude-code
  id: 01m4b74rcqd675642kwadesk99
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 6cf6776), 0 findings (7 validator runs attempted, 0 failed). 1 file reviewed; 2 .kanban files not reviewed because of .reviewignore. All items in the "Review Findings (2026-10-07 07:47)" section are checked.
    - next: none. The task is in done.
  timestamp: 2026-10-07T12:59:17.271869+00:00
- actor: claude-code
  id: 01m4b74sarmsfwqdxyfnbcrx3q
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — showsErrorData is private
    - test: green — swift test, 1297 passed
    - commit: 6cf6776
    - review: clean — 0 findings
  timestamp: 2026-10-07T12:59:18.232093+00:00
position_column: done
position_ordinal: ff8680
title: Make SessionEntryRowsHostedTests.anAppendedErrorShowsItsData stable
---
## What

The test `SessionEntryRowsHostedTests.anAppendedErrorShowsItsData` fails some times. It failed in two filtered runs with other suites. It passed in the full runs. It passed in one filtered run with 20 repetitions (`swift test --filter 'SessionEntryRowsHostedTests|MessageViewsHostedTests|WireContentBlockViewHostedTests' --maximum-repetitions 20`). The cause is not known.

The test calls `appendError` on the session model. Then it waits up to 5 seconds for the element with the identifier `ErrorView.dataIdentifier`. The wait limit must stay at 5 seconds. Do not use sleeps.

Find the cause. Read the order of events between `appendError`, the row in the list, and the lookup of the element. Check if the row is not made in the list, or if the identifier is lost when the row merges the element. Fix the cause in the view or in the harness. Views must bind directly to the FoundationModelsACPClient models. Add no kit-side state, copy, or turn logic.

## Acceptance Criteria

- [x] The cause of the failure is found and written on this task.
- [x] The test passes in every run, with the wait limit at 5 seconds.
- [x] The fix has no sleeps and no raised limits.

## Tests

- [x] Write a failing test that shows the cause, if the cause can be shown in a test. (The test itself shows the cause when it is the first hosted test of a process: a direct run of the test bundle failed in 7 of 10 processes. A separate test that always fails is not possible, because SwiftUI makes the incomplete element only when the accessibility tree is new in the process.)
- [x] Run `swift test --filter SessionEntryRowsHostedTests` one time after the fix.
- [x] Run the full suite one time at the end. It must have zero failures and zero warnings.

## Workflow

- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-10-07 07:47)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 1 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Tests/AgentViewKitTests/Items/SessionEntryRowsHostedTests.swift:443` `swift/access-control` — Helper function `showsErrorData` should be marked `private`. It is only called within the test class (lines 432 and 434) and should not be part of the class's public interface. Change `static func showsErrorData` to `private static func showsErrorData`.
