---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: Keep the in-process agent tests and the Gallery from writing into the home directory
---
## What
Found during ^wv9bpnv (2026-10-12): `RecordedSessionsAgentTests` run FoundationModelsACPAgent in the process. On a machine where the recorded working directories still exist (this one), each resume uses the full tool surface and writes outside the repository: `~/.config/agentviewkit-demo/projects.jsonl` (the project registry, rewritten on each run) and a `.code-context/` directory in each recorded working directory. On CI the directories are missing, so the agent replays with no tools and writes nothing. A test must not write into the home directory of the person who runs it.

## Work
- [ ] Find which part of FoundationModelsACPAgent writes the project registry and the code-context index, and which public input controls the location (for example the `environment:` dictionary of `ComposedAgent.compose`, a home or config root parameter, or a replay-only resume option). Read only; do not change that repository.
- [ ] Make the tests (and, if it is right, the Gallery) give the agent a temporary root for these writes, through a public API, not through the process environment and not through a config file. If no public API exists, record the exact missing API for the FoundationModelsACPAgent session and stop.
- [ ] A test that the test run writes nothing into the home directory.