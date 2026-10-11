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
position_column: doing
position_ordinal: '80'
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