---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5pxt000zmr1nnvx0zvhnjnq
  text: |-
    ### dependency (2026-10-24)
    EditorKit filed the shared selection surface as card 01M5PXSJHPTMDTANGXTFN4SP6B. It adds `.selectionSurface(_:radius:)`, the tokens `selectionOpacity` (0.20) and `inactiveSelectionOpacity` (0.08), the `appearsActive` grey fallback and the `.isSelected` trait, and moves the palette and completion rows onto it. It is additive and goes straight to EK main with no hold branch. It is queued behind EK ^b84akwb. Start this card only once that card's commit is on EK main, and record the SHA.
  timestamp: 2026-10-24T12:22:42.432939+00:00
- actor: claude-code
  id: 01m5q4wn5508y5fnqj8jpenhmh
  text: |-
    ### dependency landed (2026-10-24)
    EditorKit 01M5PXSJHPTMDTANGXTFN4SP6B (^fn4sp6b) is on EK main fd2ce62; the feature commit is ed23895. This card can start.

    API:
    - `.selectionSurface(_ isSelected: Bool, radius: EditorStyle.Radius)` in EditorStyle.
    - `EditorStyle.selectionOpacity` (0.20) and `EditorStyle.inactiveSelectionOpacity` (0.08) are static lets.
    - A `.tint` fill in the surface shape behind the content; `.primary` at 0.08 when `\.appearsActive` is false.
    - Text stays primary, the modifier adds `.isSelected`, and the focus ring is unchanged.

    EK adopted it in palette rows (the white-text swap is gone), completion rows, workspace tabs and outline rows.

    Breaking: `rowCornerRadius` was removed from the palette and completion ResolvedModel, and so was `DefaultCommandPaletteStyle.rowCornerRadius(in:)`. Check whether AVK uses either.

    Test tip: hosted test windows are not key, so set `\.appearsActive` to true to see the accent fill.
  timestamp: 2026-10-24T14:26:29.669411+00:00
- actor: claude-code
  id: 01m5qt9m9q7je1pcg7qfr7hbk2
  text: |-
    ### research (2026-10-24)
    EditorKit: `swift package update EditorKit` resolved EK main ab2b8a4cc830b667421fe2950aa99f6118c8fa8d (it contains fd2ce62 and the feature commit ed23895). `swift build` of AVK with no code change is green, so the removed `rowCornerRadius` (palette and completion ResolvedModel, `DefaultCommandPaletteStyle.rowCornerRadius(in:)`) does not affect AVK.

    The plan for the next pass, from the research:
    - Sites:
      - `Elicitation/ElicitationLayout.swift` tab: `Capsule().fill(isSelected ? editorTheme.accent.opacity(selectedTabOpacity) : .clear)`, plus a `Capsule()` stroke and content shape.
      - `Diff/DiffView.swift` fileRow: `.background(isSelected ? .quaternary : .clear, in: EditorSurface.shape(radius: radii.s))`.
      - `Input/EditorKitPromptEditor.swift` PromptCompletionRow: `.background(isSelected ? .selection : .clear)`, with no shape. EK's own CompletionRow uses `.selectionSurface(isSelected, radius: .small)` inset 2pt; match it.
      - SourcesView: the current source is not a selection, so it gets no surface. Nothing to change.
    - Inspector-selected files: they select through `\.attachmentSelect` (`AttachmentSelectAction`: the host binding `HostAttachmentTarget`, with a session id, or `InspectorSelection.attachment`). Add an "is this file selected" read beside it, comparing by `url`, because ImageView selects `Attachment(url:)` while its scope uses a different id. The views are `AttachmentView` (corners: `surfaceCorners`, the chip reports `.medium`, otherwise `.square`), `ImageView` (`.square`), and the ToolCallView `LocationChips` chip (`AttachmentChip.corners` = `.medium`, which keeps its resting `.quaternary` chip fill). ArtifactView wraps an AttachmentView.
    - Allow lists that must shrink: ThemeInjectionTests `accentFiles` drops ElicitationLayout, leaving the InlineCitation chip fill. ContentFillTests drops DiffView from `backgroundInShapeFiles` and ElicitationLayout from `shapeFillFiles` (`eachAllowedFileUsesItsForm` would fail otherwise). Update the ContentFillTests note on the prompt editor's `.background(.selection)`.
    - The new structure suite, modelled on ContentFillTests (SampledCodeForm + FixtureCodeForm, scanning `SystemStructureTests.scanPaths`), has two forms with no allowed files:
      - the system `.selection` shape style;
      - a fill or background whose style is a ternary on a state (`? AnyShapeStyle(`, or `.background(`/`.fill(` with ` ? `), which is how every old selection fill was written.
      The accent and `.tint` are already held by ThemeInjectionTests.
    - Hosted tests: EK's SelectionSurfaceHostedTests is the model. Set `\.appearsActive` to true, because hosted windows are not key. Cover selected, inactive grey, and selected plus focused (AgentItemFocusRingHostedTests.expectFocusRingMask and AttachmentFocusRingHostedTests.focusScope). Check that the text stays `.primary`.
  timestamp: 2026-10-24T20:40:34.871691+00:00
- actor: claude-code
  id: 01m5qt9rcqp7a4qxjpe1a5na6g
  text: |-
    ### blocker (2026-10-24)
    `.selectionSurface(_:radius:)` only takes an `EditorStyle.Radius` step (small, medium, large, window). There is no square step. Several file views that select into the inspector have square focus-ring corners (`AgentSurfaceCorners.square`): ImageView, and AttachmentView while it shows a loaded image, a PDF thumbnail, a text or media preview, or a registered view. With the step form, they cannot meet "same corners as the focus ring".

    I asked the user. The answer was A: stop, and file an EK card for a fixed-corner overload, `selectionSurface(_:cornerRadius:)`, mirroring `scopeFocusRing(cornerRadius:)`. This card stays stuck until that card lands. I filed EditorKit 01M5QT95QZRVZ6CRCGF1PSB3K1 (^1psb3k1, tag cross-repo).

    No AVK source was changed in this pass. When ^1psb3k1 is on EK main, run `swift package update EditorKit`, record the SHA, and implement from the research comment above. Use `.selectionSurface(_:cornerRadius:)` with `AgentSurfaceCorners.radius(in:)` for every site, so each fill and its focus ring read the same corner value.
  timestamp: 2026-10-24T20:40:39.063810+00:00
- actor: claude-code
  id: 01m5qta6dqn5tgkv4rfn7frk9a
  text: |-
    ### implement — stuck
    - evidence: no AVK files changed. EK resolved to main ab2b8a4 (it contains fd2ce62). `swift build` is green with no code change. User answer A (.sah/questions/20261024_203848_408569_question.yaml): file the EK fixed-corner overload, and this card waits. EK card ^1psb3k1 (01M5QT95QZRVZ6CRCGF1PSB3K1) is filed.
    - next: once ^1psb3k1 is on EK main, update EditorKit, record the SHA, and implement from the research comment.
  timestamp: 2026-10-24T20:40:53.431627+00:00
- actor: claude-code
  id: 01m5qtb52j634yahbakv9mptk5
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — `.selectionSurface` takes only a radius step and has no square step, so square file surfaces (ImageView, AttachmentView previews) can't match their focus ring. With the user's answer A, the agent filed EK ^1psb3k1 (01M5QT95QZRVZ6CRCGF1PSB3K1) for `selectionSurface(_:cornerRadius:)`. EK now resolves at ab2b8a4 and swift build is green. The plan for the next pass is in a comment.
    - test/commit/review: not run (no source change)
    - next: resume /implement when EK ^1psb3k1 is on EK main
  timestamp: 2026-10-24T20:41:24.818302+00:00
- actor: claude-code
  id: 01m5qzgfhh30kevtk8qbw1623c
  text: |-
    ### unblocked (2026-10-24)
    EditorKit 01M5QT95QZRVZ6CRCGF1PSB3K1 (^1psb3k1) is on EK main e79b163; the feature commit is cd2c88b. It is additive.
    - New API: `.selectionSurface(_ isSelected: Bool, cornerRadius: CGFloat)`, mirroring `scopeFocusRing(cornerRadius:)`. `cornerRadius: 0` gives square corners.
    - The step form resolves to the same private modifier, so the fill, the inactive grey and `.isSelected` are identical.
    Next: run `swift package update EditorKit` to e79b163 or later, then resume /implement with the recorded plan.
  timestamp: 2026-10-24T22:11:42.257245+00:00
- actor: claude-code
  id: 01m5r01q75r490r6e0qqztpbzw
  text: |-
    ### picked up after unblock (2026-10-24)
    `swift package update EditorKit` resolved EK main e79b1639a5b23eee83de2d78f26000d75f7d3746 (contains ^1psb3k1 feature commit cd2c88b). Implementing from the research comment with `.selectionSurface(_:cornerRadius:)`/`(_:radius:)`.
  timestamp: 2026-10-24T22:21:07.173315+00:00
- actor: claude-code
  id: 01m5r22x6nk10g1agsnb6ht9gd
  text: |-
    ### implementation (2026-10-24)
    EK resolved at e79b1639a5b23eee83de2d78f26000d75f7d3746.

    What landed:
    - `AttachmentSelectAction.isSelected(_:)` and `HostAttachmentTarget.isSelected(_:)` (AttachmentInspectorMode.swift) compare by URL. In host mode the selection also has to belong to this thread view's session id. One binding serves several thread views, so a file picked in another thread is not this thread's selection.
    - `SelectOnTap` is replaced by `InspectorSelectable(file:corners:action:)` (AttachmentView.swift): one modifier for "select into the inspector and show it selected". It draws `.selectionSurface(_:cornerRadius: corners.radius(in:))`, the same value its scope ring uses. It takes the cornerRadius form, not a branch on the step. AttachmentView's corners change when a preview falls back to the chip, and a `_ConditionalContent` branch would reset the view's state. Used by AttachmentView (surfaceCorners), ImageView (new `ImageView.corners = .square`) and the ToolCallView LocationChips (`AttachmentChip.corners`, still on its resting `.quaternary` chip fill).
    - DiffView file rows: `.selectionSurface(isSelected, radius: Self.fileRowRadius)` (.small). The content shape for `[.interaction, .focusEffect]` is now `EditorSurface.shape` of that radius, so the button's focus ring follows the same corners.
    - ElicitationLayout tabs: the Capsule accent fill, `selectedTabOpacity` and the Capsule stroke are gone. The tab is now `.selectionSurface(isSelected, radius: Self.tabRadius)` (.medium, the kit chip corners) plus `.inlineEdge(radius:)` for the separator edge. That edge is transparent by default and shows a fill only under a host `inlineFill`. The focus-effect content shape is in the same shape. The tab is now a rounded rect, not a capsule, because a capsule is not an `AgentSurfaceCorners` value.
    - PromptCompletionRow: `.selectionSurface(isSelected, radius: .small)` inset 2pt horizontally, matching EK's CompletionRow.
    - Allow-lists: DiffView left ContentFillTests `backgroundInShapeFiles` and ElicitationLayout left `shapeFillFiles`. ElicitationLayout left ThemeInjectionTests `accentFiles`, so InlineCitation's chip fill is the only accent use left.
    - New structure suite `SelectionFillTests` with fixtures `Fixtures/SelectionFill/{Violating,Clean}`. It has two forms and no allowed files: `systemSelectionStyle` (implicit `.selection` / `SelectionShapeStyle`) and `conditionalFill` (`.background(`/`.fill(` with a top-level ` ? `). Accent and tint stay with ThemeInjectionTests.
    - Hosted tests in `SelectionSurfaceSitesHostedTests`: completion row fill when active and when inactive, and none when unselected. Image fill when active and inactive, none when unselected, and selected+focused (fill plus a square ring mask). The AttachmentView chip, active and inactive, matches the unselected view on an outer shared surface pixel for pixel, so its text keeps `.primary`. Tool call location selected vs unselected. Unit tests in `AttachmentSelectActionTests`.

    Discoveries:
    - TestImage's PNG is fully clear, so the fill shows through the ImageView, and the image pixel test reads the expected fill at the center.
    - ArtifactView: the panel scope owns the focus ring (.medium) and the inner AttachmentView's scope is skipped. The selection fill is drawn by the inner AttachmentView with its own preview corners (square for a text preview). The plan treated ArtifactView through AttachmentView, and I followed it. Review may want the artifact's fill on the panel instead.
    - `missing creator for mutated node … mlx-swift_Cmlx.bundle` is a SwiftPM build-system warning about a dependency product. It is not repo code and was already there.
  timestamp: 2026-10-24T22:56:43.221823+00:00
- actor: claude-code
  id: 01m5r2374r37chpbwjdhfnf6bq
  text: |-
    ### implement — changed
    - evidence: `swift test` gave 1828 tests in 225 suites passed, with the 7 expected known issues. Re-recorded snapshots, each diff confined to the tab-row band: HostedSnapshotTests elicitation-form-{light,dark,reduce-transparency,increase-contrast}.png and request-deck-bar-{light,dark,reduce-transparency,increase-contrast}.png. Regenerated the xcodeproj. The demo `xcodebuild … build` gave BUILD SUCCEEDED with 0 repo warnings; the only warning line is Xcode's appintentsmetadataprocessor. `Scripts/test-examples.sh AgentViewKitDemo` ran under the shared lock: TEST SUCCEEDED, 10 UI tests, 0 failures, and "The example gate passed." Files: Sources/AgentViewKit/{Attachments/AttachmentInspectorMode.swift, Attachments/AttachmentView.swift, Content/Blocks/ImageView.swift, Diff/DiffView.swift, Elicitation/ElicitationLayout.swift, Input/EditorKitPromptEditor.swift, Items/ToolCallView.swift}; Tests/PackageStructureTests/{SelectionFillTests.swift (new), Fixtures/SelectionFill/ (new), ContentFillTests.swift, ThemeInjectionTests.swift}; Tests/AgentViewKitTests/{Attachments/AttachmentSelectActionTests.swift (new), Theme/SelectionSurfaceSitesHostedTests.swift (new)}; 8 snapshot PNGs. EK pinned at e79b163.
    - next: /review. Open question for review: should ArtifactView draw the selection fill on its panel, which owns the focus ring, instead of on the inner preview?
  timestamp: 2026-10-24T22:56:53.400829+00:00
- actor: claude-code
  id: 01m5r2r9g8w47vc2b7gb1pcjvx
  text: |-
    ### test — green
    - evidence: `swift test` — 1828 tests in 225 suites passed, 7 known issues (expected), 0 failures. Regenerated AgentViewKitDemo.xcodeproj; `xcodebuild ... build` — BUILD SUCCEEDED, 0 repo warnings (only the toolchain line "appintentsmetadataprocessor: Metadata extraction skipped, no AppIntents.framework dependency found"). `Scripts/test-examples.sh AgentViewKitDemo` under the shared UI-test lock — 10 UI tests, 0 failures, "The example gate passed." No draft files left; nothing committed; no source changes.
    - next: review
  timestamp: 2026-10-24T23:08:23.944631+00:00
- actor: claude-code
  id: 01m5r2xjda3ck7tt1tn0vebnzy
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (41ea39e), batched, complete (attempted 14, failed 0, skipped 0; 8 PNG snapshots not text) — 2 findings, 2 confirmed, 0 refuted — Sources/AgentViewKit/Diff/DiffView.swift:267, Sources/AgentViewKit/Elicitation/ElicitationLayout.swift:166
    - next: implement the shared selection-row modifier (selectionSurface + matching contentShape from one radius) and call it from DiffView.fileRow and ElicitationLayout tab; re-run /finish
  timestamp: 2026-10-24T23:11:16.906414+00:00
- actor: claude-code
  id: 01m5r2y3ds43j9q8c2fd6579gw
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — every selection uses .selectionSurface (EK e79b163). InspectorSelectable added; SelectionFillTests added; hosted tests added; 8 PNGs re-recorded.
    - test: green — swift test 1828/225 (7 known issues), demo build 0 repo warnings, test-examples.sh 10/10 under lock
    - commit: 9a3482a (chore kanban), 41ea39e (code, HEAD)
    - review: findings — DiffView.swift:267 and ElicitationLayout.swift:166 (duplication: the selectionSurface + contentShape pair)
  timestamp: 2026-10-24T23:11:34.329708+00:00
- actor: claude-code
  id: 01m5r3d09kt0fr731ggpdt5kkx
  text: |-
    ### review findings fixed (2026-10-24)
    Both duplication findings had one cause: each site paired `.selectionSurface` with its own hit/focus `.contentShape` and could let the two drift apart.
    - New kit modifier in the theme layer: `Sources/AgentViewKit/Theme/SelectableSurface.swift`. It has `SelectableSurface` (ViewModifier) plus `.selectableSurface(_:radius:)` (radius step) and `.selectableSurface(_:corners:)` (`AgentSurfaceCorners`). It reads one radius (`corners.radius(in: editorStyle)`) and applies both `.selectionSurface(_:cornerRadius:)` and `.contentShape([.interaction, .focusEffect], EditorSurface.shape(radius:))` from it. EK's step form resolves to the same private modifier as the cornerRadius form, so nothing draws differently.
    - Call sites: `DiffView.fileRow` and `ElicitationLayout.tab` now call `.selectableSurface(isSelected, radius:)`; `.inlineEdge` stays at the tab call site.
    - Other `.selectionSurface` sites I checked:
      - `InspectorSelectable` had the same pairing, but with a different shape (`.selectionSurface(cornerRadius:)` + `.contentShape(.rect)`). It now uses `.selectableSurface(_:corners:)`, so a tap lands in the surface shape. Its now-unused `editorStyle` environment value is removed.
      - `PromptCompletionRow` had no content shape. I moved it onto the shared modifier anyway, so that every selection uses one code path. Hit testing doesn't change: EK's `CompletionSuggestionsList` wraps each row in `.contentShape(Rectangle()).onTapGesture`, and the outer shape wins.
    - Guard (written as a failing test first): two new SelectionFillTests. `onlyTheSharedSelectableSurfaceAppliesTheSelectionSurface(path:)` checks that `.selectionSurface(` appears in no file of the kit, the demo support or the demo except SelectableSurface.swift. `theSharedSelectableSurfaceAppliesTheSelectionSurface` checks that the shared file applies it. Both failed before the change and pass after it.
    - No EditorKit API change.
  timestamp: 2026-10-24T23:19:42.643171+00:00
- actor: claude-code
  id: 01m5r3d606mdme84y00cf646ae
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/Theme/SelectableSurface.swift (new), Sources/AgentViewKit/Diff/DiffView.swift, Sources/AgentViewKit/Elicitation/ElicitationLayout.swift, Sources/AgentViewKit/Input/EditorKitPromptEditor.swift, Sources/AgentViewKit/Attachments/AttachmentView.swift, Tests/PackageStructureTests/SelectionFillTests.swift. `swift test`: 1828 tests in 225 suites passed with the 7 known issues, and the PackageStructureTests run passed 250/33. No snapshot changed, none re-recorded. Regenerated the xcodeproj (generate_xcodeproj.rb). Demo `xcodebuild … build`: BUILD SUCCEEDED, 0 repo warnings (the only warning is the toolchain appintentsmetadataprocessor line). Both review findings are flipped to [x]. Nothing committed.
    - next: /review
  timestamp: 2026-10-24T23:19:48.486785+00:00
- actor: claude-code
  id: 01m5r3s16wp14hz6t8pv5dcrw7
  text: |-
    ### test — green
    - evidence: `swift test` — 1828 tests in 225 suites passed, 7 known issues (expected), 0 failures. xcodeproj regenerated; `xcodebuild -project Examples/AgentViewKitDemo/AgentViewKitDemo.xcodeproj -scheme AgentViewKitDemo ... build` — BUILD SUCCEEDED, 0 repo warnings (only the Xcode tool note "appintentsmetadataprocessor: Metadata extraction skipped, no AppIntents.framework dependency found"). `Scripts/test-examples.sh AgentViewKitDemo` under the UI-test lock — 10 UI tests, 0 failures, PASS AgentViewKitDemo; no demo process left running, no new files in git status.
    - next: review
  timestamp: 2026-10-24T23:26:16.796472+00:00
position_column: doing
position_ordinal: '8380'
title: Draw every selection through the shared EditorStyle selection surface (translucent accent, one code path)
---
The user's rule (2026-10-24): one set of code for selection, smart about transparency, so the selection effects are consistent everywhere.

Three states, each drawn one way:
- Focused (where the keyboard is): the system focus ring that the EditorKit scope beacon draws (`agentItemScope` → `.scopeFocusRing`). An outline only. Unchanged.
- Selected (what is chosen): the accent colour at a fixed low opacity, filled in the item's surface shape, behind the content. Text stays `.primary`, with no white-text swap. Because it's translucent, it blends over clear, glass, a tint or a host fill.
- Selected while the window is not key (`appearsActive == false`): `.primary` at a low opacity, the grey macOS uses for an inactive window.
Selected plus focused is the fill plus the ring.

Depends on an EditorKit card, filed with editorkit-28: a `selectionSurface(_ isSelected:, radius:)` modifier and its two opacity tokens in EditorStyle, shared with KanbanViewKit and EditorKit's own lists. Do not start until that card is on EditorKit main. Record the EditorKit SHA in a comment when you start.

Today's separate drawings to replace:
- `Elicitation/ElicitationLayout.swift` field tabs: a Capsule filled with accent at selectedTabOpacity.
- `Diff/DiffView.swift` file rows: a `.quaternary` fill.
- `Input/EditorKitPromptEditor.swift` completion rows: the system `.selection` fill.
- `Citations/SourcesView.swift` highlighted source: check how it draws.
- Attachments and files that select into the host inspector show no selected state today (see ^fqr901r).

- [x] Each selection site above uses the shared modifier, with the same corners as its focus ring (`AgentSurfaceCorners`).
- [x] Attachment and file views show the selected state when the host inspector selection is that file.
- [x] A structure test forbids accent, `.selection`, `.quaternary` or tint fills used as a selection outside the shared modifier.
- [x] Hosted tests: selected, inactive-window selected, and selected plus focused each draw the expected layer; text stays `.primary`.
- [x] Snapshots re-recorded for the changed sites, each one listed.
- [x] No compatibility shims; transparent backgrounds by default. #avk-8 #cross-repo

## Review Findings (2026-10-24 18:09)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 14 file(s) reviewed, 8 not reviewed.

> 8 file(s) not reviewed — the file holds no text to review:
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/elicitation-form-dark.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/elicitation-form-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/elicitation-form-light.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/elicitation-form-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/request-deck-bar-dark.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/request-deck-bar-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/request-deck-bar-light.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/request-deck-bar-reduce-transparency.png` — not UTF-8 text, so there is nothing to review

- [x] `Sources/AgentViewKit/Diff/DiffView.swift:267` `duplication/duplication` — The file row repeats the selection-surface and hit-shape modifier pair from the tab chip in ElicitationLayout. Both pair a `.selectionSurface(isSelected, radius:)` with a `.contentShape([.interaction, .focusEffect], EditorSurface.shape(radius: editorStyle.radii[...]))` built from the same radius step. The two copies must keep the hit shape equal to the painted surface, and they can drift apart if one is edited. Extract a shared modifier, for example `SelectionRow(isSelected:radius:)` with a `.selectableRowSurface(_:radius:)` extension in EditorKit or the kit's theme layer. It applies `.selectionSurface` and the matching `.contentShape` from one radius value. Call it from `fileRow` and `tab`, passing the radius constant that differs.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationLayout.swift:166` `duplication/duplication` — The tab chip repeats the selection-surface and hit-shape pairing used by the diff file row. The hit shape of the selected tab must match its selection surface, and two copies of that pairing can drift apart. Use the same shared selection-row modifier proposed for DiffView.fileRow, so that both sites take one radius value and derive the selection surface and the hit shape from it. Keep `.inlineEdge` at this call site, since only the tab chip uses it.
