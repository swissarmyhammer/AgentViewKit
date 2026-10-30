---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6532vrq3bp56ddvd2z9x0r7
  text: |-
    ### implement — changed
    - branch wt/style-rules, EditorKit 1e07fc0e (root + IntegrationTests; Package.resolved untracked)
    - commits: dacca85 (capture: StillCaptureContent dropped, stopProgressIndicators kept), 3414f73 (StyleRuleEngineTests; AVK scanners deleted), 650ad28 (docs)
    - evidence: root `swift test` green: 234 tests/38 suites (PackageStructureTests), 855/98, 16/3; 0 failures, no AVK warnings. `swift build --package-path IntegrationTests --build-tests` exit 0, no warnings. Integration/hosted/capture tests not run (UI pause).
    - no new hits from 1e07fc0e interpolation scanning.
    - allow lists: themeInjection (InlineCitation, demo AgentViewKitDemoApp + GalleryLook), contentFills (5 chip/terminal/citation files), symbol names (ToolKindSymbol: "_lost"/"Result lost" literals). ANSIText left fixedColors (stale). PromptCaretProbe gone.
    - EditorKit gaps reported to coordinator: file-level allow granularity (demo files exempt from tint too), themeInjection misses \.accent/tokenTint/selectedTokenTint, fixedColors misses `self.init(.sRGB, red:)`, SymbolNameScanner flags non-symbol literals in Symbol-named types, PreviewCoverage has no same-file mode, SwiftCodeText internal (AVK keeps SwiftLiteralLexer), no AVK StringCatalog scan existed.
    - next: /review
  timestamp: 2026-10-30T00:24:17.943967+00:00
- actor: claude-code
  id: 01m6534ey9t2rxd9rsrp1j7w1v
  text: |-
    Implemented on wt/style-rules (dacca85, 3414f73, 650ad28) on EditorKit 1e07fc0e.
    - The engines replace every AVK scan they cover, in StyleRuleEngineTests, and the old scanners are deleted. The PromptCaretProbe allow entry is removed, StillCaptureContent is gone (ReviewScreenRoot now turns on reduce motion), and stopProgressIndicators stays.
    - Root swift test is green: 234 + 855 + 16 tests. IntegrationTests builds; nothing in it was run because of the UI pause.
    - Eight engine gaps were reported to EditorKit.
  timestamp: 2026-10-30T00:25:10.345003+00:00
position_column: todo
position_ordinal: b480
title: 'Adopt EditorKit 8c924484: StyleRules engines replace AVK''s own style scans; PromptCaretProbe allow entry dropped; capture errors and HostedViewHarness.click'
---
EditorKit 8c924484 is on origin/main.

- [ ] ^3q7j9nd: every PackageStructureTests scan that holds a style.md rule uses the matching `StyleRules` engine, configured with roots and a [path: reason] allow list. No AVK scanner variant. The engines are:
  - `.textInputControls`, `.fontRoles`, `.themeInjection`, `.fixedColors`, `.contentFills`
  - `.systemStructure`, `.glassPlacement`, `.offscreenRenderers`
  - `SymbolNameScanner`, `HostedSerialScanner`, `StringCatalogScanner`, `PreviewCoverageScanner`
- [ ] Delete the AVK scanners these engines replace. OuterSpacingScanner stays until ^ny8zhz5.
- [ ] ^qkc9fbg: remove the PromptCaretProbe entry from the text-input allow list.
- [ ] ^xv401e7: the capture errors (`screenRecordingDenied`, `captureNeverCalledBack`, `deadlinePassed`) need no AVK code. ReviewScreenRoot now freezes animation, so drop any AVK reduce-motion injection.
- [ ] ^h3bj2nr: hosted tests that click text views use `HostedViewHarness.click(at:)`. Button actions still go through `press(identifier:)`.
- [ ] Root swift test (unit-only) is green.

Starts on top of wt/integration-tests (^f89p8k), because both edit PackageStructureTests. #cross-repo