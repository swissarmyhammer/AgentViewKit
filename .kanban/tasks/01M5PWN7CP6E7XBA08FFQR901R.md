---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5qnt52xpkzah266xysrymhw
  text: |-
    Research (implement):
    - Selection path: `AttachmentView` / `ImageView` call `@Environment(\.attachmentSelect)` (AttachmentSelectAction: host binding in host mode, else InspectorSelection) through `SelectOnTap`, and `.agentAttachmentScope(_:focusRingCorners:)` gives the context menu (Open, Reveal, Share, Save, Quick Look via AgentAttachmentVerb).
    - `Docs/decisions/attachment-types.md` already records that ACP blob resources and resource links use the AttachmentView default renderers (pdf thumbnail, text, movie, chip...). So the blob resource and the `file:` resource link go through `AttachmentView` itself.
    - Blob: AttachmentView previews read the file, so the blob is written to its ContentBlockFile first (as AudioPlayerView does), then shown in AttachmentView; a failed write keeps the plain chip.
    - `file:` resource link: ContentBlockView routes it to AttachmentView(Attachment(url:)) with the link name/size/MIME type; other links stay LinkView.
    - Locations (decision): AttachmentView would render the whole file, so each location chip keeps its compact label and uses the same selection path inline (SelectOnTap + attachmentSelect + agentAttachmentScope), as ImageView does. Every ACP location is an AbsolutePath, so every location selects its file. The chip surface changes from Capsule to the medium rounded radius so the scope focus ring matches the surface (AgentSurfaceCorners has no capsule).
    - Demo: DemoGallery has scripted tool calls (permission "Edit Greeting.swift") with no locations; adding a location there gives the demo a file chip.
    - No selected-state visual is added (^dn1m56r owns `.selectionSurface`).
  timestamp: 2026-10-24T19:22:13.469147+00:00
- actor: claude-code
  id: 01m5qpsvm8475s2yw2pd5gg5t3
  text: |-
    Implementation landed (not committed):
    - Blob `.resource`: new `BlobResourceView` writes the bytes to their `ContentBlockFile` block file, then shows that file in `AttachmentView` (spinner while writing, plain `AttachmentChip` on a failed write). Tests wait on the new `resourceFileReport` ObservationReport, the same pattern as `audioFileReport`. New helper `ContentBlockFile.attachment(of:named:type:)`.
    - `.resourceLink`: `ContentBlockView` routes a `file:` URI to `AttachmentView(link.fileAttachment)` (the link size/MIME type fill in when the file is not on this Mac); every other URI stays a `LinkView`.
    - Locations (decision, also in Docs/decisions/attachment-types.md "Files in content"): every ACP location is an AbsolutePath, so every chip selects its file. The chip keeps its compact label (AttachmentView would render the whole file) and uses the same path as ImageView: `SelectOnTap` + `attachmentSelect` + `agentAttachmentScope`. The chip surface changed from Capsule to the `AttachmentChip.corners` rounded rect so the scope focus ring matches the surface (AgentSurfaceCorners has no capsule). New public `ToolCallView.locationIdentifier(for:index:)`.
    - No selected-state visual added; ^dn1m56r still owns `.selectionSurface`.
    - Demo: `DemoGallery.permission`'s pending "Edit Greeting.swift" call now carries a location (`DemoGallery.greetingPath`, line 2), so the Gallery shows a file chip that selects into the inspector.
    - Existing test `aWireBinaryResourceShowsAChipWithItsName` now waits for the blob write (the chip appears after the write).
    - Follow-up: ^z2qejh5 (ImageView still hand-builds the same block-file attachment; the duplication rule keeps that edit out of this card).
    - No snapshot changed: the suite passed with no re-record.
  timestamp: 2026-10-24T19:39:32.360206+00:00
- actor: claude-code
  id: 01m5qpszqkztj5kw3fe2n57kgp
  text: |-
    ### implement — changed
    - evidence: `swift test` 1800 tests passed with 7 known issues (+ 239 PackageStructure tests passed); snapshots unchanged, none re-recorded; xcodeproj regenerated and `xcodebuild ... AgentViewKitDemo build` BUILD SUCCEEDED, 0 repo warnings (the one warning is appintentsmetadataprocessor tool noise); `Scripts/test-examples.sh AgentViewKitDemo` passed under the UI-test lock (10 UI tests, 0 failures). Files: Sources/AgentViewKit/Content/Blocks/BlobResourceView.swift (new), Sources/AgentViewKit/Content/Blocks/ContentBlockFile.swift, Sources/AgentViewKit/Content/Blocks/ResourceBlockView.swift, Sources/AgentViewKit/Content/ContentBlockView.swift, Sources/AgentViewKit/Items/ToolCallView.swift, Sources/DemoSupport/DemoGallery.swift, Docs/decisions/attachment-types.md, Tests/AgentViewKitTests/Content/ContentFileSelectionHostedTests.swift (new), Tests/AgentViewKitTests/Content/WireContentBlockViewHostedTests.swift, Tests/AgentViewKitTests/ACP/DemoGalleryTests.swift
    - next: /review
  timestamp: 2026-10-24T19:39:36.563966+00:00
- actor: claude-code
  id: 01m5qq684ywzhfbg61qh09149m
  text: |-
    ### test — green
    - evidence: `swift test` — 1800 tests in 219 suites passed, 7 known issues (expected); xcodeproj regenerated, `xcodebuild ... AgentViewKitDemo build` — BUILD SUCCEEDED, 0 warnings from repo sources (the only "warning:" line is Xcode's appintentsmetadataprocessor "Metadata extraction skipped, no AppIntents.framework dependency found"); `Scripts/test-examples.sh AgentViewKitDemo` — 10 UI tests, 0 failures, "The example gate passed."
    - next: review
  timestamp: 2026-10-24T19:46:18.398031+00:00
position_column: doing
position_ordinal: '8380'
title: 'Tool-call and message files select into the host inspector (resource blobs, file: resource links, locations)'
---
Requested by testudoapp-2c on 2026-10-24 (Testudo ^5wq4zfq waits on this).

At AVK 6493d6f a file in a tool-call result cannot be inspected. ContentBlockView renders:
- `.resourceLink` with a `file:` URL as a `LinkView` card; a click opens the file in its default app.
- `.resource` with a blob through `ResourceBlockView.blobChip`, a plain `AttachmentChip` that selects nothing on click.
- tool-call `locations` as static `LocationChips` labels.

Only `AttachmentView` and `ImageView` select into the host's File inspector, and in the transcript `AttachmentView` is reachable only through `ArtifactView`.

Goal: a click on a file in tool-call content (and in message content where it applies) selects it into the host inspector, the same way a message attachment does. Use `AttachmentView` or the same selection path. Keep the kit rule: one wrapping view or one modifier, no host glue.

- [x] A blob `.resource` renders through the attachment selection path; a click selects it into the inspector.
- [x] A `.resourceLink` whose URI is a `file:` URL renders through the attachment selection path. A non-file link (http and so on) stays a `LinkView`.
- [x] Tool-call `locations` that name a file select that file the same way (a decision for this card; record it).
- [x] The existing context menu stays: Open, Reveal, Share, Save, Quick Look.
- [x] Hosted tests: a click on each of these selects the file (the inspector selection is set), and the context menu keeps its items.
- [x] The demo's scripted tool call shows a file chip that selects into the inspector, if the demo has one.

When done, send testudoapp-2c the card id and the SHA after the user pushes. #avk-8 #cross-repo