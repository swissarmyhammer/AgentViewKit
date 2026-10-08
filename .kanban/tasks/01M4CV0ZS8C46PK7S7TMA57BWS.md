---
assignees:
- claude-code
position_column: todo
position_ordinal: bc80
title: Ask FoundationModelsACPClient for the environment, the working directory and the exit status of AgentProcess
---
## What
Source: the deleted update plan of 2026-10-02, section 9.4 (task ^g95wwbs moved its content into `plan.md` and deleted it). `AgentProcess` of FoundationModelsACPClient has only `init(command:arguments:)`. The child inherits the environment of the host, and the host cannot set the working directory. Thus `AgentProcessLauncher` (`Sources/AgentViewKit/ACP/AgentProcessLauncher.swift`) launches the agent through `/usr/bin/env`, and the exit status of the agent is not available.

- [ ] Make a task in FoundationModelsACPClient: add an `environment` parameter and a `currentDirectory` parameter to `AgentProcess`, and give the exit status of the process.
- [ ] When that commit is pinned, change `AgentProcessLauncher` to use the new parameters in place of `/usr/bin/env`, and show the exit status where the kit shows the end of the agent process.

## Acceptance Criteria
- [ ] FoundationModelsACPClient has a task for the three parts.
- [ ] After the pin move, `AgentProcessLauncher` does not start `/usr/bin/env`.

## Tests
- [ ] A unit test of `AgentProcessLauncher` with `FakeProcessLauncher` or the real launcher checks the environment and the working directory of the child.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #blocked-upstream