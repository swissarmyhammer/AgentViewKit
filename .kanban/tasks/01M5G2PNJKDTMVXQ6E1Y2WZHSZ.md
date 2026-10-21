---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5g3rwy6jqm8ngg30qsxaeyf
  text: |-
    Research result (root cause, with evidence).

    - In gqztxta-4, only the second expectation failed: `NSApp.windows.allSatisfy { !$0.isKeyWindow }`. The expectations on `isVisible` and `!NSApp.isActive` passed. Thus a window that is not visible said that it was the key window, while the application was not active.
    - Probe: `makeKey()` on a hidden harness window and on a plain `NSWindow` does nothing in this process (`.prohibited`, not active). `NSApp.keyWindow` stays `nil`. No test code makes a window key.
    - Diagnostic full runs (temporary code, now removed) logged each window class in `NSApp.windows` and each window with `isKeyWindow == true`, with the stack of its init. Runs y2-diag2 and y2-diag3 (logs in the scratchpad `winwatch` folder) found one such window: `NSCampoLightweightUIHostWindow`, a private AppKit window. Its class overrides `isKeyWindow`, `canBecomeKeyWindow`, `hasKeyAppearance` and `acceptsFirstResponder`. Values: `visible=false`, frame size 0x0, `NSApp.keyWindow == nil`, `NSApp.isActive == false`. `didBecomeKeyNotification` never came.
    - The init stack: `NSTextInputContext _performDwellingCheck` / `_performHoveringDwellingCheck` (a delayed perform, that is, a timer) -> `_showLightweightAffordanceWithMode:` -> `NSCampoLightweightUIController showWithMode:forView:` -> `setupHostWindow:` -> `NSCampoLightweightUIHostWindow init`. This is the Writing Tools affordance of a text view that has the focus, for example the EditorKit prompt editor in the thread and request deck tests.
    - The timer fires some time after a text view gets the focus. Thus the window comes into `NSApp.windows` at a time that the tests do not control. When it is there during `aMountedViewThatGetsAKeyShowsNoWindowAndTakesNoFocus`, the expectation fails. That is the flaky failure.
    - The window is not a test window and it does not take the focus: the application has no key window and is not active. The window monitor found 0 on-screen windows in all runs after AVK-12 (f3a6655), also in the 3 diagnostic runs.
    - Thus the check is wrong, not the harness. The parallel-test hypothesis is false: no test can make a window key in this process.

    Plan: the test checks the key window of the application (`NSApp.keyWindow`), the key status of the harness window, and the activation of the application, in place of the `isKeyWindow` value of each window. The check of `isVisible` on each window stays. A new test keeps a window that only reports `isKeyWindow == true`, as the AppKit window does, so that the cause is certain in each run.
  timestamp: 2026-10-21T20:52:16.966804+00:00
- actor: claude-code
  id: 01m5g4bdqe8esy4wjmz5n9ych6
  text: |-
    Implementation landed (TDD).

    - RED: new test `aWindowThatOnlyReportsTheKeyStatusTakesNoFocus` keeps a hidden `KeyStatusReportingWindow` (an `NSWindow` subclass whose `isKeyWindow` is `true`, as `NSCampoLightweightUIHostWindow` does). With the old check, the test failed on each run with the same message as gqztxta-4: `Expectation failed: NSApp.windows.allSatisfy { !$0.isKeyWindow }`. The `#require` showed that the window is in `NSApp.windows`.
    - GREEN: `HostedViewHarness.processHasFocus` (new public property in `Sources/AgentViewKitTestSupport/HostedViewHarness.swift`) is `true` when the application is active, when `NSApplication.keyWindow` is not `nil`, or when the harness window is the key window. Both focus tests use `#expect(!harness.processHasFocus)` in place of the `isKeyWindow` check of each window and the `isActive` check. The check of `isVisible` on each window in `NSApp.windows` stays as it was, so a window on the screen still fails the test.
    - The check is not weaker: AppKit sends key events only to `NSApplication.keyWindow`, and the application must be active to take the focus. The `isActive` check is still in the property.
    - The source of the AppKit window is not changed. It is not a test window, it is never on the screen, and it takes no focus. It comes from the Writing Tools affordance of the real text views under test. Thus no pattern for `HiddenTestWindowTests` applies.
    - Did not work / ruled out: (1) the parallel-test hypothesis. `makeKey()` on a hidden window does nothing in this process, so no test can make a window key. (2) The first diagnostic run (notification `didBecomeKeyNotification`) saw nothing, because the AppKit window never becomes key through AppKit: only its class override says so.
    - Temporary diagnostic code (`Y2Diag.swift`, an `NSWindow` init swizzle, and a probe test file) is removed. `git diff` holds only the two files above.
  timestamp: 2026-10-21T21:02:23.982520+00:00
- actor: claude-code
  id: 01m5g4bj6866cxxwxbpy6zechb
  text: |-
    ### implement — changed
    - evidence: root cause = `NSCampoLightweightUIHostWindow`, a private AppKit window that a timer of `NSTextInputContext` (`_performDwellingCheck` / `_performHoveringDwellingCheck`) makes for the Writing Tools affordance of a focused text view. Its class overrides `isKeyWindow` (true) while it is not visible, has size 0x0, and `NSApp.keyWindow == nil`, `NSApp.isActive == false`. Init stacks in winwatch/y2-diag3.log. Files: Sources/AgentViewKitTestSupport/HostedViewHarness.swift (new `processHasFocus`), Tests/AgentViewKitTests/TestSupport/HostedViewHarnessTests.swift (new `KeyStatusReportingWindow`, new test `aWindowThatOnlyReportsTheKeyStatusTakesNoFocus`, focus check changed). RED: the new test failed with the old check; GREEN: it passed. Full suite 3 times with `run-watched.sh` (y2-full1, y2-full2, y2-full3): build-exit=0, test-exit=0 each, 1573 tests in 197 suites + 214 + 1 passed, 3 known issues (the same as before), 0 on-screen test-process windows in each run.
    - next: /review
  timestamp: 2026-10-21T21:02:28.552703+00:00
position_column: doing
position_ordinal: '8180'
title: Find why aMountedViewThatGetsAKeyShowsNoWindowAndTakesNoFocus fails in some full runs
---
## Why

The test rules of the project forbid a test that fails in some runs only. In the full run `gqztxta-4` (window monitor `run-watched.sh`, 2026-10-21), `HostedViewHarnessTests.aMountedViewThatGetsAKeyShowsNoWindowAndTakesNoFocus` failed at `HostedViewHarnessTests.swift`:

`Expectation failed: NSApp.windows.allSatisfy { !$0.isKeyWindow }`

The next full run `gqztxta-5` had no code change and passed (1572 tests, 3 known issues). The window monitor showed 0 on-screen test windows in both runs. The change in that run touched only `Tests/AgentViewKitTests/Theme/GlassAccessibilityTests.swift`, which renders with `ImageRenderer` and opens no window.

The expectation reads `NSApp.windows` of the full process. Tests in other suites (not `.hostedSerially`) run in parallel and can make a window of the process the key window at that time.

## What to do

- [x] Find the test that makes a window of the process the key window while `HostedViewHarnessTests` runs. Use the logs: `/private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/47eecec9-7dd0-49dd-b5a7-064ae713842b/scratchpad/winwatch/gqztxta-4.log`.
- [x] Correct the cause, so that the expectation is always true. Do not add a retry, a sleep, a poll or a clock.

## Acceptance

- Two full runs with the window monitor pass, with 0 on-screen test windows. #avk-8