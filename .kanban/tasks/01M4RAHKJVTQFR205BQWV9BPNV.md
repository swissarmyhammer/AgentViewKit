---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4ramxaw52avhq16hvkbaqkq
  text: |-
    Research (read only; FoundationModelsACPAgent local 8506ea5 and remote main 50d8785, which have the same API):

    - `ComposedAgent.compose(name:workingDirectory:environment:modelSource:stubChunkDelay:reporting:)` loads the start-up configuration with `ConfigurationLoader(name:workingDirectory:environment:)`. It has no parameter for an `AgentConfiguration`, a `TranscriptLocation`, or a `userDirectory`.
    - `RoutedACPAgent.init(name:router:configuration:reporting:userDirectory:environment:inlineSettleGrace:)` is public, but it uses `configuration` only to resolve the profile. Each session request loads the configuration again from the files of the stack: `SessionSetup.loadSessionContext(workingDirectory:)` (session/new, session/resume, session/load) and `SessionList.listableRecords(inProject:)` (session/list) each make a new `ConfigurationLoader(name:workingDirectory:userDirectory:environment:)` and read `transcripts.location` from it.
    - Thus the only ways to set the transcript location are config files: the user layer (`XDG_CONFIG_HOME` in the `environment` value, or `userDirectory`), or the project layer `<cwd>/.acp-agent/config.yaml`. The card forbids "through `XDG_CONFIG_HOME` and a config file".
    - The stub model is public: `ComposedAgent.ModelSource.stub` (the library `EchoModel`; no download, no weights). The Gallery can use it.
    - The ACP tab also starts the sibling program: `DemoLaunchOptions.defaultAgentCommand` (`FoundationModelsACPAgent/.build/release/acp-agent`), `--agent-command`, and `DemoLaunchOptions.agentArguments(for:)` serve the ACP tab and the Gallery tab. `DemoAgent.makeConnected(options:)` starts it for the ACP tab. `DemoAgent.makeConnected(recordedSessions:agentCommand:)` and `RecordedSessionsStage.agentEnvironment(adding:)` / `configurationHome` / the config file are the Gallery-only path.

    No file of AgentViewKit is changed.
  timestamp: 2026-10-12T15:10:39.964109+00:00
- actor: claude-code
  id: 01m4ran2bw08j57jfc9kcawc34
  text: |-
    Blocker: the public API of FoundationModelsACPAgent has no in-code transcript location.

    Missing API (send to the FoundationModelsACPAgent session):
    - `ComposedAgent.compose(...)` must accept a transcript location in code, for example a `transcriptLocation: TranscriptLocation? = nil` parameter (or a configuration override such as `configure: (inout AgentConfiguration) -> Void`).
    - `RoutedACPAgent` must keep that value and apply it to each per-session configuration load: `SessionSetup.loadSessionContext(workingDirectory:)` and `SessionList.listableRecords(inProject:)` (and the registry path of `allListableRecords()`). A value on the start-up configuration only is not sufficient, because each session request reads the files of the stack again.

    Without this API, the Gallery can run the agent in the process only through a config file (the user layer through `environment["XDG_CONFIG_HOME"]` or `userDirectory`, or `<cwd>/.acp-agent/config.yaml`). The card forbids that path, so I did not start the change.

    Alternative for the owner to decide: run the agent in the process with `ComposedAgent.compose(environment:)`, where only the `environment` value (not the process environment) names the stage configuration. This starts no program and needs no sibling checkout, but it keeps a config file.
  timestamp: 2026-10-12T15:10:45.116491+00:00
- actor: claude-code
  id: 01m4ran5cmmwekf3hfmjg4s4be
  text: |-
    ### implement — stuck
    - evidence: no file changed. Read `ComposedAgent.swift`, `RoutedACPAgent.swift`, `SessionSetup.swift`, `SessionList.swift`, `AgentConfiguration.swift` of FoundationModelsACPAgent (local 8506ea5, remote main 50d8785). No public API sets `TranscriptLocation.path(URL)` in code; each session load reads config files. Stub model: `ComposedAgent.ModelSource.stub` is available. No test run and no demo build, because no code changed.
    - next: the owner adds the missing API in FoundationModelsACPAgent (see the blocker comment), or accepts the in-process `environment` alternative. Then run implement again.
  timestamp: 2026-10-12T15:10:48.212958+00:00
- actor: claude-code
  id: 01m4rap0pg2tbyd5xbq4p0ka2q
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — FoundationModelsACPAgent has no public API to set the transcript location in code; compose(...) and each per-session load and list path read the config files only. No file changed.
    - test: not run
    - commit: not run
    - review: not run
    - next: 2026-10-12 the request was sent to the FoundationModelsACPAgent session (foundationmodelsacpagent-36): a `transcriptLocation` (or configuration override) on `ComposedAgent.compose(...)`, kept by `RoutedACPAgent` and used in SessionSetup.loadSessionContext, SessionList.listableRecords and allListableRecords. The stub model `ComposedAgent.ModelSource.stub` exists. When that commit is pushed, run implement again. Note: the ACP tab also starts the sibling acp-agent program (DemoLaunchOptions.defaultAgentCommand); by the owner rule it should also run in the process — a separate card.
  timestamp: 2026-10-12T15:11:16.176478+00:00
- actor: claude-code
  id: 01m4rapta82y1m216ccnemz4we
  text: '2026-10-12: FoundationModelsACPAgent accepted the request as its task 01M4RAPHKAPWWZMDJ9RRWF91AA. Planned API: `ComposedAgent.compose(..., transcriptLocation: TranscriptLocation? = nil)`; when not nil it wins over every config layer; it goes into the one shared config-load step, so session/new, resume, load and list (project and registry) use it. Tests there: `.path(dir)` with `ModelSource.stub` and no config files writes, lists and resumes in `dir`. It is in that session''s current batch; the owner pushes. Run implement again when the commit is pushed.'
  timestamp: 2026-10-12T15:11:42.408071+00:00
- actor: claude-code
  id: 01m4rh7xd55t50g87j99e7sbqn
  text: '2026-10-12: FoundationModelsACPAgent finished the in-code transcript location (its task ^rwf91aa), local commit f4d16a3, reviewed clean, NOT pushed (the owner pushes; the missing-cwd commits 613b69d, 36eb18c, 335a8b2 are also local). API: `ComposedAgent.compose(name:workingDirectory:environment:modelSource:stubChunkDelay:transcriptLocation:reporting:)` with `transcriptLocation: TranscriptLocation? = nil` (`.project`, `.home`, `.path(URL)`); when not nil it wins over every config layer, for session/new, resume, delete and both list paths. The agent has no session/load handler; session/resume is the restore path. Tested with `ModelSource.stub` and no config files. Run implement again after the owner pushes FoundationModelsACPAgent.'
  timestamp: 2026-10-12T17:05:54.085236+00:00
- actor: claude-code
  id: 01m4rjhnm5v8rd9rtct8kppg5p
  text: |-
    Research (2026-10-12, implement pass 2). FoundationModelsACPAgent origin/main is 8ec62b6 and has `ComposedAgent.compose(..., transcriptLocation:)`.

    Plan of the change:
    - `Package.swift`: add the FoundationModelsACPAgent package (SSH URL, branch main). Only the demo-only target `DemoSupport` links its product. The app compiles `Sources/DemoSupport`, so the generator gets the same package in `REMOTE_PACKAGES`.
    - `DemoAgent.makeInProcess(recordedSessions:)` composes the agent with `ModelSource.stub`, `transcriptLocation: .path(stage.transcriptsDirectory)`, and the dotfolder name of the demo, binds it with `composed.agent(boundTo:)` through `InProcessAgent.makeConnection`, and `stop()` calls `waitForConnectionTeardown()` after `disconnect()`.
    - The dotfolder name of the demo is not `acp-agent`, so the agent reads no user config file of `acp-agent` and writes nothing to `~/.config/acp-agent/projects.jsonl`. A replay-only resume (missing cwd) registers no project.
    - Remove from `RecordedSessionsStage`: the configuration home, the config file, `agentEnvironment(adding:)`, `XDG_CONFIG_HOME`. Remove `DemoAgent.makeConnected(recordedSessions:agentCommand:)`.
    - Shared code that stays for the ACP tab (card ^01M4RAP5MC4VGF4TS77WRQEM55): `DemoLaunchOptions.agentCommand`, `--agent-command`, `defaultAgentCommand`, `siblingAgentPath`, `agentArguments(for:)`, `DemoAgent.makeConnected(options:)`, `TerminalAppAuthRunner`. The Gallery tab no longer reads `DemoLaunchOptions`.
    - Doc and test checks to update: `Docs/decisions/dependencies.md` (DecisionRecordTests compares the table with the direct dependencies), ImportBoundaryTests (add: the kit target does not import FoundationModelsACPAgent).
  timestamp: 2026-10-12T17:28:42.373625+00:00
- actor: claude-code
  id: 01m4rjwqpaf1sebr1jry83gpzx
  text: |-
    Blocker (2026-10-12): FoundationModelsACPAgent and EditorKit cannot be in one SwiftPM package graph.

    What I did:
    - Added `.package(url: "git@github.com:swissarmyhammer/FoundationModelsACPAgent.git", branch: "main")` to `Package.swift`, linked only by `DemoSupport`. `swift package resolve` resolved the agent at main (8ec62b6).
    - `swift build --build-tests` then fails before it compiles a file:
      `error: multiple similar targets 'SwiftTreeSitter', 'SwiftTreeSitterLayer' appear in package 'swifttreesitter' and 'swift-tree-sitter'`

    Cause:
    - EditorKit depends on `https://github.com/tree-sitter/swift-tree-sitter.git` (identity `swift-tree-sitter`), exact 0.25.0.
    - FoundationModelsCodeContext (a dependency of the agent) depends on `https://github.com/ChimeHQ/SwiftTreeSitter` (identity `swifttreesitter`), exact 0.25.0. The tree-sitter grammar packages of its graph (tree-sitter-json, -cpp, -java, -rust, -ruby, -yaml, -markdown, -typescript, -c-sharp) also name the package `SwiftTreeSitter` in their own manifests.
    - The two identities are the same repository with the same target names.

    What did not work:
    - A local SwiftPM mirror (ChimeHQ URL to the tree-sitter URL) fails: each grammar package then reports `unknown dependency 'SwiftTreeSitter'`, because its manifest names the package by the ChimeHQ identity. A mirror in the other direction breaks the `package: "swift-tree-sitter"` reference of EditorKit in the same way. A mirror is also local state (`.swiftpm/` is git-ignored), so CI and Xcode would not get it.
    - `moduleAliases` cannot fix it in Xcode: the demo app links EditorKit and the agent package through the generated `.xcodeproj`, which has no module alias.

    Fix that is needed (another repository, not this card):
    - EditorKit: depend on `https://github.com/ChimeHQ/SwiftTreeSitter` (exact 0.25.0) and use `.product(name: "SwiftTreeSitter", package: "SwiftTreeSitter")`, so that the graph has one identity, the one that the grammar packages use. (FoundationModelsCodeContext cannot move to the tree-sitter URL, because the grammar packages name the ChimeHQ identity.)

    State of the working tree: I reverted each change of this pass (Package.swift, the tests) and resolved again, so the tree is at HEAD and `swift build --build-tests` is green. The partial diff and the new test file `RecordedSessionsAgentTests.swift` are kept in the session scratchpad only. The plan in the research comment above stays valid.
  timestamp: 2026-10-12T17:34:44.938117+00:00
- actor: claude-code
  id: 01m4rjwva2es3ksmdhnaw6g9m4
  text: |-
    ### implement — stuck
    - evidence: `swift package resolve` with FoundationModelsACPAgent (main 8ec62b6) succeeds; `swift build --build-tests` fails: "multiple similar targets 'SwiftTreeSitter', 'SwiftTreeSitterLayer' appear in package 'swifttreesitter' and 'swift-tree-sitter'" (EditorKit uses tree-sitter/swift-tree-sitter.git; FoundationModelsCodeContext and the tree-sitter grammar packages use ChimeHQ/SwiftTreeSitter). Local mirror tried, fails. All changes reverted; tree at HEAD, `swift build --build-tests` green. Full `swift test` and demo build not run, because no change stays. Load average 25.02 21.78 21.17.
    - next: the owner changes EditorKit to the ChimeHQ/SwiftTreeSitter URL (or decides another fix of the SwiftTreeSitter identity conflict). Then run implement again.
  timestamp: 2026-10-12T17:34:48.642432+00:00
- actor: claude-code
  id: 01m4rjxh02jm3ycrb82hcmdaar
  text: |-
    ### finish iteration 2 — stuck
    - implement: stuck — FoundationModelsACPAgent (8ec62b6) and EditorKit cannot be in one SwiftPM graph: "multiple similar targets 'SwiftTreeSitter', 'SwiftTreeSitterLayer' appear in package 'swifttreesitter' and 'swift-tree-sitter'". EditorKit uses https://github.com/tree-sitter/swift-tree-sitter.git; FoundationModelsCodeContext and the tree-sitter grammar packages use https://github.com/ChimeHQ/SwiftTreeSitter. A local mirror failed (grammar packages report "unknown dependency 'SwiftTreeSitter'") and is local state only. All changes reverted; tree at HEAD; build green. Partial patch and test in the session scratchpad (wv9bpnv-partial.patch, RecordedSessionsAgentTests.swift).
    - test: not run
    - commit: not run
    - review: not run
    - next: EditorKit must depend on https://github.com/ChimeHQ/SwiftTreeSitter (exact 0.25.0) with `.product(name: "SwiftTreeSitter", package: "SwiftTreeSitter")`. No EditorKit session is open on 2026-10-12; the owner must open one or decide. Then move the EditorKit pin and run implement again.
  timestamp: 2026-10-12T17:35:10.850459+00:00
- actor: claude-code
  id: 01m4rphevwxqxbcdfz0xj3ypw7
  text: |-
    Pass 3 (2026-10-12): the blocker is gone.
    - `swift package update EditorKit` moved EditorKit to main 65393f5. The graph now uses https://github.com/ChimeHQ/SwiftTreeSitter 0.25.0 only (SwiftPM removed tree-sitter/swift-tree-sitter.git).
    - Added FoundationModelsACPAgent (branch main, resolved 8ec62b6), linked only by `DemoSupport`. `swift package resolve` is green.
    - Two more local pins had to move before `DemoSupport` built: FoundationModelsExtras 130eb40 -> main d1a9031 (FoundationModelsRouter 9de67e9 needs `PooledEmbedding.dimension`), and swift-distributed-tracing 1.5.0 -> 1.6.0 (FoundationModelsMultitool 8e70406 needs `InstrumentationContext`). `Package.resolved` is git-ignored, and CI resolves from zero, so CI gets these versions too. Then `swift build --target DemoSupport` is green.
    - The agent writes `projects.jsonl` in the user layer of its dotfolder name only for a session that is not replay-only (`SessionSetup.activateSession`). A recorded session with a missing cwd writes nothing there.
  timestamp: 2026-10-12T18:38:29.756997+00:00
- actor: claude-code
  id: 01m4rqdbfkkyknyzcvjsgjnh63
  text: |-
    Implementation landed (pass 3, not committed).

    What changed:
    - `Package.swift`: FoundationModelsACPAgent (SSH, branch main), product linked only by `DemoSupport` (`demoAgentProducts`). The demo generator `REMOTE_PACKAGES` gets the same package.
    - `DemoAgent.makeInProcess(recordedSessions:)`: `ComposedAgent.compose(name: DotfolderName("agentviewkit-demo"), workingDirectory: stage.workingDirectory, modelSource: .stub, transcriptLocation: .path(stage.transcriptsDirectory))`, bound with `composed.agent(boundTo:)` through `InProcessAgent.makeConnection`. `stop()` calls `waitForConnectionTeardown()` after `disconnect()`. `makeConnected(recordedSessions:agentCommand:)` is removed.
    - `RecordedSessionsStage`: the configuration home, the config file, `agentEnvironment(adding:)` and `XDG_CONFIG_HOME` are removed. The stage holds only `transcripts/` and `working-directory/`.
    - `GalleryTabView` reads no launch option (no `options` property). `DemoRootView` makes `GalleryTabView()`.
    - Docs: README, `RecordedSessions/README.md` (Gallery start paragraph only; the recording steps stay, because they record new sessions with the program), `DemoLaunchOptions` doc, `GalleryTabEndToEndTests` doc, `Docs/decisions/dependencies.md` (new section "The demo-only package"; the kit table stays the kit direct dependencies, so DecisionRecordTests stays green).
    - Tests: new `RecordedSessionsAgentTests` (4 tests: list, resume from start of each listed session, in-process with no terminal sign-in, stop gives disconnected). `ImportBoundaryTests.theKitTargetDoesNotImportTheAgentPackage`. The stage test of the config file and of the environment is replaced by `theStageHoldsOnlyTheTranscriptLocationAndTheWorkingDirectory`. The DemoAgent test of a relative Gallery program is removed with its code.

    Code that stays for the ACP tab card ^01M4RAP5MC4VGF4TS77WRQEM55: `DemoLaunchOptions.agentCommand`, `--agent-command`, `defaultAgentCommand`, `siblingAgentPath`, `agentArguments(for:)`, `DemoAgent.makeConnected(options:)`, `TerminalAppAuthRunner`, `ACPSettingsSheet` agent command row.

    Discovery: on this computer the recorded `cwd` of each recorded session still exists (temporary directories of the recording runs, and `recording-run/work` in the session scratchpad). For those sessions the resume is not replay-only, so the agent registers the project in `~/.config/agentviewkit-demo/projects.jsonl` and FoundationModelsCodeContext writes `.code-context/` in that `cwd`. On CI and on other computers these directories are missing, so the agent replays with no tools and writes nothing. The agent also logs to stderr (swift-log default handler) during the tests; no test fails from it.

    CI: the Gallery UI test is not run on this computer (owner rule). It must be checked on CI after the push.
  timestamp: 2026-10-12T18:53:43.795939+00:00
- actor: claude-code
  id: 01m4rqdjakc01mybynf3fet7bt
  text: |-
    ### implement — changed
    - evidence: pins (Package.resolved, git-ignored): EditorKit 95ef6c4 -> 65393f5 (graph now has only ChimeHQ/SwiftTreeSitter 0.25.0), FoundationModelsACPAgent added at 8ec62b6, FoundationModelsExtras 130eb40 -> d1a9031 and swift-distributed-tracing 1.5.0 -> 1.6.0 (both needed to compile FoundationModelsRouter 9de67e9 and FoundationModelsMultitool 8e70406). API: `ComposedAgent.compose(name:workingDirectory:modelSource: .stub, transcriptLocation: .path(URL))`, `agent(boundTo:)`, `waitForConnectionTeardown()`. Files: Package.swift, Sources/DemoSupport/{DemoAgent,RecordedSessionsStage,DemoLaunchOptions}.swift, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/{GalleryTabView,DemoRootView}.swift, Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb, Examples/AgentViewKitDemo/Tests/GalleryTabEndToEndTests.swift (doc only), Examples/AgentViewKitDemo/RecordedSessions/README.md, README.md, Docs/decisions/dependencies.md, Tests/AgentViewKitTests/ACP/{RecordedSessionsAgentTests (new),RecordedSessionsStageTests,DemoAgentTests}.swift, Tests/PackageStructureTests/ImportBoundaryTests.swift. `swift test`: 1165 tests in 130 suites passed (2 known issues, the same as before) and 123 tests in 15 suites passed; load average 35.82 before, 34.94 after. Demo project regenerated; `xcodebuild build-for-testing -skipMacroValidation -skipPackagePluginValidation`: TEST BUILD SUCCEEDED (load 33.88 -> 54.28). ResolvedPinsTests 2/2 green with the generated project. UI tests not run.
    - next: /review. After the commit and push, check that CI runs GalleryTabEndToEndTests green.
  timestamp: 2026-10-12T18:53:50.803996+00:00
- actor: claude-code
  id: 01m4rr093c617dwa4snm4hyypx
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (0e61008); 3 findings (3 confirmed, 1 refuted) — Sources/DemoSupport/DemoAgent.swift:182, Tests/AgentViewKitTests/ACP/RecordedSessionsAgentTests.swift:95, Tests/PackageStructureTests/ImportBoundaryTests.swift:57
    - next: implement the 3 open items in the Review Findings section of 2026-10-12 14:00, then test, commit and review again.
  timestamp: 2026-10-12T19:04:03.948272+00:00
- actor: claude-code
  id: 01m4rr0tky63hjs6ja62dssrsy
  text: |-
    ### finish iteration 3 — findings
    - implement: changed — in-process ComposedAgent for the Gallery (stub model, transcriptLocation .path); pins EditorKit 65393f5, FoundationModelsACPAgent 8ec62b6, FoundationModelsExtras d1a9031, swift-distributed-tracing 1.6.0
    - test: green — swift test, 1165 tests passed, 2 expected known issues, load average 39 to 67; the run wrote ~/.config/agentviewkit-demo/projects.jsonl and .code-context folders on this machine (follow-up card 01M4RQRJE02Q59FCT73PNDR0C1)
    - commit: 0e61008
    - review: findings — Sources/DemoSupport/DemoAgent.swift:182, Tests/AgentViewKitTests/ACP/RecordedSessionsAgentTests.swift:95, Tests/PackageStructureTests/ImportBoundaryTests.swift:57
  timestamp: 2026-10-12T19:04:21.886124+00:00
- actor: claude-code
  id: 01m4rrg6p8450rfnvbd97vh391
  text: |-
    Pass 4 (2026-10-12): the 3 review findings are fixed (not committed).

    - DemoAgent: new private helper `makeInProcess(serving:workingDirectory:waitForTeardown:)` connects through `InProcessAgent.makeConnection(serving:)` and calls `makeStarted`. `makeInProcess(script:workingDirectory:)` and `makeInProcess(recordedSessions:)` now give only their agent constructor (and the recorded agent gives `composed.waitForConnectionTeardown`).
    - DemoAgentTests: new `InProcessAgentFactory` (`scriptedInMemory`, `recordedSessions`; `start()` gives the agent and the removal of the stage files). `stopMakesTheStateOfTheModelDisconnected(factory:)` runs over both agents. The copy in RecordedSessionsAgentTests is removed. The same cause was in the file one more time: `theAgentRunsInThisProcessWithNoTerminalSignIn` (RecordedSessionsAgentTests) repeated `theInMemoryAgentHasNoTerminalSignIn` (DemoAgentTests). Both are now one test, `anAgentInThisProcessIsConnectedWithNoTerminalSignIn(factory:)`. RecordedSessionsAgentTests no longer imports AgentViewKitTestSupport (`waitUntil` was its only use).
    - ImportBoundaryTests: `boundaries` holds the (directory, forbidden) pairs: ("Sources", forbiddenInSources), (kitSourcesPath, [agentModule]), and each of swiftDirectories with [mergedModule]. One test `noSwiftFileCrossesTheImportBoundaryOfItsDirectory(directory:forbidden:)` runs over them, through the helper `expectNoImport(below:of:)`. `scannerAcceptsTheCleanFixture` also uses the helper. The three old boundary tests are removed.
    - Note: the validator dump for `.swift` was 750 KB (12,098 lines) and was too large to read in one call; I used the rule headings and the finding text.
  timestamp: 2026-10-12T19:12:45.768315+00:00
- actor: claude-code
  id: 01m4rrg9rs0nafq24bkgawq0b2
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/DemoSupport/DemoAgent.swift, Tests/AgentViewKitTests/ACP/DemoAgentTests.swift, Tests/AgentViewKitTests/ACP/RecordedSessionsAgentTests.swift, Tests/PackageStructureTests/ImportBoundaryTests.swift. `swift build --build-tests` green. `swift test`: 1163 tests in 130 suites passed (2 known issues, the same as before) and 121 tests in 15 suites passed; the two parameterized DemoAgent tests passed with 2 cases each, the boundary test with 5 cases. Load average 29.24 33.82 38.00 before, 31.72 32.42 36.38 after. UI tests not run. All 3 findings checked.
    - next: /test, /commit, then /review.
  timestamp: 2026-10-12T19:12:48.921518+00:00
- actor: claude-code
  id: 01m4rrxcza07kpxk5dss8aqd0y
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (e0d6af9). 4 files reviewed. 0 findings, 0 confirmed, 0 refuted. All prior findings are checked.
    - next: The task is in done.
  timestamp: 2026-10-12T19:19:58.186341+00:00
- actor: claude-code
  id: 01m4rrxpjwsvn86kcaqcs01jsd
  text: |-
    ### finish iteration 4 — clean
    - implement: changed — one makeInProcess(serving:...) helper; agent tests over InProcessAgentFactory; one parameterized import boundary test; 3 findings checked
    - test: green — swift test, 1163 tests passed, 2 expected known issues, load average 20 to 33
    - commit: e0d6af9
    - review: clean — 0 findings (4 files); task in done
  timestamp: 2026-10-12T19:20:08.028813+00:00
position_column: done
position_ordinal: ffb480
title: 'Gallery: run FoundationModelsACPAgent in the process through its package, not as a sibling program'
---
## What
Decision of the owner (2026-10-12): the Gallery must reference the FoundationModelsACPAgent package and run the agent in the process (inline), not start the sibling program `FoundationModelsACPAgent/.build/release/acp-agent` as a shell command.

Today the Gallery (^x7jcat5, ^z13s3dd) starts `acp-agent acp` from the sibling checkout with a temporary `XDG_CONFIG_HOME` whose `config.yaml` sets `transcripts: location: <copy>`. CI has no sibling checkout, so `GalleryTabEndToEndTests.testOpeningARecordedSessionShowsItsTranscript` fails with "The start of the Gallery failed" (CI run 38248679318, rerun). The four ACP tab UI tests pass in that run, which confirms the crash fix of ^nh1h15p.

## Work
- [x] Add FoundationModelsACPAgent as a package dependency of the demo app only (the xcodeproj generator `remote_packages`, branch `main`), or of a demo-only target. The kit (`AgentViewKit`) must not import it. Keep `ImportBoundaryTests` green, and add a check if it does not cover this.
- [x] Start the agent in the process with the public API (for example `ComposedAgent.compose(...)` and `composed.agent(boundTo:)`, as the README quick start shows), with the transcript location set to the temporary copy of the recorded sessions (`TranscriptLocation.path(URL)` in the configuration), not through `XDG_CONFIG_HOME` and a config file.
- [x] The connection uses the in-process transport, the same as `InProcessAgent` / `makeInProcess`. Remove the code that starts the sibling program for the Gallery, and any launch option, environment or doc that only that path used (check `DemoLaunchOptions` and the README). Do not leave a second way.
- [x] If the ACP tab or other code also starts the sibling `acp-agent` program, record it; do not change it on this card unless it is the same code.
- [x] Tests: the package test that opens the recorded sessions runs the in-process agent (no sibling binary). The Gallery UI test must pass on CI. Do not run UI tests on this machine.
- [x] Update the README and `RecordedSessions/README.md`.

## Review Findings (2026-10-12 14:00)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 12 file(s) reviewed, 9 not reviewed.

> 6 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 6 file(s)

> 3 file(s) not reviewed — no validator matched:
> - `Docs/decisions/dependencies.md` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/README.md` — no validator matches this file
> - `README.md` — no validator matches this file

- [x] `Sources/DemoSupport/DemoAgent.swift:182` `reuse/reuse` — The new makeInProcess(recordedSessions:) repeats the connect-and-start sequence of makeInProcess(script:): it calls InProcessAgent.makeConnection with a closure that builds the agent, then calls makeStarted. Only the agent constructor differs. Two copies of this sequence can drift apart when the in-process startup changes. Extract a private static helper that takes the agent factory closure, for example makeInProcess(agent: (AgentConnection) -> any Agent, workingDirectory:, waitForTeardown:). Then makeInProcess(script:) and makeInProcess(recordedSessions:) each pass only their own agent constructor. Keep the per-case constructors where they are.
- [x] `Tests/AgentViewKitTests/ACP/RecordedSessionsAgentTests.swift:95` `reuse/reuse` — The new test stopMakesTheStateOfTheModelDisconnected repeats the existing stop test of DemoAgentTests. Both start an agent, call stop, and wait until the model state is .disconnected. The copy can drift from the original. Check whether the existing DemoAgentTests stop test already covers the recorded-sessions agent once it is parameterized over the agent factory. If it does, remove this copy. If the start helper must differ, keep the test and add a comment that says why it is separate.
- [x] `Tests/PackageStructureTests/ImportBoundaryTests.swift:57` `reuse/reuse` — The new test theKitTargetDoesNotImportTheAgentPackage repeats the body of noSourceTargetImportsAFoundationModelsRuntime. Only the directory and the forbidden set differ. A second copy of the scan-and-assert logic can drift from the first. Parameterize the existing test over (directory, forbidden) pairs with @Test(arguments:), or move the shared assertion into a helper that both tests call. Keep the two constants, Self.kitSourcesPath and Self.agentModule, as the parameters.
