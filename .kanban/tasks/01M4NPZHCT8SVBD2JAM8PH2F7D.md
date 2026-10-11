---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: 'SF Symbols: replace the 11 old symbol names and the restricted passkey symbol'
---
## What
A check against the system symbol data (`CoreGlyphs.bundle`: `name_aliases.strings`, `name_availability.plist`, `symbol_restrictions.strings`) on 2026-10-11 found 11 old names that still work only as aliases, and one restricted symbol. Paths are below `Sources/AgentViewKit/`.

## Work
- [ ] Change each old name to its current name:
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
- [ ] `person.badge.key` (`Connections/AgentAuthView.swift:79`) has the system restriction "may only be used to refer to creating or signing in with a passkey". The agent sign-in is not a passkey flow. Use a symbol with no restriction (for example `person.badge.shield.checkmark` or `key`).
- [ ] Test: no symbol name in Sources and Examples is in a fixed list of old alias names, and no name is a restricted symbol. `NSImage(systemSymbolName:)` also accepts the old names, so the existence check in `Tests/AgentViewKitTests/Items/ToolKindSymbolTests.swift:34`, `:53` cannot find them. Search the whole repository again for each old name before the task is closed.