---
assignees:
- claude-code
position_column: todo
position_ordinal: a580
title: 'FontRoleTests: forbid fixed-size AppKit/UIKit font factories and preferredFont(forTextStyle:)'
---
From testudoapp-2c (2026-10-24). At 6493d6f, `Tests/PackageStructureTests/FontRoleTests.swift` does not forbid the fixed-size AppKit/UIKit font factories. Each of them picks a font outside the theme roles:
- systemFont(ofSize:), boldSystemFont(ofSize:), italicSystemFont(ofSize:)
- labelFont, menuFont, menuBarFont, messageFont, paletteFont, titleBarFont, toolTipsFont, controlContentFont, userFont (each with ofSize:)
- monospacedDigitSystemFont(ofSize:weight:)
- preferredFont(forTextStyle:), a bare system text style

Testudo closed the same gap in cb6ec3d (Tests/SAHKitTests/FontRoleScan.swift):
- The one literal `Font\(ofSize:` catches every factory. It does not match `image.thumbnail(ofSize:)` or `NSFont.systemFontSize(for:)`.
- `preferredFont\(forTextStyle:` goes in the bare-text-style group.
- Watch out: Swift Regex `\b` is a Unicode word boundary, so `\bpreferredFont` never matches `NSFont.preferredFont`. Drop the anchor.

Checklist:
- [ ] FontRoleTests forbids `Font(ofSize:` (every factory above) in Sources/AgentViewKit and in the demo sources the test already scans.
- [ ] FontRoleTests forbids `preferredFont(forTextStyle:` in the bare-text-style group.
- [ ] Self-tests show each pattern catches a violating sample and leaves `thumbnail(ofSize:)` and `systemFontSize(for:)` alone.
- [ ] Every site the new rules flag routes through a theme role (`editorTheme.font(for:style:)` / `face(for:)`). List the sites. Fixing them is part of this card, not an exception. #avk-8