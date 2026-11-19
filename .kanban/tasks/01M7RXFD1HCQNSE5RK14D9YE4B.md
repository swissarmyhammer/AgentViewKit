---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7rxq9qvs7n2117kazagvqvn
  text: |-
    Implementation: the static `PromptInputView.apply(_:text:attachments:onSubmit:start:)` now takes the host closure `onSubmit`. It calls the closure one time, after `start`, only for `.send`. `.cancel` and `.consumed` do not call it. `send(_:)` does not call `onSubmit` itself now. Doc comments updated: the `onSubmit` property and init parameters, the type comment of PromptInputView, `apply`, `send(_:)`, `ComposerSubmitResult.consumed`, `Disposition.consumed` and `onComposerSubmit(_:)`.

    TDD: three new tests in ComposerSubmitResultTests (aConsumedPromptDoesNotCallTheHostClosure, aSendCallsTheHostClosureOneTime, aCancelDoesNotCallTheHostClosure). RED was a compile failure (no `onSubmit` parameter on `apply`). The fixture counts host calls in `hostCalls`.

    Discovery: `swift test` and `swift build` show one warning "missing creator for mutated node ... mlx-swift_Cmlx.bundle". It comes from the build system for the mlx-swift dependency, not from this change.

    Not done here (out of the scope of this implement step): push, and send the sha to testudoapp-9a. The commit step must do this.

    ### implement — changed
    - evidence: 3 files — Sources/AgentViewKit/Input/PromptInputView.swift, Sources/AgentViewKit/Input/ComposerSubmit.swift, Tests/AgentViewKitTests/Input/ComposerSubmitResultTests.swift. `swift test`: 1424 tests in 165 suites passed, plus 54 tests in 11 suites passed. IntegrationTests `swift build --build-tests`: Build complete. `swift format lint -s`: no new findings.
    - next: review, then commit, push and send the sha to testudoapp-9a.
  timestamp: 2026-11-19T03:31:06.619610+00:00
- actor: claude-code
  id: 01m7rxspvdt6gxj8w7t196ygvh
  text: |-
    ### test — green
    - evidence: swift test (package root) exit 0. "Test run with 1424 tests in 165 suites passed after 31.348 seconds." and "Test run with 54 tests in 11 suites passed after 0.013 seconds." Zero failures, zero skipped.
    - lint: swift format lint -s on the 3 changed files. 6 findings in ComposerSubmit.swift and PromptInputView.swift. The same 6 exist at HEAD (line numbers moved only). 0 new findings. ComposerSubmitResultTests.swift is clean.
    - build warning: "missing creator for mutated node" for the mlx-swift_Cmlx bundle. It comes from the build system, not from this change.
    - not run: IntegrationTests, ScreenshotTests (they take the screen focus).
    - next: review.
  timestamp: 2026-11-19T03:32:25.581257+00:00
position_column: doing
position_ordinal: '80'
title: Skip onSubmit after a consumed submit, so the thread does not scroll (D205 /btw)
---
Request from testudoapp-9a (2026-11-19), after task 01M7RW67CA7429M4T2X5ZA6YDN (56166863, 36b6fa83).

Now: after a submit hook returns `ComposerSubmitResult.consumed`, the host closure `onSubmit` of the composer runs, as after a send. The thread can use it to scroll to the bottom.

`/btw` does not change the transcript. The user may be reading higher up, so the thread must not scroll.

Do:
- After `.consumed`, do not call `onSubmit`. After `.send`, call it as now. After `.cancel`, do not call it (as now).
- Update the doc comments of `onSubmit`, `ComposerSubmitResult.consumed` and `onComposerSubmit(_:)`.
- TDD unit test: `.consumed` does not call `onSubmit`; `.send` calls it one time.

Run `swift test`. Push, and send the sha to testudoapp-9a.