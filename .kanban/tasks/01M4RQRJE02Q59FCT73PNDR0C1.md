---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4rzfqdptffqx5qbrfxtyyv8
  text: |-
    Research (read only, checkout 8ec62b6 of FoundationModelsACPAgent):
    - The project registry: `SessionSetup.activateSession` calls `ProjectRegistry(directory: composition.userLayerRoot).recordSessionStart(...)` for each session that is not replay-only (session/new and a full resume). The user layer root comes from `DotfolderStack` (FoundationModelsExtras): `$XDG_CONFIG_HOME/<name>/` when the injected environment has an absolute `XDG_CONFIG_HOME`, else `~/.config/<name>/`.
    - The public control: `ComposedAgent.compose(name:workingDirectory:environment:...)`. The `environment:` dictionary is documented as "The environment the stack reads XDG_CONFIG_HOME from". It goes to the start-up load and to each session load (`makeConfigurationLoader`). It is a code parameter, not the process environment.
    - The code-context index: `ToolCatalog.composeCodeContext` opens `CodeContext` over the session cwd and makes `<cwd>/.code-context`. It is off only when `tools.codeContext` is off in a config layer (a config file). A resume is replay-only only when the recorded cwd or an additional root does not exist. No public option gives a replay-only resume, and no code parameter disables the index. Missing API for the FoundationModelsACPAgent session: a code override for the tool sections (for example a `tools:` override on `compose`, as `transcriptLocation:` is for transcripts), or a `replayOnly` option on `session/resume`.
    - The recorded cwds of the RecordedSessions are all in temporary directories (/private/tmp/... and /private/var/folders/.../T/...), not in the home directory. Thus the `.code-context/` writes do not go into the home directory. Only the registry write goes into the home directory.
    - Plan: the stage gets a configuration directory; the Gallery agent gets `environment: ["XDG_CONFIG_HOME": <stage>/configuration]`.
  timestamp: 2026-10-12T21:14:50.166518+00:00
- actor: claude-code
  id: 01m4s0226teesyfzjhvj8rbcyx
  text: |-
    Implementation landed (not committed).
    - API: the public `environment:` dictionary of `ComposedAgent.compose`. The package documents it as "The environment the stack reads XDG_CONFIG_HOME from". It is a code value, not the process environment, and no config file is used. An absolute `XDG_CONFIG_HOME` in it moves the user layer, and thus `projects.jsonl`.
    - Gallery: `RecordedSessionsStage` now makes an empty `configuration/` directory and gives `agentEnvironment` = `["XDG_CONFIG_HOME": <stage>/configuration]` (only that key, so the agent reads no value of the process environment). `DemoAgent.makeInProcess(recordedSessions:)` passes it.
    - ACP tab tests: `DemoAgent.makeInProcess(options:environment:)` gets an `environment` parameter (default: the process environment, so the app does not change). `DemoAgentTests.makeACPTabAgent` gives a configuration root below its temporary directory.
    - Tests: `RecordedSessionsAgentTests.aRunOfTheAgentLeavesTheProjectRegistryOfTheHomeDirectoryUnchanged` and `DemoAgentTests.anACPTabAgentOfATestLeavesTheProjectRegistryOfTheHomeDirectoryUnchanged` compare the bytes and the modification date of `~/.config/agentviewkit-demo/projects.jsonl` before and after a run that opens a session (and resumes each recorded session). `theAgentWritesItsProjectRegistryIntoTheConfigurationDirectoryOfTheStage` checks that the registry goes into the stage. Each run opens a session in an existing temporary cwd, so the tests check the same thing on CI. Stage tests check the new directory and `agentEnvironment`.
    - RED: shown by the compile failure (no `configurationDirectory`, no `agentEnvironment`, no `environment:`). I did not run the home test before the change on purpose: the old code writes the real `~/.config/agentviewkit-demo/projects.jsonl`, and the rules forbid a change to real files in the home directory.
    - Evidence: `stat` of `~/.config/agentviewkit-demo/projects.jsonl` was `1791836236 507` before and after the targeted run and the full run.
    - `.code-context/`: no public option disables the index or forces a replay-only resume (only `tools.codeContext` in a config file, which is forbidden). The recorded cwds of the RecordedSessions are in temporary directories, not in the home directory, so this card does not need that API. Missing API, for the FoundationModelsACPAgent session, if the owner wants no write in an existing recorded cwd: a code override of the tool sections on `ComposedAgent.compose` (as `transcriptLocation:` is for transcripts), or a replay-only option on `session/resume`.
    - `Docs/decisions/dependencies.md` records the new rule.
  timestamp: 2026-10-12T21:24:51.034095+00:00
- actor: claude-code
  id: 01m4s027vwx3a7bxsb3d4c9gam
  text: |-
    ### implement — changed
    - evidence: 8 files — Sources/DemoSupport/RecordedSessionsStage.swift, Sources/DemoSupport/DemoAgent.swift, Sources/DemoSupport/DemoLaunchOptions.swift (doc link), Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift (doc link), Tests/AgentViewKitTests/ACP/RecordedSessionsAgentTests.swift, Tests/AgentViewKitTests/ACP/RecordedSessionsStageTests.swift, Tests/AgentViewKitTests/ACP/DemoAgentTests.swift, Docs/decisions/dependencies.md. API: `ComposedAgent.compose(environment:)` with `XDG_CONFIG_HOME`. Targeted run: 30 tests in 5 suites passed. Full `swift test`: 1275 test functions started, no failed test, 2 known issues (existing `withKnownIssue`), XCTest 0 tests; only warning is the existing SwiftPM "missing creator for mutated node" of the mlx-swift bundle. Load average before the full run 29.94 20.98 18.18, after 25.52 23.47 19.86. Home registry stat unchanged (1791836236, 507 bytes).
    - next: /review. The task stays in doing.
  timestamp: 2026-10-12T21:24:56.828907+00:00
- actor: claude-code
  id: 01m4s2d15zsvnneq41xx7hpye2
  text: 'Decision of the owner (2026-10-12): accept `XDG_CONFIG_HOME` set to an empty temporary configuration root in the `environment:` dictionary of `ComposedAgent.compose` (a value in code, not the process environment, no config file) for the tests and the Gallery.'
  timestamp: 2026-10-12T22:05:47.583900+00:00
position_column: doing
position_ordinal: '8180'
title: Keep the in-process agent tests and the Gallery from writing into the home directory
---
## What
Found during ^wv9bpnv (2026-10-12): `RecordedSessionsAgentTests` run FoundationModelsACPAgent in the process. On a machine where the recorded working directories still exist (this one), each resume uses the full tool surface and writes outside the repository: `~/.config/agentviewkit-demo/projects.jsonl` (the project registry, rewritten on each run) and a `.code-context/` directory in each recorded working directory. On CI the directories are missing, so the agent replays with no tools and writes nothing. A test must not write into the home directory of the person who runs it.

## Work
- [x] Find which part of FoundationModelsACPAgent writes the project registry and the code-context index, and which public input controls the location (for example the `environment:` dictionary of `ComposedAgent.compose`, a home or config root parameter, or a replay-only resume option). Read only; do not change that repository.
- [x] Make the tests (and, if it is right, the Gallery) give the agent a temporary root for these writes, through a public API, not through the process environment and not through a config file. If no public API exists, record the exact missing API for the FoundationModelsACPAgent session and stop.
- [x] A test that the test run writes nothing into the home directory.