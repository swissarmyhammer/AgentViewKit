---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4cwen2hznv7995ftncb1xt7
  text: 'Upstream task made on the FoundationModelsACPAgent board: ^h72a557 "Make the serve and compose helper of the agent public in the library target". It was written with the kanban CLI in the agent repository. This task stays blocked-upstream until ^h72a557 is pushed.'
  timestamp: 2026-10-08T04:30:56.081751+00:00
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