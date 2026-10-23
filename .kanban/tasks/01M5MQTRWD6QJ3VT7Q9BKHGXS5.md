---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5nctzgmctkrzm7hzzp86g7k
  text: |-
    Picked up; research notes.
    - `AttachmentInspector.body` is a `VStack(spacing: theme.spacing.m)` + `.padding(theme.spacing.m)`; `QuickLookPreview` uses `maxHeight: .infinity`, which a scrolling Form row cannot honor, so the preview needs a fixed height in the form.
    - `AttachmentActions` is shared with `ArtifactView`; it stays unchanged (identifiers come from `AgentAttachmentVerb.identifier(prefix:)`).
    - Existing grouped forms (`ToolToggles` .list, `ConfigOptionsView` .form) do NOT hide the scroll content background; this card hides it (user transparency rule) with `.scrollContentBackground(.hidden)`. No structure suite forbids that modifier (SystemStructureTests forbids containerBackground/materials; ContentFillTests forbids background-in-shape and shape fills).
    - Transparency can be proven with the pixel probe `ContentEdgeHostedProbe.pixels(of:backdrop:...)` + `GlassRenderProbeTests.backdrop`.
    - There are NO AttachmentInspector snapshots in Tests/AgentViewKitTests/Snapshots/__Snapshots__ (Glass + Hosted suites only cover thread/composer/bars/cards/code/terminal/elicitation). So the "re-record AttachmentInspector snapshots" item has nothing to re-record; the user's constraint is to re-record only inspector snapshots that change.
    - The safe-area doc comment on `AttachmentInspectorModifier` is about the main content's padding, not the inspector content; the Form does not change it.
  timestamp: 2026-10-23T22:06:54.484077+00:00
- actor: claude-code
  id: 01m5nd05yjwt742akq3041pej8
  text: |-
    Probe (throwaway hosted test, deleted) of a `.formStyle(.grouped)` Form at 320 pt wide on macOS 27:
    - The form is a `HostingScrollView`; its a11y element is `AXScrollArea` and carries the Form's identifier.
    - Section rows sit at a 20 pt form margin; row content has a further 10 pt inset (content x 30..290 of 320). A `maxWidth: .infinity` view in a row spans exactly the row content width.
    - WITHOUT `.scrollContentBackground(.hidden)` the system inserts `_NSScrollViewContentBackgroundView` + `NSVisualEffectView` and the host backdrop shows nowhere (margins included). WITH it, `drawsBackground == false` on the scroll and clip views, and the backdrop shows in the margins; the rows keep the grouped-row look. So the transparency rule and the grouped look do not conflict.
  timestamp: 2026-10-23T22:09:44.914910+00:00
- actor: claude-code
  id: 01m5nde43jxz7qnww849saag58
  text: |-
    Implementation landed (not committed).
    - `AttachmentInspector.body` is now `Form { Section { name, actions } Section { preview } }`, `.formStyle(.grouped)`, `.scrollContentBackground(.hidden)`, `.accessibilityIdentifier(formIdentifier)`, then `.agentAttachmentScope`. The VStack, its `theme.spacing.m` spacing and padding, and the now-unused `agentTheme` environment read are gone.
    - The preview gets `maxWidth: .infinity` and a fixed `previewHeight` (240 pt), because a scrolling form row has no height for `maxHeight: .infinity` to fill.
    - New public `AttachmentInspector.formIdentifier = "inspector-form"`. `nameIdentifier`, `identifierPrefix` and every action identifier are unchanged.
    - TDD: new suite `AttachmentInspectorFormHostedTests` (form is an AXScrollArea holding the name and actions; QLPreviewView leading edge == name leading edge and its trailing inset == its leading inset; host backdrop shows in the form margin with Reduce Transparency off and on). Red 1: the form and inset tests failed with only the identifier constant added. Red 2: the backdrop test failed once the grouped Form was in but the background was not yet hidden. Green after `.scrollContentBackground(.hidden)`.
    - Safe-area doc comment on `AttachmentInspectorModifier`: it is still accurate. It covers the safe-area padding of the MAIN content beside the inspector, and the Form is inspector content, so it is unchanged.
    - Snapshots: there are NO AttachmentInspector snapshots, so none were re-recorded and none changed. Follow-up card ^v7n1ycx asks whether to add some (the live QLPreviewView may not be pixel-deterministic).
    - Not done by this step: telling testudoapp-2c the card id + SHA, which needs the commit.
  timestamp: 2026-10-23T22:17:21.778835+00:00
- actor: claude-code
  id: 01m5nde7rs4vr76d59cyyn47j9
  text: |-
    ### implement — changed
    - evidence: 2 files — Sources/AgentViewKit/Attachments/AttachmentInspector.swift, Tests/AgentViewKitTests/Attachments/AttachmentInspectorFormHostedTests.swift (new). `swift test`: 1744 tests in 215 suites passed (3 known issues, all pre-existing `withKnownIssue` helper self-tests), plus 227 tests in 30 suites passed. The one warning is SwiftPM's "missing creator for mutated node … mlx-swift_Cmlx.bundle", which comes from the build system and appears on every build. `xcodebuild -scheme AgentViewKitDemo build`: BUILD SUCCEEDED. No UI run, so the UI-test lock was not taken. EditorKit is still at 69d04fc. No snapshot changed: no AttachmentInspector snapshot exists (follow-up ^v7n1ycx).
    - next: /review
  timestamp: 2026-10-23T22:17:25.529423+00:00
position_column: doing
position_ordinal: '8380'
title: 'AttachmentInspector: system grouped Form layout (Xcode / Icon Composer inspector look)'
---
Requested by testudoapp-2c (2026-10-23) for Testudo card ^5pzcse2. The user said: "the inspector padding looks off to me, like inconsistent and too 'touching' the surrounding edge. the inspectors in xcode and icon composer look nice, use them for inspiration".

Today `AttachmentInspector` (Sources/AgentViewKit/Attachments/AttachmentInspector.swift:190, :200) uses a `VStack(spacing: theme.spacing.m)` padded with `theme.spacing.m` (12 pt). Testudo's PlaceholderInspector uses `.padding()`, and its pane header uses 4 pt, so the inspector column has three different insets. Testudo is moving PlaceholderInspector to a grouped Form and aligning its header to the same content edge.

## What to do
- [x] The body becomes `Form { Section { name row, actions } … }` with `.formStyle(.grouped)`. It uses the system margins and has no hand-tuned padding: remove the `theme.spacing.m` padding and stack spacing.
- [x] The QuickLook preview sits inside the form, with the same leading and trailing inset as the section content.
- [x] Keep `nameIdentifier` and the action accessibility identifiers unchanged, so the Testudo UI tests still pass.
- [x] One view, no host glue: hosts change nothing.
- [x] Check the safe-area padding behavior described in the doc comment at AttachmentInspector.swift:65–88 still holds, or update that comment.

## Tests
- Hosted test: the inspector's content is a grouped Form; the preview's leading and trailing edges match the section rows.
- The identifiers resolve: `nameIdentifier` and each action.
- Re-record the AttachmentInspector snapshots in Dark and Light, and list them by name.
- Full `swift test` green; the demo builds.

When it's done, send testudoapp-2c the card id and the SHA. #avk-8 #testudo-request