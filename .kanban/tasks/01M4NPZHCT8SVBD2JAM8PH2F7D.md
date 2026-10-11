---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4nvdtpz2qph53dqrwx8h9bc
  text: |-
    Research (implement step):
    - Symbol data on this machine (macOS 27, CoreGlyphs.bundle): name_aliases.strings has 1101 old names (old name -> current name). symbol_restrictions.strings has the restricted names. Both are binary property lists. PropertyListSerialization reads them.
    - Each new name exists in name_availability.plist and has no restriction: apple.terminal 2023, arrow.trianglehead.2.clockwise.rotate.90 2024, clock.arrow.trianglehead.counterclockwise.rotate.90 2024, document 2024, document.on.clipboard 2024, document.on.document 2024, inset.filled.circle 2024, microphone 2024, microphone.slash 2024, richtext.page 2024, text.document 2024, person.badge.shield.checkmark 2022, key 2020. All are older than macOS 27.
    - Two locations in the card are not symbol names. Do not change them: `Terminal/TerminalView.swift` `identifier = "terminal"` is the accessibility identifier of the view. `Thread/TranscriptEntryKind.swift` `case .terminal: "terminal"` is `kindName`, which the minimap uses for tick identifiers and as the accessibility label. The other 5 "terminal" uses are symbols.
    - The alias list has short words such as "a", "abc", "number", "note", "terminal". Thus the test cannot scan all string literals. It reads only the literals in a symbol context: after a `systemName:`, `systemImage:`, `systemSymbolName:` or `symbolName:` label, and in the body of a declaration whose name has "symbol" (for example `enum ToolKindSymbol`, `static let commandSymbol`) or is `systemImage`.
    - CI runs on the self-hosted macOS 27 runner, so the test reads the system files at test time. A missing file fails the test.
    - No test pins an old name. The existing-symbol checks in ToolKindSymbolTests use NSImage(systemSymbolName:), which also accepts old names.
  timestamp: 2026-10-11T16:06:10.399897+00:00
- actor: claude-code
  id: 01m4nvy0ync2fcfge6mbvj106h
  text: |-
    Implementation landed.
    - New test files in Tests/PackageStructureTests: SymbolNameTests.swift (11 tests), SymbolNameScanner.swift (the symbol-context scan and a small literal and comment lexer), SystemSymbolData.swift (reads name_aliases.strings and symbol_restrictions.strings with PropertyListSerialization). SourceLineScanner.swift: the relative path code moved into `relativePath(of:to:)`, so that both scanners use it.
    - RED: noSymbolNameIsAnOldName found exactly 17 uses (the card list less the two non-symbol "terminal" literals). noSymbolNameIsRestricted found AgentAuthView `person.badge.key`. No false finding.
    - GREEN: 13 source files changed. Passkey symbol is now `person.badge.shield.checkmark`.
    - The search of the whole repository again found no old symbol name outside the test fixtures of SymbolNameTests. The remaining "terminal" literals are ACP wire values, the TerminalView accessibility identifier and TranscriptEntryKind.kindName.
    - The `.switchMode` / max-turn-requests banner symbol collision stays open for the concept card. No test fails on it.
    - Full `swift test`: 1 + 100 + 1046 tests pass, 0 failures. One known issue is the existing `withKnownIssue` in HostedLayoutExpectationsTests. The only warning is the known SwiftPM line "missing creator for mutated node" for the mlx-swift_Cmlx bundle in .build; it is not from the code. Load average before the run 27.59 34.31 39.12, after 23.16 31.20 37.03. No UI tests were run.
  timestamp: 2026-10-11T16:15:01.077644+00:00
- actor: claude-code
  id: 01m4nvy442dxzn0zjqbr59pc7r
  text: |-
    ### implement — changed
    - evidence: 17 files — Tests/PackageStructureTests/{SymbolNameTests,SymbolNameScanner,SystemSymbolData,SourceLineScanner}.swift; Sources/AgentViewKit/{Activity/ActivityTimeline,Attachments/ArtifactView,Code/CodeBlockView,Connections/AgentAuthView,Content/CommandOutputView,Elicitation/ElicitationFieldViews,HumanInTheLoop/PermissionView,Input/SpeechInputButton,Items/MessageActions,Items/ToolCallView,Items/ToolKindSymbol,Status/SessionStreamBanner,Terminal/TerminalView}.swift. swift test: 1147 tests pass (1 + 100 + 1046), 0 failures, 1 existing known issue. Load average 27.59 before, 23.16 after.
    - next: /review
  timestamp: 2026-10-11T16:15:04.322690+00:00
- actor: claude-code
  id: 01m4nwdcy1vmzg9z23f921teb1
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (fb26a6d). 7 findings (7 confirmed, 1 refuted). Content/CommandOutputView.swift:207, HumanInTheLoop/PermissionView.swift:75, Items/ToolCallView.swift:495, Items/ToolKindSymbol.swift:20, Terminal/TerminalView.swift:201, Tests/PackageStructureTests/SymbolNameScanner.swift:377, :381.
    - next: Do the 7 items in the "Review Findings (2026-10-11 11:19)" section. The task stays in review.
  timestamp: 2026-10-11T16:23:24.865975+00:00
- actor: claude-code
  id: 01m4nwdy06yqvnjypxwcceqx0g
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 11 old names replaced in 13 source files, person.badge.key replaced, SymbolNameTests added
    - test: green — swift test, 1147 tests passed, 1 expected known issue, load average 17 to 23
    - commit: fb26a6d
    - review: findings — Sources/AgentViewKit/Content/CommandOutputView.swift:207, Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift:75, Sources/AgentViewKit/Items/ToolCallView.swift:495, Sources/AgentViewKit/Items/ToolKindSymbol.swift:20, Sources/AgentViewKit/Terminal/TerminalView.swift:201, Tests/PackageStructureTests/SymbolNameScanner.swift:377, Tests/PackageStructureTests/SymbolNameScanner.swift:381
  timestamp: 2026-10-11T16:23:42.342889+00:00
- actor: claude-code
  id: 01m4nww6f9kayf21f4y12chxmh
  text: |-
    Review findings fixed (implement step, pass 2).
    - New file Sources/AgentViewKit/Items/SharedSymbol.swift: internal `nonisolated enum SharedSymbol` with `terminal = "apple.terminal"` and `copy = "document.on.document"`. The later symbol table card can add constants to it.
    - Terminal symbol: ToolKindSymbol `.execute`, PermissionView.commandSymbol, ToolCallView terminal part, TerminalView header and the ActivityTimeline terminal row now read SharedSymbol.terminal. ActivityEntryRow.terminalSymbolName is removed.
    - Copy symbol: MessageActions.Action.copy, CommandOutputView and CodeBlockView now read SharedSymbol.copy.
    - A search of Sources and Examples finds each of the two literals only in SharedSymbol.swift.
    - New test SymbolNameTests.eachSharedSymbolNameIsWrittenOnlyInTheSharedSymbolFile. RED 1: the file did not exist. RED 2: after the enum was added, the test found the repeated literals. GREEN after the call sites changed.
    - SymbolNameScanner.swift: the `2` values were the lengths of `/*` and `*/`. New constants lineCommentOpener, blockCommentOpener, blockCommentCloser; commentEnd uses their `count`. The other numbers in the file are 0, 1, -1 (allowed by magic-numbers-swift) and the named multiLineQuoteCount.
    - Full swift test: 1 + 101 + 1046 tests pass, 0 failures, the 1 known issue of HostedLayoutExpectationsTests. Only warning: the SwiftPM "missing creator for mutated node" line for the mlx-swift_Cmlx bundle in .build. Load average before 26.95 22.57 27.20, after 37.76 29.03 28.94. No UI tests were run.
  timestamp: 2026-10-11T16:31:29.769455+00:00
- actor: claude-code
  id: 01m4nww9bngjq4ynwk9ksa885h
  text: |-
    ### implement — changed
    - evidence: 11 files — Sources/AgentViewKit/Items/SharedSymbol.swift (new); Sources/AgentViewKit/{Activity/ActivityTimeline,Code/CodeBlockView,Content/CommandOutputView,HumanInTheLoop/PermissionView,Items/MessageActions,Items/ToolCallView,Items/ToolKindSymbol,Terminal/TerminalView}.swift; Tests/PackageStructureTests/{SymbolNameScanner,SymbolNameTests}.swift. swift test: 1148 tests pass (1 + 101 + 1046), 0 failures, 1 existing known issue. Load average 26.95 before, 37.76 after. 7 of 7 findings checked.
    - next: /review
  timestamp: 2026-10-11T16:31:32.725041+00:00
- actor: claude-code
  id: 01m4nxc68m3h84zg0h77td874e
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (e96684e): 0 findings, 0 confirmed, 0 refuted, 7 validators attempted, 0 failed. 11 files reviewed. All prior review items are checked.
    - next: none. The task moved to done.
  timestamp: 2026-10-11T16:40:13.844774+00:00
- actor: claude-code
  id: 01m4nxcraeq292nzczq1p45qp6
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — SharedSymbol (terminal, copy) read by 8 places; named comment-marker constants; 7 findings checked
    - test: green — swift test, 1046 tests passed, 1 expected known issue, load average 28 to 40
    - commit: e96684e
    - review: clean — 0 findings (11 files); task in done
  timestamp: 2026-10-11T16:40:32.334982+00:00
position_column: done
position_ordinal: ffa380
title: 'SF Symbols: replace the 11 old symbol names and the restricted passkey symbol'
---
## What
A check against the system symbol data (`CoreGlyphs.bundle`: `name_aliases.strings`, `name_availability.plist`, `symbol_restrictions.strings`) on 2026-10-11 found 11 old names that still work only as aliases, and one restricted symbol. Paths are below `Sources/AgentViewKit/`.

## Work
- [x] Change each old name to its current name:
  - `arrow.triangle.2.circlepath` → `arrow.trianglehead.2.clockwise.rotate.90` (`Items/ToolKindSymbol.swift:23`). Note: the new name is the same as the max-turn-requests banner (`Status/StateBanner.swift:208`). The concept card resolves this.
  - `clock.arrow.circlepath` → `clock.arrow.trianglehead.counterclockwise.rotate.90` (`Status/SessionStreamBanner.swift:146`)
  - `doc.on.clipboard` → `document.on.clipboard` (`Items/MessageActions.swift:75`)
  - `doc.richtext` → `richtext.page` (`Attachments/ArtifactView.swift:44`)
  - `largecircle.fill.circle` → `inset.filled.circle` (`Elicitation/ElicitationFieldViews.swift:632`)
  - `doc` → `document` (`Items/ToolCallView.swift:586`)
  - `doc.text` → `text.document` (`Items/ToolKindSymbol.swift:15`)
  - `doc.on.doc` → `document.on.document` (`Code/CodeBlockView.swift:106`, `Content/CommandOutputView.swift:207`, `Items/MessageActions.swift:74`)
  - `mic` → `microphone`, `mic.slash` → `microphone.slash` (`Input/SpeechInputButton.swift:85`, `:88`)
  - `terminal` → `apple.terminal` (`Activity/ActivityTimeline.swift:179`, `HumanInTheLoop/PermissionView.swift:69`, `Terminal/TerminalView.swift:29`, `:201`, `Items/ToolCallView.swift:495`, `Items/ToolKindSymbol.swift:20`, `Thread/TranscriptEntryKind.swift:33`)
- [x] `person.badge.key` (`Connections/AgentAuthView.swift:79`) has the system restriction "may only be used to refer to creating or signing in with a passkey". The agent sign-in is not a passkey flow. Use a symbol with no restriction (for example `person.badge.shield.checkmark` or `key`).
- [x] Test: no symbol name in Sources and Examples is in a fixed list of old alias names, and no name is a restricted symbol. `NSImage(systemSymbolName:)` also accepts the old names, so the existence check in `Tests/AgentViewKitTests/Items/ToolKindSymbolTests.swift:34`, `:53` cannot find them. Search the whole repository again for each old name before the task is closed.

## Notes
- Two "terminal" locations in the list are not symbol names, so they did not change. `Terminal/TerminalView.swift` `identifier = "terminal"` is the accessibility identifier of the view. `Thread/TranscriptEntryKind.swift` `case .terminal: "terminal"` is `kindName`, the tick identifier and the accessibility label of the minimap. The other five "terminal" locations are symbols, and they changed to `apple.terminal`.
- The passkey symbol changed to `person.badge.shield.checkmark`.
- The test reads the old names and the restricted names from the system files at test time. It does not use a fixed list.
- Open for the concept card: `ToolKindSymbol` `.switchMode` and the max-turn-requests banner (`Status/StateBanner.swift`) now use the same symbol `arrow.trianglehead.2.clockwise.rotate.90`. No test fails on this, so this card does not change it.
- The terminal symbol and the copy symbol are now in one place: `Items/SharedSymbol.swift` (`SharedSymbol.terminal`, `SharedSymbol.copy`). The later symbol table card can add more constants to this enum. The test `SymbolNameTests.eachSharedSymbolNameIsWrittenOnlyInTheSharedSymbolFile` fails when a source file writes a name of `SharedSymbol` again.

## Review Findings (2026-10-11 11:19)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 17 file(s) reviewed, 6 not reviewed.

> 6 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 6 file(s)

- [x] `Sources/AgentViewKit/Content/CommandOutputView.swift:207` `reuse/reuse` — The Copy output button repeats the literal "document.on.document", which is the same copy symbol that `MessageActions.Action.copy` already defines. Use one shared copy-symbol constant for both copy buttons.
- [x] `Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift:75` `reuse/reuse` — `commandSymbol` re-declares the SF Symbol `apple.terminal`, which is already the value of `ActivityEntryRow.terminalSymbolName`. Two copies of one symbol name can drift apart when a future change edits one and not the other. Keep one shared symbol constant for the terminal symbol, next to `ToolKindSymbol`, and have `commandSymbol`, `terminalSymbolName`, and the other call sites read it. `ActivityEntryRow` is file-private, so the constant must move out of it to be shared.
- [x] `Sources/AgentViewKit/Items/ToolCallView.swift:495` `reuse/reuse` — The terminal part row hard-codes "apple.terminal" again, although the same symbol is already defined in three places in the changed set (`ActivityEntryRow.terminalSymbolName` and `ToolKindSymbol.name(for: .execute)`). Read the shared terminal symbol constant (see the PermissionView finding) instead of the literal.
- [x] `Sources/AgentViewKit/Items/ToolKindSymbol.swift:20` `reuse/reuse` — The `.execute` case repeats the literal "apple.terminal" that other changed files also declare, so the terminal symbol now lives in four places. Make the `.execute` case return the shared terminal symbol constant, so `ToolKindSymbol` is the one source for it.
- [x] `Sources/AgentViewKit/Terminal/TerminalView.swift:201` `reuse/reuse` — The terminal header image hard-codes "apple.terminal" in a view that duplicates the symbol already used by the activity row and the permission card. Use the shared terminal symbol constant so all terminal surfaces change together.
- [x] `Tests/PackageStructureTests/SymbolNameScanner.swift:377` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/PackageStructureTests/SymbolNameScanner.swift:381` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
