---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4c0rtyw9vektvtqtfqxg8w7
  text: |-
    Research:
    - Client pin 36f3249: `SessionModel.cwd` is `AbsolutePath?` (nil only in a model that a unit test makes directly). `SessionModel.additionalDirectories` is `[AbsolutePath]` (empty means no additional root). The client sets both after a successful `session/new` or `session/resume`.
    - `ConnectionModel.resumeSession(_:)` throws `unsupported` and sends nothing when the request has additional directories and `canUseAdditionalDirectories` is false. Thus a test that sends additional directories must give an `initialize` result with `session.additionalDirectories: {}`.
    - `SessionInfo.additionalDirectories` is `[AbsolutePath]?`. The picker can send it as is.
    - Callers of the `workingDirectory:` input: `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift`, `Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift`. The README does not use it. `DemoAgent.makeConnected(workingDirectory:)` is a different API and stays.
    - `ScriptedSession.open` sends `session/new` with the cwd only. The banner test needs a session with two additional directories, so `open` gets an `additionalDirectories:` input.
  timestamp: 2026-10-07T20:27:09.660448+00:00
- actor: claude-code
  id: 01m4c1fp7nav8y2t43pezb6ma8
  text: |-
    Implementation notes:
    - RED: the three new tests failed for the expected reason. The Reload frame and the picker frame had no `additionalDirectories`. `noFileGivesTheWorkingDirectoryToAView` found the callers. The first form of the regex did not find the DocC link `AgentThreadView/init(session:connection:workingDirectory:actions:)`, because the default word boundary does not break at `:` between two letters. The regex now uses `.wordBoundaryKind(.simple)`, as `wholeWord(_:)` does.
    - The Reload button also needs `session.cwd`, because `ResumeSessionRequest.cwd` is not optional. A model with no `cwd` (a model that no `session/new` or `session/resume` opened) shows no Reload button. The doc comment of `SessionStreamBanner` tells this.
    - The picker sends `info.additionalDirectories` as is. When a row has directories and the agent does not advertise `session.additionalDirectories`, the client throws `unsupported` and the picker shows the error. The picker does not drop the list.
    - `ScriptedSession.open` has a new `additionalDirectories:` input. With a list, the `initialize` result advertises `session.additionalDirectories` (`ScriptedSession.additionalDirectoriesInitializeResult`, public, also used by the picker test).
    - `RemovedVocabularyTests`: the file scan of the thread initializer and the new scan share the helper `fileNames(matching:)`.
    - `AgentThreadView.swift` no longer imports `FoundationModelsACP`. Only `AbsolutePath` needed it.
    - `Scripts/test-examples.sh` prints the toolchain line "appintentsmetadataprocessor warning: Metadata extraction skipped, no AppIntents.framework dependency found". It is not from this change.
  timestamp: 2026-10-07T20:39:38.485938+00:00
- actor: claude-code
  id: 01m4c1fskynsxhjnkm7dhq82zf
  text: |-
    ### implement — changed
    - evidence: 9 files — Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Thread/SessionTranscriptEnvironment.swift, Sources/AgentViewKit/Status/SessionStreamBanner.swift, Sources/AgentViewKit/Sessions/SessionListView.swift, Sources/AgentViewKitTestSupport/ScriptedSession.swift, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift, Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift, Tests/AgentViewKitTests/Sessions/SessionPickerConnectionModelHostedTests.swift, Tests/PackageStructureTests/RemovedVocabularyTests.swift. Filtered run: 13 + 23 tests pass. `swift test`: 1310 tests in 127 suites, 85 tests in 12 suites, 1 test pass, 0 failures. `Scripts/check-readme.sh` passed. `Scripts/test-examples.sh AgentViewKitDemo`: BUILD SUCCEEDED, 4 tests, TEST SUCCEEDED.
    - next: /review
  timestamp: 2026-10-07T20:39:41.950628+00:00
- actor: claude-code
  id: 01m4c1xqse6sgevsbcw9acktfs
  text: |-
    ### test — green
    - evidence: `swift test` — 1310 tests in 127 suites passed, 0 failed, 0 skipped. `Scripts/check-readme.sh` — passed (3 snippets compile). `Scripts/test-examples.sh AgentViewKitDemo` — passed (4 UI tests, 0 failures).
    - warnings: only the two expected ones (mlx-swift "missing creator for mutated node", Xcode "Metadata extraction skipped").
    - time-limit failures: none. Load not measured.
    - next: review/commit. No file was changed by this step.
  timestamp: 2026-10-07T20:47:18.830984+00:00
depends_on:
- 01M443RA2PMKC5MXXBNH1116AB
- 01M4BHMJNEVT7DQ6KHVZTXQXVH
position_column: doing
position_ordinal: '80'
title: Resume and reload from SessionModel.cwd and additionalDirectories
---
## Start condition
The pin task ^ztxqxvh moves the pins; this task starts after it.

## What
Rule: the agent streams to FoundationModelsACPClient over ACP. The client keeps an observable state. The kit views bind directly to that state and keep no state or logic of their own.

ACP v2 tells that a resume must send the same `cwd` and the full `additionalDirectories` of the session. Task ^dpg4t4z added the input `workingDirectory:` to `AgentThreadView.init(session:connection:workingDirectory:actions:)`, because the session model did not hold the working directory. The host gives a copy of a model value, and the Reload button sends no `additionalDirectories`. The session picker sends `info.cwd` and no `additionalDirectories`.

Subtasks:
- [x] In `Sources/AgentViewKit/Thread/AgentThreadView.swift`, remove the `workingDirectory:` input, the `workingDirectory` property and their doc comments. The initializer becomes `init(session:connection:actions:)`. Change the symbol link in `Sources/AgentViewKit/Thread/SessionTranscriptEnvironment.swift:8`.
- [x] In `Sources/AgentViewKit/Status/SessionStreamBanner.swift`, remove the `workingDirectory:` input. The Reload button makes the `ResumeSessionRequest` from `session.cwd` and `session.additionalDirectories`. When the list is empty, the request has no `additionalDirectories`. The Reload button shows when the host gives the connection model and `canResumeSessions` is true.
- [x] In `Sources/AgentViewKit/Sessions/SessionListView.swift`, `resume(_:)` sends `info.cwd` and the full `info.additionalDirectories` of the `SessionInfo` value in `ConnectionModel.sessions`. Update the doc comment at line 26.
- [x] Remove `workingDirectory:` from the callers in `Tests/` and `Examples/`. Add `init(session:connection:workingDirectory:actions:)` to `Tests/PackageStructureTests/RemovedVocabularyTests.swift`.

Size: 4 source files: `AgentThreadView.swift`, `SessionStreamBanner.swift`, `SessionListView.swift`, `SessionTranscriptEnvironment.swift`.

## Acceptance Criteria
- [x] No kit view takes the working directory or the additional directories of a session from the host.
- [x] The `session/resume` frame of the Reload button has `cwd == session.cwd` and `additionalDirectories == session.additionalDirectories`.
- [x] The `session/resume` frame of the session picker has the `cwd` and the full `additionalDirectories` of the `SessionInfo` row.
- [x] No file in `Sources/`, `Tests/`, `Examples/` or `README.md` uses `workingDirectory:` on `AgentThreadView` or `SessionStreamBanner`.

## Tests
- [x] `Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift`: open the scripted session with two additional directories. Press Reload. Check that the `session/resume` frame has `params.cwd` and `params.additionalDirectories` with the two paths. Remove `workingDirectory:` at line 91.
- [x] `Tests/AgentViewKitTests/Sessions/SessionPickerConnectionModelHostedTests.swift`: a `session/list` answer gives a row with `additionalDirectories`. A press on the row sends `session/resume` with the `cwd` and the full list of that row.
- [x] `Tests/PackageStructureTests/RemovedVocabularyTests.swift` fails before the removal and passes after it.
- [x] Command: `swift test --filter "SessionStateBannersHostedTests|SessionPickerConnectionModelHostedTests|RemovedVocabularyTests"`. Then `swift test` and `Scripts/check-readme.sh` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.