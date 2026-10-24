---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5qxw6hhrk3m40trpr37v011
  text: 'Research: FontRoleTests scans KitSourceFiles.viewPaths = ["Sources", "Examples"]. A repo grep for `Font\(ofSize:` and `preferredFont\(forTextStyle:` over Sources and Examples finds one site: Sources/AgentViewKit/Citations/InlineCitation.swift, `InlineCitationMetrics.init`, `NSFont.monospacedDigitSystemFont(ofSize:weight:)`. It measures the pill digits in the system font while InlineCitationPill draws them in `editorTheme.face(for: .ui)`, so the size can be wrong under a ui family. Plan: InlineCitationMetrics takes the ui FontFace, builds the digit font from it, and measures the resolved CTFont (Font.Resolved.ctFont, macOS 26+). The Textual attachment (InlineCitationAttachment) has no theme in TextEnvironmentValues, so CitationMarkdownParser carries the ui face from MarkdownProse into the attachment. Test-only uses (Tests/AgentViewKitTests/Theme/*) are outside the scanned paths.'
  timestamp: 2026-10-24T21:43:09.105557+00:00
- actor: claude-code
  id: 01m5qygf49hmd974cj377yjzya
  text: |-
    Implementation landed. FontRoleTests: `Font(ofSize:` joins fontOutsideTheRolesPattern; bareTextStylePattern is now ChoiceOf { "preferredFont(forTextStyle:" (no boundary anchor), swiftUITextStylePattern }; a shared `matches(of:on:)` helper. New self-tests: each of the 13 factories (NSFont/UIFont) caught, NSFont/UIFont preferredFont caught by the bare-text-style pattern alone, `image.thumbnail(ofSize:)` and `NSFont.systemFontSize(for:)` not caught. RED seen first (both positive tests found [] before the patterns), then the repo scan went red on the one flagged site.

    Flagged site (only one in Sources + Examples): Sources/AgentViewKit/Citations/InlineCitation.swift InlineCitationMetrics.init used NSFont.monospacedDigitSystemFont(ofSize:weight:). Fix: InlineCitationMetrics(index:textFontSize:face:) sizes the `ui` FontFace, builds `digitFont` (weight semibold, monospacedDigit) and measures `digitFont.resolve(in: EnvironmentValues().fontResolutionContext).ctFont as NSFont`. InlineCitationPill draws metrics.digitFont, so the drawn and measured font are one. Textual's TextEnvironmentValues carries no theme, so CitationMarkdownParser gets `digitFace` (MarkdownProse passes editorTheme.face(for: .ui)) and hands it to InlineCitationAttachment. Side effect worth knowing: before this, the pill measured in the system font while drawing in the ui face, so a ui family theme could get a mis-sized pill. New test CitationProseTests.thePillTakesItsWidthFromTheDigitsOfTheUIFace (RED as a compile failure, then green).
  timestamp: 2026-10-24T21:54:13.257004+00:00
- actor: claude-code
  id: 01m5qygmbw2ps9mv8dsdgmp2jf
  text: |-
    ### implement — changed
    - evidence: 5 files — Tests/PackageStructureTests/FontRoleTests.swift, Sources/AgentViewKit/Citations/InlineCitation.swift, Sources/AgentViewKit/Citations/CitationProse.swift, Sources/AgentViewKit/Content/MarkdownProse.swift, Tests/AgentViewKitTests/Citations/CitationProseTests.swift. `swift test`: 1814 tests in 223 suites passed, 7 known issues, 0 repo warnings. Demo xcodeproj regenerated; xcodebuild AgentViewKitDemo build: BUILD SUCCEEDED, 0 repo warnings. Scripts/test-examples.sh AgentViewKitDemo (holds the shared UI-test lock): TEST SUCCEEDED, 10 tests, 0 failures. Flagged sites: InlineCitation.swift InlineCitationMetrics.init (only one), now routed through editorTheme.face(for: .ui).
    - next: /review
  timestamp: 2026-10-24T21:54:18.620970+00:00
- actor: claude-code
  id: 01m5qyxfkzheemkacmrwnm5dh7
  text: |-
    ### test — green
    - evidence: `swift test` — 1814 tests in 223 suites passed, 7 known issues (expected), 0 failures. Regenerated xcodeproj, then `xcodebuild -project Examples/AgentViewKitDemo/AgentViewKitDemo.xcodeproj -scheme AgentViewKitDemo -skipMacroValidation -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile build` — BUILD SUCCEEDED, 0 repo warnings (only Xcode's appintentsmetadataprocessor notice). `Scripts/test-examples.sh AgentViewKitDemo` — 10 UI tests, 0 failures, "The example gate passed." Ran under the shared UI-test lock. No draft files left; git status is unchanged.
    - next: review
  timestamp: 2026-10-24T22:01:19.743211+00:00
position_column: doing
position_ordinal: '8480'
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
- [x] FontRoleTests forbids `Font(ofSize:` (every factory above) in Sources/AgentViewKit and in the demo sources the test already scans.
- [x] FontRoleTests forbids `preferredFont(forTextStyle:` in the bare-text-style group.
- [x] Self-tests show each pattern catches a violating sample and leaves `thumbnail(ofSize:)` and `systemFontSize(for:)` alone.
- [x] Every site the new rules flag routes through a theme role (`editorTheme.font(for:style:)` / `face(for:)`). List the sites. Fixing them is part of this card, not an exception.
  - Sites flagged (one): Sources/AgentViewKit/Citations/InlineCitation.swift, `InlineCitationMetrics.init`, `NSFont.monospacedDigitSystemFont(ofSize:weight:)`. Now built from `editorTheme.face(for: .ui)`. #avk-8