---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4rt8jkhy3gnvf0x9mxcdpzd
  text: 'Decision of the owner (2026-10-12): the ACP tab runs FoundationModelsACPAgent in the process by default (ComposedAgent with the live model source). The UI tests keep the in-memory demo agent through a launch option. Remove the sibling acp-agent program path.'
  timestamp: 2026-10-12T19:43:32.977467+00:00
- actor: claude-code
  id: 01m4rtfv45dtby4ewxjv8amh18
  text: |-
    Research (2026-10-12, implement pass 1):

    - `ComposedAgent.compose(name:workingDirectory:environment:modelSource:stubChunkDelay:transcriptLocation:reporting:)` is public. `modelSource: .live` builds `Router(loader: LiveModelLoader())`; the profile resolves inside the compose call, so the live path can download and load a model at compose time. Thus no test may call compose with `.live`. The tests use `.stub` through the same helper.
    - Production users of the program path: only `DemoAgent.makeConnected(options:)` (ACP tab). It is the only maker of a transport factory and of `TerminalAppAuthRunner`. `canReconnect`, `reconnect(onOpen:)` and `terminalAuthRunner` are non-nil/true only for that path. After the removal they are dead code in the app.
    - Terminal sign-in: `TerminalAppAuthRunner` runs the agent program in Terminal.app. With an agent in the process there is no program to run, so the feature cannot exist in the demo. The in-memory agent has only an `agent` auth method, so the `agent` sign-in retry (`retryFailedOperation()`) stays. The kit terminal sign-in (AgentAuthView, `terminalAuthRunner` and `agentReconnect` environment values) stays in the kit and keeps its kit tests with fakes.
    - `DemoAgentTerminalSignInTests` uses the internal `makeConnected(makeTransport:terminalAuthRunner:workingDirectory:)` with ScriptedWireAgent transports, not the program path. The terminal tests go with the feature. The two `agent` sign-in tests stay, over a ConnectionModel that a test connects to a ScriptedWireAgent.
    - Plan: `DemoLaunchOptions.acpAgent` (in-memory, or FoundationModelsACPAgent with a model source; default `.live`; `--in-memory-agent` selects the in-memory agent). `DemoAgent.makeInProcess(options:)` replaces `makeConnected(options:)`. One helper `makeInProcess(composing:modelSource:transcriptLocation:)` composes FoundationModelsACPAgent for the ACP tab and for the Gallery, through `makeInProcess(serving:...)`.
  timestamp: 2026-10-12T19:47:31.077414+00:00
- actor: claude-code
  id: 01m4rv7wnmzmp5jyx1v4rhexp3
  text: |-
    Implementation landed (pass 1, not committed).

    What changed:
    - `DemoLaunchOptions`: new `DemoACPAgent` (`.inMemory`, `.foundationModels(ComposedAgent.ModelSource)`) and `acpAgent`, default `.foundationModels(.live)`; `--in-memory-agent` selects `.inMemory`. `agentName` gives `DemoLaunchOptions.foundationModelsAgentName` (`RoutedACPAgent.implementation.name`) or the in-memory name. Removed `agentCommandArgument`, `agentCommand`, `defaultAgentCommand`, `siblingAgentPath`, `acpAgentProgramName`, `acpSubcommand`, `agentArguments(for:)`, `processAgentName`, `usesInMemoryAgent`.
    - `DemoAgent`: `makeInProcess(options:)` replaces `makeConnected(options:)`. One private helper `makeInProcess(foundationModelsIn:modelSource:transcriptLocation:)` composes FoundationModelsACPAgent (dotfolder name `agentviewkit-demo`) and goes through `makeInProcess(serving:...)`; the ACP tab uses it with `.live`, the Gallery with `.stub` and `.path(stage)`. Removed the transport factory, `terminalAuthRunner`, `canReconnect`, `reconnect(onOpen:)`, both `makeConnected` functions. `makeStarted(connection:workingDirectory:waitForTeardown:)` is internal and takes a connected model. `makeInitializeRequest()` has no parameter.
    - Removed `TerminalAppAuthRunner` and its tests: it runs the agent program in Terminal.app, and no agent runs as a program now, so the demo terminal sign-in cannot exist. The kit terminal sign-in (AgentAuthView, `terminalAuthRunner`, `agentReconnect`) is unchanged and keeps its kit tests.
    - `ACPTabView`: starts `DemoAgent.makeInProcess(options:)`; no terminal runner and no reconnect. `ACPSettingsSheet`: the Command row is removed.
    - Tests: `DemoAgentTests` adds the `.acpTab` factory case (FoundationModelsACPAgent as the ACP tab starts it, with `.stub`, in a temporary cwd) and `theACPTabAgentWorksInTheWorkingDirectoryOfTheOptions`. `DemoAgentSignInTests` keeps the two `agent` sign-in retry tests over a ConnectionModel connected to a ScriptedWireAgent; the 7 terminal and reconnect tests are removed with the feature. `DemoLaunchOptionsTests` reads `acpAgent` and `agentName`. `RemovedVocabularyTests.noFileUsesTheRemovedAgentProgram` holds Sources, Tests/AgentViewKitTests, Examples and README free of the removed symbols.
    - Docs: README (demo app section, launch arguments, the version note), `Docs/decisions/dependencies.md`, `Package.swift` comments, `generate_xcodeproj.rb` comment, the doc comments of the two UI tests.

    Note: the ACP tab transcript location is the agent default (no override), because the owner gave none; with the dotfolder name `agentviewkit-demo` the agent reads no `acp-agent` user config. No test composes with `.live`.
  timestamp: 2026-10-12T20:00:39.092095+00:00
- actor: claude-code
  id: 01m4rv81qmkefgmb4ddnzd4rsc
  text: |-
    ### implement — changed
    - evidence: 16 source/doc files (2 deleted): Sources/DemoSupport/{DemoAgent,DemoLaunchOptions}.swift, Sources/DemoSupport/TerminalAppAuthRunner.swift (deleted), Examples/AgentViewKitDemo/AgentViewKitDemoFeature/{ACPTabView,ACPSettingsSheet}.swift, Examples/AgentViewKitDemo/Tests/{ACPTabEndToEndTests,GalleryTabEndToEndTests}.swift (doc only), Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb (comment), Package.swift (comments), README.md, Docs/decisions/dependencies.md, Tests/AgentViewKitTests/ACP/{DemoAgentTests,DemoLaunchOptionsTests,KitInitializeRequestTests}.swift, Tests/AgentViewKitTests/ACP/TerminalAppAuthRunnerTests.swift (deleted), Tests/PackageStructureTests/RemovedVocabularyTests.swift. RED seen first (missing `acpAgent`/`foundationModelsAgentName`; `noFileUsesTheRemovedAgentProgram` failed). `swift test`: 1147 tests in 129 suites passed (2 known issues, same as before), 122 tests in 15 suites passed, 1 snippet test passed; load average 38.94 before, 32.27 after. Demo project regenerated; `xcodebuild -skipMacroValidation -skipPackagePluginValidation build-for-testing`: TEST BUILD SUCCEEDED (load 27.92 before, 26.10 after). UI tests not run. No live model run.
    - next: /review.
  timestamp: 2026-10-12T20:00:44.276593+00:00
- actor: claude-code
  id: 01m4rvpqjd86cxh1rxp580q6ky
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (e785f42): 1 finding, 1 confirmed, 0 refuted. Tests/PackageStructureTests/RemovedVocabularyTests.swift:495 (duplication/duplication).
    - next: Extract one shared helper (or one parameterized test) for the removed-symbol search in RemovedVocabularyTests.swift. Make the new test noFileUsesTheRemovedAgentProgram call it. Then run the tests, commit, and review again.
  timestamp: 2026-10-12T20:08:45.389370+00:00
- actor: claude-code
  id: 01m4rvq1x91geas5h5rkczc1h7
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — ACP tab runs FoundationModelsACPAgent in the process (live model); sibling program path, --agent-command, makeConnected and the demo terminal sign-in removed
    - test: green — swift test, 1147 tests passed, 2 expected known issues, load average 18 to 28
    - commit: e785f42
    - review: findings — Tests/PackageStructureTests/RemovedVocabularyTests.swift:495
  timestamp: 2026-10-12T20:08:55.977923+00:00
- actor: claude-code
  id: 01m4rw1wx6w81x4kmrbdr70rsg
  text: |-
    Implement pass 2 (finding fix, not committed).

    - Finding `RemovedVocabularyTests.swift` duplication: fixed for the whole file, not only for the named test. New helper `expectNoUse(of:below:inFiles:sourceLocation:)` holds the scan and the expectation. The default directories are `swiftPaths` and the default other files are the README. Seven tests are now one call each: `noFileUsesTheRemovedValueCopies`, `sourcesUseNoRemovedSymbol` (`below: [sourcesPath], inFiles: []`), `theDemoAppAndItsTestsUseNoRemovedDemoSymbol` (`inFiles: []`), `noFileUsesTheRemovedAgentProgram`, `noFileUsesTheRemovedACPAdapter`, `noFileUsesTheRemovedSessionModel`, `noFileUsesTheRelativeTimeOfTheMessageHeader`.
    - The same repeated body was also in the four whole-text pattern tests. New helper `expectNoFile(matching:sourceLocation:)` over `fileNames(matching:)`. `noFileCallsTheRemovedThreadInitializer`, `noFileGivesTheWorkingDirectoryToAView`, `noFileGivesThreadActionsToTheThreadView`, `noFileGivesADateToAMessageView` are one call each.
    - Both helpers take `sourceLocation: SourceLocation = #_sourceLocation`, as the other test helpers do (`NameChecks`, `KitInitializeRequestTests`), so a failure points at the test.
    - Not changed: `theKitDeclaresNoTypeWithTheNameOfAnACPValueType` and `sourcesCallNoRemovedInitializer` use other line matchers (type declarations, initializer labels), so their bodies are not the same.
    - The tests keep the same names and scopes, so no behavior changed. There is no new production code, so no RED step.
  timestamp: 2026-10-12T20:14:51.302233+00:00
- actor: claude-code
  id: 01m4rw22h8qcdt0m2vktk80qd3
  text: |-
    ### implement — changed
    - evidence: 1 file — Tests/PackageStructureTests/RemovedVocabularyTests.swift. Finding RemovedVocabularyTests.swift:495 (duplication/duplication) checked. `swift test`: 1147 tests in 129 suites passed (2 known issues, same as before), 122 tests in 15 suites passed, 1 snippet test passed; exit 0. Load average 17.56 before, 19.61 after. One build-system line `warning: missing creator for mutated node` for the mlx-swift_Cmlx.bundle in .build (not from this change). UI tests not run.
    - next: /test, then /commit, then /review.
  timestamp: 2026-10-12T20:14:57.064524+00:00
depends_on:
- 01M4RAHKJVTQFR205BQWV9BPNV
position_column: doing
position_ordinal: '80'
title: 'ACP tab: run FoundationModelsACPAgent in the process, not the sibling acp-agent program'
---
## What
Owner rule (2026-10-12): reference our packages and run them in the process; never start a binary from a sibling checkout. The ACP tab of the demo still starts `FoundationModelsACPAgent/.build/release/acp-agent` through `DemoLaunchOptions.defaultAgentCommand`, `--agent-command` and `DemoAgent.makeConnected(options:)`.

## Work
- [x] Decide with the owner what the ACP tab must show by default: the in-memory demo agent (as the UI tests use today), or FoundationModelsACPAgent in the process (`ComposedAgent` with a model source). Record the decision. Owner decision (2026-10-12): FoundationModelsACPAgent in the process with the live model (`ComposedAgent.compose(..., modelSource: .live, ...)`), through the same in-process helper as the Gallery. The UI tests keep the in-memory demo agent through `--in-memory-agent`.
- [x] Remove the sibling-program path (`defaultAgentCommand`, `siblingAgentPath`, `agentArguments(for:)` and the `--agent-command` option if nothing else needs them), and the docs that describe it. Also removed: `DemoAgent.makeConnected(options:)`, the transport factory and reconnect path of `DemoAgent`, and `TerminalAppAuthRunner` (nothing else needs them).
- [x] If an external ACP agent program must stay possible (a real external agent such as another vendor), keep only a generic "external program" option that the user gives, with no sibling path. Not kept: the owner decision lists `--agent-command` for removal. A host can still connect an agent program through the kit (`AgentProcess`, README quick start "An ACP agent").
- [x] Tests and README.

This card depends on the in-process Gallery card (^wv9bpnv) because both change DemoAgent and DemoLaunchOptions.

## Review Findings (2026-10-12 15:05)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 14 file(s) reviewed, 4 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 2 file(s) not reviewed — no validator matched:
> - `Docs/decisions/dependencies.md` — no validator matches this file
> - `README.md` — no validator matches this file

> ⚠️ tool rule 'code-hygiene/disallowed-constructs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> disallowed-constructs-swift found no file at Sources/DemoSupport/TerminalAppAuthRunner.swift, so its constructs are unread

> ⚠️ tool rule 'code-hygiene/disallowed-constructs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> disallowed-constructs-swift found no file at Tests/AgentViewKitTests/ACP/TerminalAppAuthRunnerTests.swift, so its constructs are unread

> ⚠️ tool rule 'code-hygiene/function-length-swift' declined an item — it judged the rest of the code, and this it could not judge:
> function-length-swift found no file at Sources/DemoSupport/TerminalAppAuthRunner.swift, so its bodies are unread

> ⚠️ tool rule 'code-hygiene/function-length-swift' declined an item — it judged the rest of the code, and this it could not judge:
> function-length-swift found no file at Tests/AgentViewKitTests/ACP/TerminalAppAuthRunnerTests.swift, so its bodies are unread

> ⚠️ tool rule 'code-hygiene/idioms-swift' declined an item — it judged the rest of the code, and this it could not judge:
> idioms-swift found no file at Sources/DemoSupport/TerminalAppAuthRunner.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/idioms-swift' declined an item — it judged the rest of the code, and this it could not judge:
> idioms-swift found no file at Tests/AgentViewKitTests/ACP/TerminalAppAuthRunnerTests.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/magic-numbers-swift' declined an item — it judged the rest of the code, and this it could not judge:
> magic-numbers-swift found no file at Sources/DemoSupport/TerminalAppAuthRunner.swift, so its literals are unread

> ⚠️ tool rule 'code-hygiene/magic-numbers-swift' declined an item — it judged the rest of the code, and this it could not judge:
> magic-numbers-swift found no file at Tests/AgentViewKitTests/ACP/TerminalAppAuthRunnerTests.swift, so its literals are unread

> ⚠️ tool rule 'code-hygiene/missing-docs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> missing-docs-swift found no file at Sources/DemoSupport/TerminalAppAuthRunner.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/missing-docs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> missing-docs-swift found no file at Tests/AgentViewKitTests/ACP/TerminalAppAuthRunnerTests.swift, so its declarations are unread

- [x] `Tests/PackageStructureTests/RemovedVocabularyTests.swift:495` `duplication/duplication` — The new test noFileUsesTheRemovedAgentProgram repeats the body of the two tests below it. Only the symbol list and the README search differ. The three copies can drift apart, so a fix to one test can miss the others. Extract a helper such as `static func assertNoUse(of symbols: [String]) throws` that holds the search and the expectation. Have each test call it with its own symbol list. Alternatively, use one parameterized `@Test(arguments:)` over the three symbol lists. Keep the new test as a one-line call to the helper.
