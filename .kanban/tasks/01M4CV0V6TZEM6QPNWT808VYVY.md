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
position_column: todo
position_ordinal: bb80
title: Ask FoundationModelsACPAgent to make its serve and compose helper public
---
## What
Source: the deleted update plan of 2026-10-02, section 8 item 5 (task ^g95wwbs moved its content into `plan.md` and deleted it). The helper that serves and composes the agent of FoundationModelsACPAgent (`serve(...)` and `compose(...)` in `Sources/acp-agent/AgentComposition.swift`) is in the `acp-agent` executable target only. A host that runs the agent in its own process with `InProcessAgent.makeConnection(serving:)` (plan.md §3.9) must build the `RoutedACPAgent` itself. The kit does not import the agent, so this work is in FoundationModelsACPAgent.

- [ ] Make a task in FoundationModelsACPAgent: move the serve and compose helper into the `FoundationModelsACPAgent` library target and make it public.
- [ ] When that commit is pushed, change the doc comment of `InProcessQuickStart.start(cwd:serving:)` in `README.md` to use the public helper, and run `Scripts/extract-readme-snippets.sh` and `Scripts/check-readme.sh`.

## Acceptance Criteria
- [ ] FoundationModelsACPAgent has a task for the public helper.
- [ ] The README in-process quick start names the public helper when it exists.

## Tests
- [ ] `Scripts/check-readme.sh` passes.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #blocked-upstream