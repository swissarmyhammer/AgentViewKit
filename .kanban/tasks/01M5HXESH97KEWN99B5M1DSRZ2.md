---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5jhm1q88jxr1dnk0qzaad6z
  text: |-
    Research:
    - StatusBar and AgentLoginPrompt are internal views, so PreviewCoverageTests (public views only) does not check them. ^wx7a4db adds the file-level check later.
    - Preview pattern: named `#Preview("...")` at the end of the file, data from PreviewFixtures and the FoundationModelsACPClient preview factories (`SessionModel.preview`, `ConnectionModel.preview(authState:initializeResponse:openSessions:)`). Multi-state previews use a VStack + ForEach (ConnectionStatusChip, ActivityIndicator).
    - "Each status" of StatusBar: the messages of StateBanner.message(for:) cover the three looks (failure symbol in the error color, ongoing symbol with the live effect, plain secondary symbol).
    - AgentAuthView shows a Run button for a terminal method only with a `terminalAuthRunner` in the environment; no preview runner exists in the kit (FakeTerminalAuthRunner is in AgentViewKitTestSupport), so a preview runner that starts no process goes in PreviewFixtures.
    - AgentThreadView shows AgentLoginPrompt in its bottom bar when given a connection whose authState asks for sign-in; a long transcript makes the list scroll under the bar.
    - PreviewFixturesTests holds the tests of the fixture values.
  timestamp: 2026-10-22T19:32:46.952847+00:00
- actor: claude-code
  id: 01m5jja5hf9655t9drtf60w5zh
  text: |-
    Implementation notes:
    - First attempt put `.requestActionPlace(.barWithoutGlass)` on two StatusBar previews. GlassPlacementTests.eachViewInABarWithNoGlassDeclaresThePlaceOfABarWithNoGlassOneTime failed: only StateBanner and AgentLoginPrompt may declare that place, one time each. The StatusBar button (`.secondary`) has the `.glass` style in `.content` and in `.barWithoutGlass` (RequestDeckPlace.style(of:)), so the previews now declare no place.
    - The window monitor script `run-watched.sh` named on earlier cards is not on disk in this checkout; the full suite ran with plain `swift test`.
    - The PreviewFixtures stub runner needs `nonisolated` (default MainActor isolation of the target): `nonisolated static let successfulExitStatus`, `nonisolated struct TerminalAuthRunnerStub`.

    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKit/Status/StatusBar.swift (previews "Each agent state", "Long status text", "Bar with its buttons"), Sources/AgentViewKit/Connections/AgentLoginPrompt.swift (previews "Sign-in with an agent method", "Sign-in with a terminal method", "Sign-in with a long agent name", "Sign-in in the bottom bar of a thread over scrolled content"), Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift (agentStates, statusMessages, failedTurnStatusMessage, longStatusMessage, narrowWidth, statusAction(isEnabled:), agentName, longAgentName, agentVersion, agentAuthMethod, terminalAuthMethod, longNameAuthMethod, authConnection(methods:agentName:openSessions:), successfulExitStatus, TerminalAuthRunnerStub, terminalAuthRunner, scrolledTurnCount, scrolledSession), Tests/AgentViewKitTests/Infrastructure/PreviewFixturesTests.swift (10 new tests, RED then GREEN). `swift test`: exit 0; 1607 tests in 201 suites passed (3 known issues from before), 219 PackageStructureTests in 29 suites passed; only build warning is the known SwiftPM mlx-swift_Cmlx bundle line. No new public API.
    - next: /review
  timestamp: 2026-10-22T19:44:51.759558+00:00
- actor: claude-code
  id: 01m5jjh6zy184jtyqhva8m3tbq
  text: |-
    ### test — green
    - evidence: `swift test` — 1607 tests in 201 suites passed, 0 failed, 0 skipped; 3 known issues are pre-existing intentional withKnownIssue harness-failure tests (SnapshotStoreTests, HostedLayoutExpectationsTests, ThemeHeightExpectationsTests). `swift build --target AgentViewKit -c debug` (touched StatusBar, AgentLoginPrompt, PreviewFixtures) — Build complete, no project warnings; only the known mlx-swift "missing creator" notice.
    - next: review
  timestamp: 2026-10-22T19:48:42.622799+00:00
position_column: doing
position_ordinal: '8380'
title: 'AVK-14a Add #Preview blocks for StatusBar and AgentLoginPrompt'
---
## Goal

The user examines the look of each component in the Xcode canvas. These views have no `#Preview`:

- `Sources/AgentViewKit/Status/StatusBar.swift` — `StatusBar`
- `Sources/AgentViewKit/Connections/AgentLoginPrompt.swift` — `AgentLoginPrompt`

## Change

Add `#Preview` blocks in the same file as each view. Use the shared data in `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift`. Add to it if a value is missing. Give each preview a name that tells its state.

Show the states that are hard to get right:

- [x] `StatusBar`: each status, a long status text, and the bar with its buttons.
- [x] `AgentLoginPrompt`: each sign-in method, a long agent name, and the card in the bottom bar of `AgentThreadView` over scrolled content (the glass buttons of ^26aevxf).

## Rules

- No new public API. No backward compatibility code (ARCHITECTURE.md).
- A preview uses no network, no real agent and no file outside a temporary directory.
- The package builds with 0 warnings. The full suite passes with the window monitor. #avk-14