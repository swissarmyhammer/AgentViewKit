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
depends_on:
- 01M4NPHNFGP5JDZS02XHHE6BE3
position_column: doing
position_ordinal: '80'
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