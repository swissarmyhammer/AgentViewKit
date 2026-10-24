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

- [ ] Each selection site above uses the shared modifier, with the same corners as its focus ring (`AgentSurfaceCorners`).
- [ ] Attachment and file views show the selected state when the host inspector selection is that file.
- [ ] A structure test forbids accent, `.selection`, `.quaternary` or tint fills used as a selection outside the shared modifier.
- [ ] Hosted tests: selected, inactive-window selected, and selected plus focused each draw the expected layer; text stays `.primary`.
- [ ] Snapshots re-recorded for the changed sites, each one listed.
- [ ] No compatibility shims; transparent backgrounds by default. #avk-8 #cross-repo #blocked-upstream