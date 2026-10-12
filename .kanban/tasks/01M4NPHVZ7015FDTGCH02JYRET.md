---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4pp1mc3ex1y2c5peymf89v9
  text: |-
    Research (2026-10-11). The code moved. The current places are:
    - PermissionView.swift: optionButton (Button(option.name)), terminalLink (Button("Show Terminal"/"Hide Terminal")).
    - DiffView.swift: hunkRow, Accept and Reject buttons.
    - StatusBar.swift: body, Button(action.title). The two actions are "Reload" (SessionStreamBanner.makeReloadAction) and "Show Error" (StateBanner). There is no "Retry" banner action now.
    - SessionListView.swift: list, Button("Load More").
    - OutputChrome.swift: OutputCapRow, "Show all N lines".
    - AgentAuthView.swift: actionButton shows Text(title) for Sign In, Run, Reconnect and Sign Out.
    - SuggestionsView.swift: Button(suggestion).
    The accessibility tree of the harness does not show the icon of a Label in a Button. Thus the hosted tests check that each button keeps its text label, and SymbolConceptTests checks the symbol of each button through a static symbol of the view.
    Other buttons with text only that the card does not name: PermissionView "Send" and "Allow and Switch to Auto Mode", ElicitationView "Cancel"/"Decline"/"Submit", ElicitationURLConsentView "Cancel"/"Decline"/"Open in Browser"/"Retry". I will record them on a new task.
  timestamp: 2026-10-11T23:51:22.243624+00:00
- actor: claude-code
  id: 01m4ppgk8xa9czdcf0zmb96kmg
  text: |-
    Implementation landed.
    - New `SharedSymbol` concepts: `accept` (checkmark), `acceptAlways` (checkmark.seal), `reject` (xmark.circle), `rejectAlways` (xmark.seal), `details` (text.magnifyingglass), `loadMore` (arrow.down.to.line), `showAll` (rectangle.expand.vertical), `signOut` (rectangle.portrait.and.arrow.right), `suggestion` (sparkles). Existing concepts that the new buttons reuse: `terminal` (Show Terminal, Run), `reload` (banner Reload, Reconnect), `signIn` (Sign In), `unknown` (a permission option kind that the kit does not know).
    - `PermissionView.optionSymbol(for:)` gives the symbol of each `PermissionOptionKind`. Each view has a static symbol for its button, and `SymbolConceptTests.permissionOptionUses()` and `actionButtonUses()` read them.
    - `StatusBar.Action` has a new `systemImage` field. `StateBanner` (Show Error) and `SessionStreamBanner` (Reload) give it.
    - `AgentAuthView.actionButton` shows `Label(title, systemImage:)`. The other buttons use `Button(_:systemImage:action:)`, which makes the same `Label`. The accessibility label of each button stays its text.
    - The harness does not show the icon of a Label in a Button, so the hosted tests check the role and the text label of each button, and SymbolConceptTests checks each symbol.
    - Text-only buttons that this card does not name are on new task "SF Symbols: add icons to the text-only buttons of the permission comment row and the elicitation cards".
  timestamp: 2026-10-11T23:59:32.637894+00:00
- actor: claude-code
  id: 01m4ppgr872vqgrekbvzca5f6z
  text: |-
    ### implement — changed
    - evidence: 17 files. Sources: Items/SharedSymbol.swift, HumanInTheLoop/PermissionView.swift, Diff/DiffView.swift, Status/StatusBar.swift, Status/StateBanner.swift, Status/SessionStreamBanner.swift, Sessions/SessionListView.swift, Content/OutputChrome.swift, Connections/AgentAuthView.swift, Input/SuggestionsView.swift. Tests: Items/SymbolConceptTests.swift, HumanInTheLoop/PermissionViewHostedTests.swift, Diff/DiffViewHostedTests.swift, Status/SessionStateBannersHostedTests.swift, Sessions/SessionPickerConnectionModelHostedTests.swift, Connections/AgentAuthViewHostedTests.swift. RED: SymbolConceptTests did not compile (missing symbol members). Full `swift test`: 1102 tests in 120 suites passed, 1 known issue (the deliberate HostedLayoutExpectationsTests case), no compiler warning from the changed files. Load average 76.69 at start, 72.15 at end.
    - next: review
  timestamp: 2026-10-11T23:59:37.735700+00:00
- actor: claude-code
  id: 01m4ppgw3nhpbn5dxyvs4qs4z5
  text: 'Correction to the step record: the change has 16 code files (10 source files and 6 test files), not 17. The file list in the record is correct.'
  timestamp: 2026-10-11T23:59:41.685946+00:00
depends_on:
- 01M4NPHNFGP5JDZS02XHHE6BE3
position_column: doing
position_ordinal: '80'
title: 'SF Symbols: add icons to the text-only action buttons'
---
## What
An audit on 2026-10-11 found action buttons with text only. Use `Label(_:systemImage:)` with the symbol table of the kit. Paths are below `Sources/AgentViewKit/`.

## Work
- [x] Permission options: an icon from `option.kind` (for example a checkmark for allow, an xmark for reject) (`HumanInTheLoop/PermissionView.swift:301`). Also "Show Terminal" (`:236`).
- [x] Diff hunk Accept and Reject (`Diff/DiffView.swift:345`, `:352`).
- [x] Banner actions such as Retry and Reconnect (`Status/StatusBar.swift:51`).
- [x] "Load More" (`Sessions/SessionListView.swift:202`), "Show all" (`Content/OutputChrome.swift:27`), the sign-in method buttons (`Connections/AgentAuthView.swift`), and the suggestion chips (`Input/SuggestionsView.swift:46`) where an icon helps.
- [x] Hosted tests that find each button and its label.