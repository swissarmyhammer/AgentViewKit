---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4cwen2hznv7995ftncb1xt7
  text: 'Upstream task made on the FoundationModelsACPAgent board: ^h72a557 "Make the serve and compose helper of the agent public in the library target". It was written with the kanban CLI in the agent repository. This task stays blocked-upstream until ^h72a557 is pushed.'
  timestamp: 2026-10-08T04:30:56.081751+00:00
- actor: claude-code
  id: 01m4dtzwdcvt5w14yvhf1k8xk4
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — the upstream request exists: FoundationModelsACPAgent task 01M4CWED7MJFK6NEGGYH72A557 "Make the serve and compose helper of the agent public in the library target", column todo. FoundationModelsACPAgent HEAD c83355c has no public serve or compose helper.
    - next: when the upstream helper is public and pushed, change the README in-process quick start and run the README scripts. A person must start this task again.
  timestamp: 2026-10-08T13:24:37.932162+00:00
- actor: claude-code
  id: 01m4g8yv7mvjzy9wsrq0jnn9br
  text: 'Upstream status, 2026-10-09: the FoundationModelsACPAgent /finish session will do task 01M4CWED7MJFK6NEGGYH72A557 after its current task. It recorded the shape that the kit needs: a public helper that returns `any Agent` bound to a given `AgentSideConnection`, with no own transport or serve loop. It will tell us if `compose` must throw or be async, and it will send the commit sha after the push. The push needs approval from its user.'
  timestamp: 2026-10-09T12:07:12.884418+00:00
- actor: claude-code
  id: 01m4hfbet3s8s3fa3t41gc590w
  text: 'Upstream status, 2026-10-09: FoundationModelsACPAgent implemented the public helper. It is not committed or pushed yet. Shape: `ComposedAgent` is a public `Sendable` struct. Step 1 (host, async throws, one time): `let composed = try await ComposedAgent.compose(name: try DotfolderName("my-host"), workingDirectory: projectDirectory)`; optional parameters are `environment`, `modelSource` (`.live` or `.stub`), `stubChunkDelay` and `reporting progress`. Step 2 (sync, does not throw, no transport): `InProcessAgent.makeConnection { connection in composed.agent(boundTo: connection) }`. Step 3, after the connection closes: `await composed.waitForConnectionTeardown()`. The README in-process quick start must show these three steps. Wait for the commit sha before the work starts.'
  timestamp: 2026-10-09T23:18:12.035113+00:00
- actor: claude-code
  id: 01m4jb1tr7ma195awh7xvjq7rz
  text: 'Research, 2026-10-10: FoundationModelsACPAgent origin/main 18d2eb2 (commit 25787f4) has the public `Sendable` struct `ComposedAgent` in `Sources/FoundationModelsACPAgent/ComposedAgent.swift`. The kit Package.swift has no dependency on FoundationModelsACPAgent, so compiled README code cannot name `ComposedAgent`. The README snippet `InProcessQuickStart` already shows the agent code in a `///` doc comment, which the snippet build does not compile. Three places tell a host to bind a `RoutedACPAgent` itself: the doc comment of `InProcessQuickStart.start(cwd:serving:)` in README.md (and its extracted copy in Examples/ReadmeSnippets/Snippets/InProcessQuickStart.swift), the README prose of the section "An agent in this process", and the doc comment of `InProcessAgent` in Sources/AgentViewKit/ACP/InProcessAgent.swift. plan.md §3.9 only says that the app gives the agent; it does not tell the host to build it. `ConnectionModel.disconnect()` is async. Plan: add a test in ReadmeCoverageTests that the in-process quick start shows the three steps of `ComposedAgent` and does not call `RoutedACPAgent(`, then change the text.'
  timestamp: 2026-10-10T07:22:16.711528+00:00
- actor: claude-code
  id: 01m4jbnn1teevx4b0mrqaw0xqc
  text: 'Implementation, 2026-10-10. TDD: two new tests in ReadmeCoverageTests read the `InProcessQuickStart` snippet of README.md. `theInProcessQuickStartShowsEachStepOfTheComposedAgent` requires `ComposedAgent.compose(`, `composed.agent(boundTo:` and `composed.waitForConnectionTeardown()`. `theInProcessQuickStartDoesNotBuildTheRoutedAgentByHand` forbids `RoutedACPAgent(`. RED: both failed for the expected reason (the snippet had the old `RoutedACPAgent` example). GREEN: both pass after the change. Changes: the doc comment of `InProcessQuickStart.start(cwd:serving:)` in README.md shows the three steps of `ComposedAgent`; the README prose of the section "An agent in this process" names `ComposedAgent`, `ComposedAgent.agent(boundTo:)` and `ComposedAgent.waitForConnectionTeardown()`; the doc comment of `InProcessAgent` in Sources/AgentViewKit/ACP/InProcessAgent.swift shows the same three steps with `InProcessAgent.makeConnection`. The `ComposedAgent` code is only in `///` doc comments, because the kit does not import FoundationModelsACPAgent and compiled snippet code cannot name it. The README doc comment says this. `Scripts/extract-readme-snippets.sh` wrote the 3 snippets again; the change is in Examples/ReadmeSnippets/Snippets/InProcessQuickStart.swift. plan.md §3.9 is not changed: it only says that the app gives the agent.'
  timestamp: 2026-10-10T07:33:06.234410+00:00
- actor: claude-code
  id: 01m4jbnrd4hk3t8mgj30bm0vyf
  text: |-
    ### implement — changed
    - evidence: 5 files — README.md, Examples/ReadmeSnippets/Snippets/InProcessQuickStart.swift, Sources/AgentViewKit/ACP/InProcessAgent.swift, Tests/PackageStructureTests/ReadmeCoverageTests.swift, and this card. `Scripts/extract-readme-snippets.sh`: wrote 3 snippets. `Scripts/check-readme.sh`: passed. `swift test --filter ReadmeCoverageTests`: RED 2 of 12 failed, then GREEN 12 of 12 passed. `swift test`: 1040 tests in 110 suites passed, 0 failures (load average 33.08 at start, 28.77 at end). The build prints one SwiftPM build-graph warning, "missing creator for mutated node" for the mlx-swift_Cmlx.bundle of a dependency. It is not from the source of the kit, and it was also in the build before this change.
    - next: /review.
  timestamp: 2026-10-10T07:33:09.668595+00:00
position_column: doing
position_ordinal: '80'
title: Ask FoundationModelsACPAgent to make its serve and compose helper public
---
## What
Source: the deleted update plan of 2026-10-02, section 8 item 5 (task ^g95wwbs moved its content into `plan.md` and deleted it). The helper that serves and composes the agent of FoundationModelsACPAgent (`serve(...)` and `compose(...)` in `Sources/acp-agent/AgentComposition.swift`) is in the `acp-agent` executable target only. A host that runs the agent in its own process with `InProcessAgent.makeConnection(serving:)` (plan.md §3.9) must build the `RoutedACPAgent` itself. The kit does not import the agent, so this work is in FoundationModelsACPAgent.

- [x] Make a task in FoundationModelsACPAgent: move the serve and compose helper into the `FoundationModelsACPAgent` library target and make it public. Upstream task 01M4CWED7MJFK6NEGGYH72A557 (^h72a557), done in commit 25787f4 (origin/main 18d2eb2): the public `ComposedAgent` in `Sources/FoundationModelsACPAgent/ComposedAgent.swift`.
- [x] When that commit is pushed, change the doc comment of `InProcessQuickStart.start(cwd:serving:)` in `README.md` to use the public helper, and run `Scripts/extract-readme-snippets.sh` and `Scripts/check-readme.sh`.

## Acceptance Criteria
- [x] FoundationModelsACPAgent has a task for the public helper.
- [x] The README in-process quick start names the public helper when it exists.

## Tests
- [x] `Scripts/check-readme.sh` passes.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.