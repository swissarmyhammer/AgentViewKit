---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4q98djtjp63ka95avdajs8y
  text: |-
    Research and decisions. The file:line references on the card are correct: PermissionView Send and switch to auto, ElicitationFooter Cancel/Decline/Submit, URL consent Cancel/Decline/Open in Browser/Retry.

    Each button now uses `Button(_:systemImage:...)`. No new SharedSymbol constant was necessary. Each button has the same meaning as an existing concept, so the button uses that concept:
    - Permission comment Send: `send` (the comment goes out as the next prompt).
    - Allow and Switch to Auto Mode: `switchMode` (the button changes the session mode).
    - Elicitation Submit: `accept`. Decline: `reject`. Cancel: `dismiss` (closes with no answer).
    - URL consent Open in Browser: `open` (opens in an other app). Retry: `reload`. Decline and Cancel: the same symbols as the form.

    The view symbols are internal statics: `PermissionView.commentSubmitSymbol`, `PermissionView.switchToAutoSymbol`, `ElicitationView.submitSymbol/declineSymbol/cancelSymbol`, `ElicitationURLConsentView.openSymbol/retrySymbol/declineSymbol/cancelSymbol`. The SharedSymbol doc comments of send, dismiss, open, reload, accept, reject and switchMode now name the new uses.

    SymbolConceptTests: new concepts `send`, `dismiss`, `open`; new use lists `elicitationFormButtonUses`, `urlConsentButtonUses`, `requestButtonUses` (in `allUses`); two new distinct-symbol tests. Hosted tests: a new shared helper `HostedViewHarness.expectButton(identifier:label:)` in `Tests/AgentViewKitTests/Helpers/HarnessButtons.swift` checks the button role and the label. The Retry button keeps its accessibility label "Open The agent in the browser again".

    RED: the SymbolConceptTests build failed on the missing symbol members. GREEN: 15 filtered tests passed.
  timestamp: 2026-10-12T05:27:07.610219+00:00
- actor: claude-code
  id: 01m4q98j649n6d38ywdean5v4x
  text: |-
    ### implement — changed
    - evidence: `swift test` — 1160 tests in 128 suites passed (2 known issues, from the existing withKnownIssue self-tests of ThemeHeightExpectations and HostedLayoutExpectations), plus 118 tests in 15 suites and 1 test in 1 suite passed. Load average before 17.57 19.24 20.39, after 19.84 19.31 20.17. The only build warning is the existing SwiftPM "missing creator for mutated node" on the mlx-swift_Cmlx bundle. No UI tests run.
    - files: Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift, Sources/AgentViewKit/Elicitation/ElicitationView.swift, Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift, Sources/AgentViewKit/Items/SharedSymbol.swift, Tests/AgentViewKitTests/Items/SymbolConceptTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift, Tests/AgentViewKitTests/Elicitation/ElicitationViewHostedTests.swift, Tests/AgentViewKitTests/Elicitation/ElicitationURLConsentViewHostedTests.swift, Tests/AgentViewKitTests/Helpers/HarnessButtons.swift (new)
    - next: /review. The task stays in doing. No commit.
  timestamp: 2026-10-12T05:27:12.324904+00:00
position_column: doing
position_ordinal: '80'
title: 'SF Symbols: add icons to the text-only buttons of the permission comment row and the elicitation cards'
---
## What
Card ^02jyret added icons to the text-only action buttons that the audit named. Some text-only buttons are not on that card. Use `Label(_:systemImage:)` and read each symbol from `SharedSymbol`. Paths are below `Sources/AgentViewKit/`.

## Work
- [x] `HumanInTheLoop/PermissionView.swift`: the "Send" button of the comment row (`SharedSymbol.send` can apply) and the "Allow and Switch to Auto Mode" button.
- [x] `Elicitation/ElicitationView.swift`: the "Cancel", "Decline" and "Submit" buttons.
- [x] `Elicitation/ElicitationURLConsentView.swift`: the "Cancel", "Decline", "Open in Browser" and "Retry" buttons.
- [x] Add each new concept to `SharedSymbol`. Two concepts must not share a symbol. Add the uses to `SymbolConceptTests`.
- [x] Hosted tests that find each button and its label.