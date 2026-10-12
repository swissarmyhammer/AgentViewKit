---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4pskdrj8hp4gdppfp732scj
  text: |-
    Research (2026-10-11):
    - Rendering mode: the symbols without `.hierarchical` are `ToolStatusImage` (tool call status, also used by ActivityTimeline), the kind and disclosure symbols of `ToolCallHeader`, the row symbol of `ActivityTimeline` (TimelineRow), and the file symbol of `DiffView.fileRow`. The priority symbol of `TaskListView` also has no mode.
    - Spinner and pulse: `ToolCallHeader.statusGlyph` shows a `ProgressView` and the status symbol with `.variableColor.iterative`. Plan: keep the symbol effect, remove the `ProgressView`.
    - `circle.dotted` does not exist now. `TaskListView.statusSymbol(.inProgress)` gives `SharedSymbol.inProgress`, but `PlanEntryRow` shows a `ProgressView` in its place. Plan: show the symbol with the same effect as the tool call.
    - Banners: `StatusBar` draws the symbol of `StateBanner` and `SessionStreamBanner`. The running message has `SharedSymbol.inProgress`, the replaying message has `SharedSymbol.replaying`.
    - Usage ring: on macOS, Dynamic Type does not scale body text (DynamicTypeHostedTests). A symbol scales with the font. A probe with ImageRenderer showed that `gauge.open` with `symbolVariableValueMode(.draw)` draws an open ring that fills with the variable value. `circle` also does this, but `SharedSymbol.notChosen` already has `circle`. `gauge.open.with.lines.needle.84percent.exclamation` is a current name for the full state.
    - Elicitation: `.accessibilityValue(isSelected ? "selected" : "")` takes a String, so the text is not localized.
    - Demo: `ACPTabView.failureLabel` uses `.foregroundStyle(.red)`. The demo app target links EditorTheme and EditorSwiftUI.
  timestamp: 2026-10-12T00:53:31.026285+00:00
- actor: claude-code
  id: 01m4ptgtgw9jj8g1yjwc1p62xt
  text: |-
    Implementation landed (not committed). What changed:
    - Rendering mode: `.symbolRenderingMode(.hierarchical)` on `ToolStatusImage`, on the kind and disclosure symbols of `ToolCallHeader`, on the row symbol of the `ActivityTimeline` row, on the file symbol of `DiffView.fileRow`, and on the priority symbol of `PlanEntryRow`. The new package test `SymbolRenderingModeTests` holds each `Image(systemName:)` of the status view files in this mode.
    - Spinner and pulse: `ToolCallHeader.statusGlyph` keeps the symbol with `.variableColor.iterative` and removes the `ProgressView`.
    - Plan in progress: `PlanEntryRow` shows `SharedSymbol.inProgress` with the same effect as the tool call, removed under Reduce Motion. The `ProgressView` is gone, so the name is used.
    - Banners: `StateBanner.Message.isOngoing` is true for the symbols `inProgress` and `replaying`. `StatusBar` gives such a symbol `.variableColor.iterative`, with `.symbolEffectsRemoved(reduceMotion)` as in ToolCallView.
    - Usage ring: an `Image(systemName: SharedSymbol.usage, variableValue:)` with `.symbolVariableValueMode(.draw)` (`gauge.open`), so it scales with the font. A full ring shows `SharedSymbol.usageFull` (`gauge.open.with.lines.needle.84percent.exclamation`) in the failed color. The view has the accessibility label `UsageRingView.labelText` ("Usage"). `ContextUsageView` still gives "Context used" over it.
    - Elicitation: the radio value is `ElicitationSingleChoiceField.selectedValue` (`String(localized: "Selected")`). The same cause in the file is also removed: `noSelectionTitle` and `requiredLabel` are now `String(localized:)`.
    - Demo: `ACPTabView.failureLabel` uses `editorTheme.severityError`. The new package test `FixedColorTests` holds `Sources` and `Examples` free of fixed system colors. The demo app builds with xcodebuild (no UI tests ran).
    Discoveries:
    - On macOS, a SwiftUI `ProgressView` shows as an `NSProgressIndicator` in the hosting view. The new helper `HostedViewHarness.progressIndicatorCount()` counts them, and `HarnessProgressIndicatorTests` proves the count.
    - The symbol `circle` also draws with the variable value, but `SharedSymbol.notChosen` already has it, so the ring uses `gauge.open`.
    - The build prints `warning: missing creator for mutated node` for the mlx-swift_Cmlx bundle. It comes from a dependency build product, and it showed before this change.
  timestamp: 2026-10-12T01:09:34.364299+00:00
- actor: claude-code
  id: 01m4pth2mv3aycja9wqnq5x60x
  text: |-
    ### implement — changed
    - evidence: `swift test` 1114 tests in 123 suites passed (1 known issue, the designed `withKnownIssue` of HostedLayoutExpectationsTests), XCTest 0 failures, PackageStructure 108 tests passed. Load average 55.08 at start, 64.73 at end. Demo app: `xcodebuild -scheme AgentViewKitDemo build` succeeded. RED run before the change: 10 issues in the new tests; GREEN run: 42 tests passed.
    - files: Sources/AgentViewKit/{Items/SharedSymbol.swift, Items/ToolStatusImage.swift, Items/ToolCallView.swift, Activity/ActivityTimeline.swift, Diff/DiffView.swift, Status/TaskListView.swift, Status/StateBanner.swift, Status/StatusBar.swift, Status/UsageRingView.swift, Elicitation/ElicitationFieldViews.swift}, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift; tests: PackageStructureTests/{SymbolRenderingModeTests.swift, FixedColorTests.swift}, AgentViewKitTests/{Helpers/HarnessProgressIndicators.swift, TestSupport/HarnessProgressIndicatorTests.swift, Status/UsageRingViewHostedTests.swift, Status/StatusBarEffectTests.swift, Status/UsageRingViewTests.swift, Status/ContextUsageSessionModelHostedTests.swift, Items/ToolCallViewHostedTests.swift, Items/SessionEntryRowsHostedTests.swift, Items/SymbolConceptTests.swift, Elicitation/ElicitationFieldViewsHostedTests.swift}
    - next: /review
  timestamp: 2026-10-12T01:09:42.683847+00:00
- actor: claude-code
  id: 01m4pva3y4aqqt0hsqyamxxm7z
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (8b46bdf). 5 findings (5 confirmed, 4 refuted). Sources/AgentViewKit/Items/ToolCallView.swift:419, Sources/AgentViewKit/Status/StatusBar.swift:67, Sources/AgentViewKit/Status/TaskListView.swift:222 (2 findings), Sources/AgentViewKit/Status/TaskListView.swift:227
    - next: Add one shared modifier for the variable-color effect and the Reduce Motion removal. Add one shared status-symbol view. Use them in ToolCallView, StatusBar and TaskListView. The task stays in review.
  timestamp: 2026-10-12T01:23:23.204070+00:00
- actor: claude-code
  id: 01m4pvamhvjd9r2j0v22act477
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — hierarchical rendering, one pulse signal, banner effects, gauge usage ring, localized elicitation values, demo theme color, new package tests
    - test: green — swift test, 1114 tests passed, 1 expected known issue, load average 52 to 71
    - commit: 8b46bdf
    - review: findings — Sources/AgentViewKit/Items/ToolCallView.swift:419, Sources/AgentViewKit/Status/StatusBar.swift:67, Sources/AgentViewKit/Status/TaskListView.swift:222 (two findings), Sources/AgentViewKit/Status/TaskListView.swift:227
  timestamp: 2026-10-12T01:23:40.219244+00:00
- actor: claude-code
  id: 01m4pvx3d2jd22c05axy2kysg5
  text: |-
    Review findings fixed (not committed). What changed:
    - New `Items/LiveSymbolEffect.swift`: the `LiveSymbolEffect` view modifier and `View.liveSymbolEffect(isActive:)`. It applies `.variableColor.iterative` while `isActive`, and `.symbolEffectsRemoved(reduceMotion)` with Reduce Motion from the environment. ToolCallHeader.statusGlyph, StatusBar and PlanEntryRow.statusSymbol call it with their own `isActive`. Their `reduceMotion` environment properties are gone.
    - In `statusGlyph` the modifier comes after `.symbolEffect(.bounce, ...)`, so under Reduce Motion it also removes the bounce, as the old chain did (the removal was the last modifier before too).
    - New `Items/StatusSymbolImage.swift`: a view with a symbol name and a color. It sets the hierarchical mode, the symbol weight and the color. ToolStatusImage, PlanEntryRow (status and priority symbols) and StatusBar use it. Each caller keeps its own status-to-symbol map and color.
    - Test: new `Tests/PackageStructureTests/SharedSymbolTreatmentTests.swift`. It holds `.variableColor` and `.symbolEffectsRemoved(` in `LiveSymbolEffect.swift` only, and holds `Image(systemName:` out of ToolStatusImage.swift, TaskListView.swift and StatusBar.swift. RED: 2 failures before the change. GREEN after.
    - `SymbolRenderingModeTests` now reads `StatusSymbolImage.swift` in place of `ToolStatusImage.swift`, because the image moved.
    - Follow-up task added: CompactionEntryView, ErrorView and SessionNoticeBanner write the same chain. They are outside the findings.
  timestamp: 2026-10-12T01:33:45.250907+00:00
- actor: claude-code
  id: 01m4pvx8bw3qm4mgqb0akj1fkn
  text: |-
    ### implement — changed
    - evidence: `swift test` 1114 tests in 123 suites passed (1 known issue, the designed `withKnownIssue` of HostedLayoutExpectationsTests), XCTest 0 failures, PackageStructure 111 tests in 13 suites passed. Load average 76.24 at start, 48.65 at end. The only warning is the known `missing creator for mutated node` of the mlx-swift_Cmlx bundle (dependency). RED: 2 issues in SharedSymbolTreatmentTests; GREEN: 5 tests passed. No UI tests ran.
    - files: Sources/AgentViewKit/Items/{LiveSymbolEffect.swift (new), StatusSymbolImage.swift (new), ToolStatusImage.swift, ToolCallView.swift}, Sources/AgentViewKit/Status/{StatusBar.swift, TaskListView.swift}, Tests/PackageStructureTests/{SharedSymbolTreatmentTests.swift (new), SymbolRenderingModeTests.swift}
    - findings: 5 of 5 checked.
    - next: /review
  timestamp: 2026-10-12T01:33:50.332939+00:00
- actor: claude-code
  id: 01m4pwcnqsy2g8h9sv534e23rq
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (47b83ce). 1 finding (1 confirmed, 1 refuted). Tests/PackageStructureTests/SharedSymbolTreatmentTests.swift:36
    - next: implement the open item in the 2026-10-11 20:38 Review Findings section. The task stays in review.
  timestamp: 2026-10-12T01:42:15.545952+00:00
- actor: claude-code
  id: 01m4pwd1k44m9myf3a7rmw9zfy
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — LiveSymbolEffect and StatusSymbolImage; 5 findings checked
    - test: green — swift test, 1114 tests passed, 1 expected known issue, load average 44 to 59
    - commit: 47b83ce
    - review: findings — Tests/PackageStructureTests/SharedSymbolTreatmentTests.swift:36
  timestamp: 2026-10-12T01:42:27.684708+00:00
- actor: claude-code
  id: 01m4pwgg221bfkbqc4mapmenmq
  text: |-
    Research for the finding at SharedSymbolTreatmentTests.swift:36 (2026-10-11):
    - `symbolImageCall = "Image(systemName:"` is in SharedSymbolTreatmentTests and in SymbolRenderingModeTests.
    - Other repeated texts between the four package suites: `["Sources", "Examples"]` (FixedColorTests.scannedPaths, SymbolNameTests.scannedPaths); `"Sources/AgentViewKit"` (SharedSymbolTreatmentTests.kitSourcesPath, SymbolNameTests.kitPath, and the prefix `"Sources/AgentViewKit/"` in SymbolNameTests); the paths of StatusBar.swift and TaskListView.swift (SymbolRenderingModeTests and SharedSymbolTreatmentTests).
    - PackageFileSupport is a library target that AgentViewKitTests also imports. These texts are for the package scans only, so the plan puts them in one new helper of the PackageStructureTests target: `KitSourceFiles`.
    - RemovedVocabularyTests also has `kitSourcesPath = "Sources/AgentViewKit"`. That suite is not one of the four suites of this finding, so it stays as it is.
  timestamp: 2026-10-12T01:44:20.802071+00:00
- actor: claude-code
  id: 01m4pwv2eck8qv671hp624r9gq
  text: |-
    Finding at SharedSymbolTreatmentTests.swift:36 fixed (not committed). What changed:
    - New `Tests/PackageStructureTests/KitSourceFiles.swift`: one enum with the texts that the package scans share. `kitPath` ("Sources/AgentViewKit"), `viewPaths` (["Sources", "Examples"]), `symbolImageCall` ("Image(systemName:"), `statusBarFile`, `taskListFile`, and `kitFile(_:)`, which gives the path of a file below `kitPath`.
    - The helper is in the PackageStructureTests target, not in PackageFileSupport. PackageFileSupport is a library that AgentViewKitTests also imports, and these texts are for the package scans only.
    - SharedSymbolTreatmentTests: removed `symbolImageCall` and `kitSourcesPath`. It reads `KitSourceFiles`. Its file paths use `kitFile(_:)`, `statusBarFile` and `taskListFile`.
    - SymbolRenderingModeTests: removed `symbolImageCall`. Its file paths use `kitFile(_:)`, `statusBarFile` and `taskListFile`.
    - FixedColorTests and SymbolNameTests: removed the two copies of `scannedPaths`. They read `KitSourceFiles.viewPaths`. SymbolNameTests also removed `kitPath`, and reads `KitSourceFiles.kitPath` and `kitFile(_:)`.
    - New `KitSourceFilesTests` (3 tests): `kitFile(_:)` gives a path below the kit directory, the two shared files are in the package, and each view path is a directory of the package. RED: the build failed, because `KitSourceFiles` did not exist. GREEN: 29 tests of the 5 suites passed.
    - Not changed: RemovedVocabularyTests also has `kitSourcesPath = "Sources/AgentViewKit"`. It is not one of the four suites of this finding.
  timestamp: 2026-10-12T01:50:07.308396+00:00
- actor: claude-code
  id: 01m4pwv5f3gcgns7tvyn6qzvqr
  text: |-
    ### implement — changed
    - evidence: `swift test` exit 0: 1114 tests in 123 suites passed (1 known issue, the designed `withKnownIssue` of HostedLayoutExpectationsTests), PackageStructure 114 tests in 14 suites passed, XCTest 0 failures. Load average 45.53 at start, 49.19 at end. The only warning is the known `missing creator for mutated node` of the mlx-swift_Cmlx bundle (dependency). No UI tests ran.
    - files: Tests/PackageStructureTests/{KitSourceFiles.swift (new), KitSourceFilesTests.swift (new), SharedSymbolTreatmentTests.swift, SymbolRenderingModeTests.swift, SymbolNameTests.swift, FixedColorTests.swift}
    - findings: 1 of 1 checked in the 2026-10-11 20:38 section.
    - next: /review
  timestamp: 2026-10-12T01:50:10.403062+00:00
- actor: claude-code
  id: 01m4px9efvpysn6370kychaaw5
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (156e061). 2 findings, 2 confirmed, 1 refuted. Tests/PackageStructureTests/FixedColorTests.swift:74, Tests/PackageStructureTests/SymbolNameTests.swift:19
    - next: implement — put the walk over KitSourceFiles.viewPaths into one shared helper, and use it in FixedColorTests and SymbolNameTests.
  timestamp: 2026-10-12T01:57:58.395342+00:00
- actor: claude-code
  id: 01m4px9tg7xp84jyxgv7qf6nmb
  text: |-
    ### finish iteration 3 — findings
    - implement: changed — KitSourceFiles helper for the shared search texts and paths; finding checked
    - test: green — swift test, 1114 tests passed, 1 expected known issue, load average 45 to 58
    - commit: 156e061
    - review: findings — Tests/PackageStructureTests/FixedColorTests.swift:74, Tests/PackageStructureTests/SymbolNameTests.swift:19
  timestamp: 2026-10-12T01:58:10.695143+00:00
- actor: claude-code
  id: 01m4pxpjrshsc0d2vvfc0696sk
  text: |-
    Findings at FixedColorTests.swift:74 and SymbolNameTests.swift:19 fixed (not committed). What changed:
    - New `KitSourceFiles.scanViewFiles(_:)`: a generic helper that runs a scan closure on the URL of each directory of `viewPaths`, and gives the results in the order of `viewPaths`. It gives the error of `PackageFiles.file(_:)` or of the scan. `KitSourceFiles.swift` now imports Foundation and PackageFileSupport.
    - FixedColorTests.noViewUsesAFixedSystemColor and SymbolNameTests.symbolNames() call the helper. Each test keeps only its own scanner call (`SourceLineScanner.matches` and `SymbolNameScanner.names`).
    - The same loop was also in KitSourceFilesTests.eachViewPathIsADirectoryOfThePackage. It now calls `scanViewFiles(PackageFiles.swiftFiles(in:))`.
    - SymbolRenderingModeTests and SharedSymbolTreatmentTests do not walk `viewPaths`. They read fixed file lists, or the one `kitPath` directory. They have no copy of this loop, so they did not change.
    - New tests in KitSourceFilesTests: the scan gets each view directory in order, and the scan error comes back to the caller. RED: the build failed, because `scanViewFiles` did not exist. GREEN: 5 tests of KitSourceFilesTests passed.
  timestamp: 2026-10-12T02:05:08.761161+00:00
- actor: claude-code
  id: 01m4pxpndv1adkw6jvma425kz4
  text: |-
    ### implement — changed
    - evidence: `swift test` exit 0: 1114 tests in 123 suites passed (1 known issue, the designed `withKnownIssue` of HostedLayoutExpectationsTests), PackageStructure 116 tests in 14 suites passed, XCTest 0 failures. Load average 40.50 at start, 46.00 at end. The only warning is the known `missing creator for mutated node` of the mlx-swift_Cmlx bundle (dependency). No UI tests ran.
    - files: Tests/PackageStructureTests/{KitSourceFiles.swift, KitSourceFilesTests.swift, FixedColorTests.swift, SymbolNameTests.swift}
    - findings: 2 of 2 checked in the 2026-10-11 20:54 section.
    - next: /review
  timestamp: 2026-10-12T02:05:11.483525+00:00
- actor: claude-code
  id: 01m4py4ppffasxqc7ez2td9t7y
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (16aed33). 0 findings, 0 confirmed, 0 refuted. 7 validator runs, 0 failed. 4 files reviewed. All prior findings are checked.
    - next: none. The task is in done.
  timestamp: 2026-10-12T02:12:51.535356+00:00
- actor: claude-code
  id: 01m4py50c4hx4rehqbcy0v6x69
  text: |-
    ### finish iteration 4 — clean
    - implement: changed — KitSourceFiles.scanViewFiles(_:) used by the package scans; 2 findings checked
    - test: green — swift test, 1114 tests passed, 1 expected known issue, load average 44 to 60
    - commit: 16aed33
    - review: clean — 0 findings (4 files); task in done
  timestamp: 2026-10-12T02:13:01.444450+00:00
depends_on:
- 01M4NPHNFGP5JDZS02XHHE6BE3
position_column: done
position_ordinal: ffab80
title: 'SF Symbols: rendering mode, symbol effects, scalable usage ring, and accessibility text'
---
## What
An audit on 2026-10-11 found differences in how symbols are drawn, and missing accessibility text. Paths are below `Sources/AgentViewKit/` unless stated.

## Work
- [x] Use the same rendering mode for the tool call, timeline and diff icons as for the other views (`.hierarchical` in ErrorView, StatusBar, SessionNoticeBanner, TaskListView, CompactionEntryView).
- [x] A running tool call shows a spinner and a pulsing symbol at the same time (`Items/ToolCallView.swift:389`, `:396`). Keep one.
- [x] `circle.dotted` (`Status/TaskListView.swift:199`) never shows, because a `ProgressView` replaces it. Remove the dead name or use it.
- [x] Give the running and replaying banners a symbol effect (`Status/StateBanner.swift:164`, `Status/SessionStreamBanner.swift:146`). Turn the effect off under Reduce Motion, as `ToolCallView.swift:398` does.
- [x] Usage ring: replace the drawn 16 pt ring (`Status/UsageRingView.swift:25`, `:139-145`) with a view that scales with the text size (for example a `Gauge` or a variable-value symbol). Give it an accessibility label (`:128` has a value and a hint only). Show the full state with a signal that is not only the failure color (`:151`).
- [x] Elicitation radio buttons: localize the accessibility value "selected", or use `Picker` with `.radioGroup` (`Elicitation/ElicitationFieldViews.swift:625-640`).
- [x] Demo: use the theme color in place of `.red` (`Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift:352`).
- [x] Tests for each change.

## Review Findings (2026-10-11 20:16)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 23 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Sources/AgentViewKit/Items/ToolCallView.swift:419` `duplication/duplication` — The variable-color effect with Reduce Motion gating is copied in three places. Each copy has the same two modifiers and differs only in the `isActive` condition. A change to the Reduce Motion rule must be made in each copy. Add one view modifier, for example `.liveSymbolEffect(isActive:)`, that applies the variable-color effect and the Reduce Motion removal. Call it from the three sites with each site's own `isActive` value.
- [x] `Sources/AgentViewKit/Status/StatusBar.swift:67` `reuse/reuse` — The `.symbolEffect(.variableColor.iterative, isActive:)` plus `.symbolEffectsRemoved(reduceMotion)` pair is written out again for the ongoing-message symbol. The same pair already appears in the tool-call and plan-entry status symbols, so the Reduce Motion gate for ongoing symbols is copied in three files. Add one shared modifier, for example `.ongoingSymbolEffect(isActive:)`, that applies the variable-color effect and `symbolEffectsRemoved(reduceMotion)` from the environment. Use it in `StatusBar`, `statusGlyph`, and `PlanEntryRow.statusSymbol`, so the Reduce Motion handling is written once.
- [x] `Sources/AgentViewKit/Status/TaskListView.swift:222` `duplication/duplication` — The new `PlanEntryRow.statusSymbol` repeats the status symbol view that `ToolStatusImage` already provides. It sets the same hierarchical rendering, the same symbol weight, and the same status color. A later change to one copy can leave the other out of sync. Add a shared view or helper that takes a symbol name and a status color, and call it from both `ToolStatusImage` and `PlanEntryRow`. Keep the per-type mapping in each caller. Delete the copied modifier chain.
- [x] `Sources/AgentViewKit/Status/TaskListView.swift:222` `reuse/reuse` — `PlanEntryRow.statusSymbol` rebuilds the status glyph that `ToolCallHeader.statusGlyph` already builds: hierarchical rendering, status color, symbol weight, the variable-color iterative effect while the status is live, and `symbolEffectsRemoved(reduceMotion)`. Two copies of one status-symbol treatment will drift apart. A later change to the live effect or the Reduce Motion rule would have to be made in both places. Move the live-status effect and the Reduce Motion handling into one shared `ViewModifier` (for example, a status-symbol modifier that takes `isLive` and applies the variable-color effect with `symbolEffectsRemoved`). Apply it from `statusGlyph`, `statusSymbol` and `ToolStatusImage`, so the rule lives in one place.
- [x] `Sources/AgentViewKit/Status/TaskListView.swift:227` `duplication/duplication` — The variable-color effect with Reduce Motion gating is copied in `PlanEntryRow.statusSymbol`. It repeats the same effect pair used in `ToolCallView` and `StatusBar`, so a change to the Reduce Motion rule must be made in three places. Use the same shared modifier proposed for `ToolCallView.swift:419`, with `entry.status == .inProgress` as its `isActive` value. Delete the copied modifiers here.

## Review Findings (2026-10-11 20:38)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 8 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Tests/PackageStructureTests/SharedSymbolTreatmentTests.swift:36` `reuse/reuse` — The new constant symbolImageCall = "Image(systemName:" copies a constant that already exists. SymbolRenderingModeTests already defines the same text, so two copies of one search string now exist and can drift apart. Remove the constant at line 36. Read SymbolRenderingModeTests.symbolImageCall instead, or move the shared constant into PackageFileSupport so both suites use one definition.

## Review Findings (2026-10-11 20:54)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 6 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Tests/PackageStructureTests/FixedColorTests.swift:74` `reuse/reuse` — The loop that runs a scan over each path in KitSourceFiles.viewPaths is written again here. The same loop is in SymbolNameTests.symbolNames(). The two copies must change together when the view paths or the scan call change. Move the loop into one helper in KitSourceFiles or in the package file support. For example, a generic `forEachViewFile` that takes the scanner as a closure. Then this test and SymbolNameTests.symbolNames() both call that helper. Keep the per-scan call in each test.
- [x] `Tests/PackageStructureTests/SymbolNameTests.swift:19` `reuse/reuse` — The loop over KitSourceFiles.viewPaths is a near-copy of the loop in FixedColorTests.noViewUsesAFixedSystemColor. It repeats the view-path walk instead of using one shared helper. Use the same shared helper that FixedColorTests uses, so the view-path walk exists once. Keep the scanner call (SymbolNameScanner.names) as the only part that differs.