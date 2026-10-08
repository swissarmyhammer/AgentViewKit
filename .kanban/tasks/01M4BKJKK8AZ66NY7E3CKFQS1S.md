---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4cwf8dc4za92r7dtat3cxkg
  text: Unblocked (2026-10-08). Client task 8mx2fve is done (2026-10-07 17:57), and FoundationModelsACPClient origin/main is e1cac1d. Task ^vewxkf3 moves the client pin to e1cac1d and the ACP pin to the revision that the client resolves, so this task now depends on ^vewxkf3 and does not move the pins again. Check that the pinned FoundationModelsACP has the a25yvy1 InMemoryTransport fix before you remove InProcessClientTransport.
  timestamp: 2026-10-08T04:31:15.884194+00:00
- actor: claude-code
  id: 01m4cyrkyhpywdwf2hxbj70s8y
  text: |-
    Research (2026-10-08):
    - The pins are already moved by ^vewxkf3 (commit b0e2003): FoundationModelsACP b2cec56, FoundationModelsACPClient e1cac1d. This task does not move them again. The first subtask is done by ^vewxkf3.
    - The checkout of FoundationModelsACP at b2cec56 ("fix(transport): end the peer stream when an InMemoryTransport reader stops") has the fix: in `InMemoryTransport.pair()`, the `onTermination` of each continuation finishes the other continuation when the termination is `.cancelled`.
    - `ConnectionModel.disconnect()` calls `ClientSideConnection.close()`, which stops the read of the transport. With the fix, the agent side then reads the end of its input.
    - `ConnectionCloseReason` is not `Equatable` (`transportFailed(any Error)`), so a test must use `if case .endOfInput`.
    - `ACPTestTimeLimit.run` records an issue when the time runs out. Thus the disconnect test fails when the agent side does not close.
    - Callers of `AgentConnectionBox.waitUntilClosed()`: only `InProcessAgentTests.aDisconnectOfTheModelClosesTheAgentSide`.
    - README: no snippet names `InProcessClientTransport`. The prose of the in-process quick start says "the helper then closes the input of the agent side". That text must change, because the pair now does it. `DemoAgent.stop()` has the same text in its doc comment.
    - The task in `makeConnection` that waits for `agentConnection.closed` stays: it keeps the agent side alive (an agent such as `RoutedACPAgent` keeps its connection weakly), and it closes the two ends when the agent closes first.
  timestamp: 2026-10-08T05:11:19.761907+00:00
- actor: claude-code
  id: 01m4czm4by4z6wbjs7yd49pzm7
  text: |-
    Implementation (2026-10-08):
    - `InProcessAgent.makeConnection(serving:)` now connects the model over the client end of `InMemoryTransport.pair()` directly. `InProcessClientTransport` and the `import Foundation` that only it used are deleted. The task that waits for `agentConnection.closed` stays (it keeps the agent side alive and closes the two ends when the agent closes first).
    - `AgentConnectionBox.waitUntilClosed()` is deleted. Its only caller was the disconnect test, and that test must now read the close reason. The new property `AgentConnectionBox.closed: ConnectionCloseReason?` (async) replaces it.
    - `aDisconnectOfTheModelClosesTheAgentSide` now requires the close reason, and expects `.endOfInput`. It has no sleep: `ACPTestTimeLimit.run` (5 s, not changed) is the only limit.
    - Proof that the test can fail (RED): with the wrapper removed, I removed the two `onTermination` handlers in `.build/checkouts/FoundationModelsACP/.../InMemoryTransport.swift` for one run. The test failed with two issues: "The operation did not end in time." and `Self.isEndOfInput(reason)` false with `reason → .closedLocally`. Then `git checkout --` restored the checkout (HEAD b2cec56, clean), and the test passed (GREEN). The pins did not move.
    - `RemovedVocabularyTests.removedSymbols` has `InProcessClientTransport`. This guard cannot be RED after the removal, because the symbol is already gone.
    - The README prose of the in-process quick start, the doc comment of `InProcessAgent`, and the doc comment of `DemoAgent.stop()` now say that the pair ends the input of the agent side. No snippet text changed, so `Scripts/extract-readme-snippets.sh` was not necessary.
  timestamp: 2026-10-08T05:26:21.310255+00:00
- actor: claude-code
  id: 01m4czm6zch2nbqddfd8mq79h0
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/ACP/InProcessAgent.swift, Sources/DemoSupport/AgentConnectionBox.swift, Sources/DemoSupport/DemoAgent.swift, Tests/AgentViewKitTests/ACP/InProcessAgentTests.swift, Tests/PackageStructureTests/RemovedVocabularyTests.swift, README.md. Gates: `swift test` 1025 tests in 110 suites passed (only the expected mlx "missing creator for mutated node" warning); `Scripts/check-readme.sh` passed; `Scripts/test-examples.sh AgentViewKitDemo` passed (4 UI tests); `swift build --package-path Benchmarks` passed. RED shown with the InMemoryTransport fix removed for one run (time-limit issue and reason `.closedLocally`); GREEN with the pinned b2cec56.
    - next: /review
  timestamp: 2026-10-08T05:26:23.980144+00:00
- actor: claude-code
  id: 01m4czzk7ss3v903cd0wmp1b74
  text: |-
    ### test - green
    - evidence: `swift test` - 1025 tests in 110 suites passed, 0 failed, 0 skipped. `Scripts/check-readme.sh` - exit 0, 3 snippets match and compile. `Scripts/test-examples.sh AgentViewKitDemo` - exit 0, 4 UI tests, 0 failures. `swift build --package-path Benchmarks` - Build complete, exit 0.
    - warnings: only the expected mlx-swift "missing creator for mutated node" and the Xcode "Metadata extraction skipped" notice. No other warnings.
    - checkout: `.build/checkouts/FoundationModelsACP` status is empty (clean). HEAD is b2cec56fc42cd5b1c4e25cfb8fe8773857bbbf65.
    - time limit: no time-limit failure. ACPTestTimeLimit is not changed.
    - next: review.
  timestamp: 2026-10-08T05:32:36.985982+00:00
depends_on:
- 01M4BTQV4WZHK4CE5F6VEWXKF3
position_column: doing
position_ordinal: '80'
title: Remove the in-process wrapper transport when the InMemoryTransport fix is pinned
---
## What
Task ^ztxqxvh added `InProcessClientTransport` in `Sources/AgentViewKit/ACP/InProcessAgent.swift`, because `ConnectionModel.disconnect()` did not end the stream of an `InMemoryTransport.pair()`, so an in-process agent stayed alive. FoundationModelsACPClient tasks a25yvy1 (the fix in FoundationModelsACP `InMemoryTransport`) and 8mx2fve (adopt it in the client) fix the cause. This task starts when the kit can pin a pushed client commit that has 8mx2fve.

- [x] Move the FoundationModelsACPClient and FoundationModelsACP pins to the pushed commits (targeted updates in the three `Package.resolved` files) and update `ResolvedPinsTests`. (Done by ^vewxkf3: FoundationModelsACPClient e1cac1d, FoundationModelsACP b2cec56. This task did not move the pins again.)
- [x] Delete `InProcessClientTransport` and serve the pair directly in `InProcessAgent.makeConnection(serving:)`.
- [x] Delete `AgentConnectionBox.waitUntilClosed()` if no other caller uses it. (Deleted. The property `AgentConnectionBox.closed` replaces it, because the disconnect test must read the close reason.)

## Acceptance Criteria
- [x] No `InProcessClientTransport` in `Sources/`.
- [x] `aDisconnectOfTheModelClosesTheAgentSide` still passes.

## Tests
- [x] `Tests/AgentViewKitTests/ACP/InProcessAgentTests.swift`: `aDisconnectOfTheModelClosesTheAgentSide`.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.