---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4tmwrs9zktxsxdp0mvtf6mg
  text: |-
    Research and work log.

    - `swift package update` moved FoundationModelsACPClient 3c3adb9 -> f47ca38 and FoundationModelsACP 5f94484 -> 7570149 (kanban record only). EditorKit and FoundationModelsACPAgent were already at origin/main. `Package.resolved` is git-ignored, so the pin change is not in the diff.
    - The only compile error was the HostApp snippet. README.md and `Examples/ReadmeSnippets/Snippets/HostApp.swift` now use `connection.openSessions.first`. plan.md (the open set) now says that `openSessions` is an ordered list of Identifiable `SessionModel`. comparison.md only names `openSessions` and needs no change.
    - The kit has no own copy of the client preview factories (no `PreviewClock`, `PreviewSessionRequestSender` or `SessionModel.preview` copy). `ScriptedSession` makes real models over a scripted agent, so it stays.
    - The first full `swift test` failed `ResolvedPinsTests.theGeneratedDemoProjectPinsTheRootACPRevisions`, because the generated demo project still held the old pins. `ruby Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb` copied the new root pins, and then the test passed. The demo project is git-ignored.
    - Gallery: the new hosted test `theSessionListOfTheGalleryShowsARowOfARecordedSession` (in the `.serialized` suite `RecordedSessionsAgentTests`, with `.hostedSerially`) passes at once: a row shows after 0.9 seconds. The test uses the XDG stage root of `DemoAgent.makeInProcess(recordedSessions:)` and makes no content assertion.
    - CI result bundle of run 38391106969: the "App UI hierarchy" of the failed Gallery test holds the application and the menu bar only. No window. The screenshot attachments are empty ("Finished test run with pending attachment").
    - What did not work: a local launch of the demo app with `--in-memory-agent --tab gallery` to count its windows. `CGWindowListCopyWindowInfo` showed no window for the ACP launch either, and osascript has no assistive access. So the local probe gives no result. Each probe app process was stopped.
    - The SwiftPM build prints `warning: missing creator for mutated node: ('.../mlx-swift_Cmlx.bundle/Contents/MacOS')` on each build. It also shows on the build before this change. It comes from the mlx-swift dependency of FoundationModelsACPAgent, not from this package.
  timestamp: 2026-10-13T12:48:12.073282+00:00
- actor: claude-code
  id: 01m4tmwwc2c1a489r42kr1b32y
  text: |-
    ### implement — stuck
    - evidence: 4 files — README.md, Examples/ReadmeSnippets/Snippets/HostApp.swift, plan.md, Tests/AgentViewKitTests/ACP/RecordedSessionsAgentTests.swift. `swift test`: 1153 tests in 129 suites passed (2 known issues), plus 123 tests in 16 suites passed. `Scripts/check-readme.sh`: passed. Demo build (`xcodebuild -scheme AgentViewKitDemo build`): BUILD SUCCEEDED. Open item: the in-process Gallery list test passes with client f47ca38, so it does not show the CI failure. The CI UI hierarchy shows that the app had no window, not an empty list.
    - next: a person decides how to find why the demo app has no window in the Gallery launch on the CI runner (a UI test run is necessary), or closes the Gallery item. The task stays in doing.
  timestamp: 2026-10-13T12:48:15.746397+00:00
- actor: claude-code
  id: 01m4v13va59re8x9k2a0f1591y
  text: |-
    ### CI green: run 38424460243 (commit 9a9a362)
    - The README gate passes with the ordered `openSessions` list of the client.
    - The Gallery item: the cause was the crash of ^any712s (nested inspectors), not the client. The Gallery UI test passes on CI.
    - next: /review.
  timestamp: 2026-10-13T16:21:46.949379+00:00
position_column: doing
position_ordinal: '8180'
title: Follow the new FoundationModelsACPClient openSessions list, and find why the Gallery lists no recorded session on CI
---
## What
CI run 38391106969 (commit 8c5aef9) resolved FoundationModelsACPClient main at f47ca38. Local pin is 3c3adb9. The new client has `8cc5afe feat(model)!: make openSessions an ordered list of Identifiable SessionModel`, `9dd9881` (list elements Identifiable) and `6f2feba` (public preview factories).

Two failures:
1. README gate and Build & test: `Examples/ReadmeSnippets/Snippets/HostApp.swift:21:48: error: value of type '[SessionModel]' has no member 'values'`. The README has the same snippet (README.md line 217).
2. Examples: `GalleryTabEndToEndTests.swift:54: XCTAssertTrue failed - The Gallery lists no recorded session.` The 4 ACP tab tests passed, and no "Failed to activate" occurred.

## Work
- [x] Update the local pin: `swift package update FoundationModelsACPClient` (and the other in-family packages to origin/main). Build the kit, the demo and the README snippets.
- [x] Fix every use of the old `openSessions` dictionary in the kit, DemoSupport, the README and the snippets. Use the new preview factories where the kit has its own copies, if the kit has them.
- [ ] Find why the Gallery lists no recorded session with the new client. First write an in-process test (a package test, not a UI test) that fails the same way: for example, resume or list the recorded sessions through `DemoAgent.makeInProcess(recordedSessions:)` and the ConnectionModel the Gallery uses, and expect at least one listed session. Then fix the cause.
- [x] Run the full `swift test`, the README gate script, and build the demo. Do not run UI tests on this machine.

## Blocker
The in-process test does not fail. `RecordedSessionsAgentTests.theSessionListOfTheGalleryShowsARowOfARecordedSession` mounts the kit `SessionListView` over the connection of `DemoAgent.makeInProcess(recordedSessions:)`, with the working directory of the agent, as the Gallery sidebar does. With client f47ca38 it shows a row after 0.9 seconds. `theAgentListsTheRecordedSessions` also passes. Thus the list path of the kit and of the new client works.

The CI result bundle of run 38391106969 shows a different cause. The "App UI hierarchy" attachment of the failed Gallery test has the application and its menu bar only. The app had no window, so no list and no start text could show. The failure label also could not show, so the assertion "The start of the Gallery failed" passed with no meaning. This is not a list problem and it is not in the new client.

The Gallery test never passed on CI before this run: run 38248679318 failed on the Gallery start (fixed by ^pndr0c1), and older runs failed before the Gallery test ran.

A person must decide the next step: find why the app has no window in the Gallery launch on the CI runner (a UI test run is necessary, and UI tests do not run on this machine), or close this item.
