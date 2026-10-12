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
- actor: claude-code
  id: 01m4pq0t5qawcxkbmprb265gt3
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (commit 531dbb1); 1 finding (1 confirmed, 1 refuted) — Tests/AgentViewKitTests/Items/SymbolConceptTests.swift:263 `reuse/reuse`
    - next: implement the open item in the "Review Findings (2026-10-11 19:04)" section, then review again. The task stays in review.
  timestamp: 2026-10-12T00:08:23.991508+00:00
- actor: claude-code
  id: 01m4pq140tvxfr8xd3ptn30ghb
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — icons on the text-only action buttons; new SharedSymbol concepts; 16 files
    - test: green — swift test, 1102 tests passed, 1 expected known issue, load average 61 to 88
    - commit: 531dbb1
    - review: findings — Tests/AgentViewKitTests/Items/SymbolConceptTests.swift:263
  timestamp: 2026-10-12T00:08:34.074592+00:00
- actor: claude-code
  id: 01m4pqayganea6p39zy2dqc84d
  text: |-
    Fix for the reuse finding in SymbolConceptTests.swift:
    - New private static helper `expectDistinctNames(_:sourceLocation:)`. It does the Set count check and the failure text. It sends the source location of the caller to `#expect`, as `KitInitializeRequestTests.expectOnlyKitCapabilities` does. The three tests `eachPlanPriorityShowsADifferentSymbol`, `eachPermissionOptionKindShowsADifferentSymbol` and `eachMCPServerStatusShowsADifferentSymbol` call it. The constructors `priorityUses`, `permissionOptionUses` and `connectionChipUses` did not change.
    - The rest of the file had a second repeated body: `eachConceptShowsOneSymbol` and `twoConceptsDoNotShareASymbol` both grouped the uses with `Dictionary(grouping:)` and kept the groups with more than one distinct value. New private static helper `mixedGroups(of:by:value:)` does this, and the two tests call it.
    - The rules file from `dump validators` was 754000 characters. It was too large to read whole in one call.
  timestamp: 2026-10-12T00:13:56.106922+00:00
- actor: claude-code
  id: 01m4pqb0pc0bsgwhm1eyr4akfr
  text: |-
    ### implement — changed
    - evidence: 1 file — Tests/AgentViewKitTests/Items/SymbolConceptTests.swift. Full `swift test`: 1102 tests in 120 suites passed, 1 known issue (the deliberate HostedLayoutExpectationsTests case), exit 0. The only build warning is the mlx-swift_Cmlx bundle "missing creator" warning of the build system, not from this change. Load average 60.97 at start, 69.45 at end. Review finding checked.
    - next: review
  timestamp: 2026-10-12T00:13:58.348638+00:00
- actor: claude-code
  id: 01m4pqv70rhfwtjbq4zn3pkskh
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (eb4b43a); 1 finding, 1 confirmed, 0 refuted — Tests/AgentViewKitTests/Items/SymbolConceptTests.swift:243
    - next: move expectDistinctNames to a shared test helper. Make SymbolConceptTests and ToolKindSymbolTests call it. Then review again.
  timestamp: 2026-10-12T00:22:49.112359+00:00
- actor: claude-code
  id: 01m4pqvk8n4ma5vqx2ay7w8p02
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — expectDistinctNames and mixedGroups helpers in SymbolConceptTests; finding checked
    - test: green — swift test, 1102 tests passed, 1 expected known issue, load average 43 to 70
    - commit: eb4b43a
    - review: findings — Tests/AgentViewKitTests/Items/SymbolConceptTests.swift:243
  timestamp: 2026-10-12T00:23:01.653304+00:00
- actor: claude-code
  id: 01m4pr87rb5rrncyw2rfakvm68
  text: |-
    Fix for the reuse finding at SymbolConceptTests.swift:243:
    - New shared test helper `NameChecks.expectDistinctNames(_ names: [String], sourceLocation:)` in `Tests/AgentViewKitTests/Helpers/NameChecks.swift`. It is not private. It does the Set count check, puts the names in the failure text, and sends the source location of the caller to `#expect`.
    - The private `expectDistinctNames` of SymbolConceptTests is removed. Its three tests call `NameChecks.expectDistinctNames(Self.<uses>().map(\.name))`.
    - ToolKindSymbolTests: `eachKindMapsToADistinctSymbol` calls the helper. The same file had the same check two more times in `eachStatusMapsToADistinctSymbolAndLabel` (names and labels). Both call the helper now.
    - The helper takes `[String]`, not `[Use]`, because `Use` belongs to SymbolConceptTests only.
    - Seven other test files write the same check by hand. They are on the new task ^1pv3jzy.
    - The full `swift test` had one failure that this change does not touch: `ToolCallEntryViewHostedTests.theBodyShowsTheRawInputTheTextPartAndTheRawOutputOfTheEntry` (ToolCallEntryViewHostedTests.swift:258, `showsText(partText)`). The test waits for the output text only and then checks the text part. This is the known race on task ^y7kyt4j. I did not run the suite again, and I did not raise a wait limit.
  timestamp: 2026-10-12T00:29:55.851786+00:00
- actor: claude-code
  id: 01m4pr8az72n7pfamnyxcfxx88
  text: |-
    ### implement — changed
    - evidence: 3 files — Tests/AgentViewKitTests/Helpers/NameChecks.swift (new), Tests/AgentViewKitTests/Items/SymbolConceptTests.swift, Tests/AgentViewKitTests/Items/ToolKindSymbolTests.swift. Full `swift test`: 1102 tests in 120 suites, 2 issues: 1 known issue (the deliberate HostedLayoutExpectationsTests case) and 1 failure in ToolCallEntryViewHostedTests.theBodyShowsTheRawInputTheTextPartAndTheRawOutputOfTheEntry (the known race of ^y7kyt4j, not in this change). Exit 1. SymbolConceptTests and ToolKindSymbolTests passed. The only build warning is the mlx-swift_Cmlx bundle "missing creator" warning of the build system. Load average 46.66 at start, 53.94 at end. Review finding checked. Follow-up task ^1pv3jzy.
    - next: test, then review
  timestamp: 2026-10-12T00:29:59.143241+00:00
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

## Review Findings (2026-10-11 19:04)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 16 file(s) reviewed, 6 not reviewed.

> 6 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 6 file(s)

- [x] `Tests/AgentViewKitTests/Items/SymbolConceptTests.swift:263` `reuse/reuse` — The new test eachPermissionOptionKindShowsADifferentSymbol repeats the body of two existing tests. It maps a list of Use values to names, then checks that Set(names).count == names.count. The change adds a third copy of this check instead of extending the existing pattern into one shared helper, so the same logic now exists in three places and must be fixed in three places. Add one private static helper, for example `static func assertDistinctNames(_ uses: [Use])`, that performs the Set count check and the failure message. Have all three tests call it with their own uses list, such as `assertDistinctNames(Self.permissionOptionUses())`. Keep the per-case constructors (permissionOptionUses, priorityUses, connectionChipUses) where they are.

## Review Findings (2026-10-11 19:19)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 1 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Tests/AgentViewKitTests/Items/SymbolConceptTests.swift:243` `reuse/reuse` — The new helper expectDistinctNames rewrites a distinct-name check that already exists in another test file. ToolKindSymbolTests.eachKindMapsToADistinctSymbol runs the same set-count comparison on its own names. The helper is private to SymbolConceptTests, so the duplicate stays in place and the two copies can drift apart. Move expectDistinctNames to a shared test helper, for example a non-private static function in a common test support file. Then have SymbolConceptTests and ToolKindSymbolTests both call it. If the other test files are out of scope for this change, record the shared helper as a follow-up task.
