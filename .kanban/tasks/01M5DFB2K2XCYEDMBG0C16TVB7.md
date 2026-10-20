---
assignees:
- claude-code
position_column: todo
position_ordinal: '9580'
title: 'AVK-8o Structure test: colors come from \.editorTheme, not from fixed colors'
---
## Why

D110 (e): colors come from the theme (`\.editorTheme`) and are never fixed for one glass look. Text on glass uses vibrant foreground styles (`.primary`, `.secondary`, `.tertiary`). A search of the sources today finds no fixed color in the views (no `Color.red`, no `Color(red:)`, no `NSColor.`), so this card adds a guard that keeps it so.

## Files

- New: `Tests/PackageStructureTests/ThemeColorTests.swift`, with fixtures in `Tests/PackageStructureTests/Fixtures/ThemeColors/` (one clean file, one file with each forbidden form).
- Pattern to copy: `Tests/PackageStructureTests/ImportBoundaryTests.swift` and its scanner.

## What to do

- [ ] Write a scanner that reads each Swift file in `Sources/AgentViewKit` and reports each line with a fixed color: `Color.<named color>`, `Color(red:`, `Color(white:`, `Color(hue:`, `NSColor.`, `UIColor.`, `.foregroundColor(` and `.foregroundStyle(.<named color>)`. The scanner ignores comments and string literals.
- [ ] Allow `Sources/AgentViewKit/Terminal/ANSIText.swift`. Its computed 256-color table is terminal data, not a theme color.
- [ ] Add fixture tests: the scanner reports each forbidden form in the bad fixture and nothing in the clean fixture.

## Acceptance

- `ThemeColorTests` passes on the current sources.
- The fixture tests prove that each forbidden form is found, with the file and the line.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8