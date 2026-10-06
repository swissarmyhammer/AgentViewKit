---
assignees:
- claude-code
depends_on:
- 01M443RA2PMKC5MXXBNH1116AB
position_column: todo
position_ordinal: b780
title: Resume and reload from SessionModel.cwd and additionalDirectories
---
## Start condition
Do not start this task before the kit pins a FoundationModelsACPClient commit that has the client task 65k5p79. Before that commit, `SessionModel` has no `cwd` and no `additionalDirectories: [AbsolutePath]`, and `ConnectionModel` has no `canUseAdditionalDirectories` flag.

## What
Rule: the agent streams to FoundationModelsACPClient over ACP. The client keeps an observable state. The kit views bind directly to that state and keep no state or logic of their own.

ACP v2 tells that a resume must send the same `cwd` and the full `additionalDirectories` of the session. Task ^dpg4t4z added the input `workingDirectory:` to `AgentThreadView.init(session:connection:workingDirectory:actions:)`, because the session model did not hold the working directory. The host gives a copy of a model value, and the Reload button sends no `additionalDirectories`. The session picker sends `info.cwd` and no `additionalDirectories`.

Subtasks:
- [ ] Bump the FoundationModelsACPClient pin to a commit that has 65k5p79.
- [ ] In `Sources/AgentViewKit/Thread/AgentThreadView.swift`, remove the `workingDirectory:` input, the `workingDirectory` property and their doc comments. The initializer becomes `init(session:connection:actions:)`. Change the symbol link in `Sources/AgentViewKit/Thread/SessionTranscriptEnvironment.swift:8`.
- [ ] In `Sources/AgentViewKit/Status/SessionStreamBanner.swift`, remove the `workingDirectory:` input. The Reload button makes the `ResumeSessionRequest` from `session.cwd` and `session.additionalDirectories`. When the list is empty, the request has no `additionalDirectories`. The Reload button shows when the host gives the connection model and `canResumeSessions` is true.
- [ ] In `Sources/AgentViewKit/Sessions/SessionListView.swift`, `resume(_:)` sends `info.cwd` and the full `info.additionalDirectories` of the `SessionInfo` value in `ConnectionModel.sessions`. Update the doc comment at line 26.
- [ ] Remove `workingDirectory:` from the callers in `Tests/` and `Examples/`. Add `init(session:connection:workingDirectory:actions:)` to `Tests/PackageStructureTests/RemovedVocabularyTests.swift`.

Size: 4 source files: `AgentThreadView.swift`, `SessionStreamBanner.swift`, `SessionListView.swift`, `SessionTranscriptEnvironment.swift`.

## Acceptance Criteria
- [ ] No kit view takes the working directory or the additional directories of a session from the host.
- [ ] The `session/resume` frame of the Reload button has `cwd == session.cwd` and `additionalDirectories == session.additionalDirectories`.
- [ ] The `session/resume` frame of the session picker has the `cwd` and the full `additionalDirectories` of the `SessionInfo` row.
- [ ] No file in `Sources/`, `Tests/`, `Examples/` or `README.md` uses `workingDirectory:` on `AgentThreadView` or `SessionStreamBanner`.

## Tests
- [ ] `Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift`: open the scripted session with two additional directories. Press Reload. Check that the `session/resume` frame has `params.cwd` and `params.additionalDirectories` with the two paths. Remove `workingDirectory:` at line 91.
- [ ] `Tests/AgentViewKitTests/Sessions/SessionPickerConnectionModelHostedTests.swift`: a `session/list` answer gives a row with `additionalDirectories`. A press on the row sends `session/resume` with the `cwd` and the full list of that row.
- [ ] `Tests/PackageStructureTests/RemovedVocabularyTests.swift` fails before the removal and passes after it.
- [ ] Command: `swift test --filter "SessionStateBannersHostedTests|SessionPickerConnectionModelHostedTests|RemovedVocabularyTests"`. Then `swift test` and `Scripts/check-readme.sh` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #blocked-upstream