---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: 'Attachment inspector: one block for each selected file, no Mixed'
---
The user decision (2026-11-09, from editorkit-9f): an inspector never folds several selected items into one block and never shows "Mixed". EditorKit removes the fold: `InspectorView` with several objects shows one full block per object, and `InspectorMultipleSelection`, `.inspectorMultipleSelection(_:)` and the Mixed strings are removed. Wait for the EditorKit sha of that change, then update to it.

## What to do
- `AttachmentInspector([files])` shows one full block for each file, with its own name, action row and preview, as one file shows today.
- The action row of each block acts on its own file only.
- Remove the Files row of several files (`filesIdentifier(of:)`) and the ids that join the file ids with `+`.
- Keep the context menu and the keys of a selection in a thread: they act on every selected file (^zsr2pbf).
- Change the words "folded into one form" in InspectedClientModel.swift, the file comment of TranscriptEntries+Inspectable.swift, AttachmentInspectorMode.swift and README.md.
- Change the tests that expect the fold or "Mixed": AttachmentMultiSelectHostedTests, AttachmentInspectorRowsHostedTests, AttachmentInspectorFilesHostedTests.
- Gallery: remove the `*-mixed-*` images. Record a two-file image with 2 blocks in their place (InspectorGallery.swift, InspectorGalleryFixtures.swift, SnapshotFixtures.swift).
- Add a test that fails before the change: an inspector of two files shows two blocks, and the action row of each block acts on its own file.

## Acceptance
- [ ] The new test passes, and it fails before the change.
- [ ] No code, doc or test of AVK says "Mixed" for an inspector.
- [ ] Unit, integration and screenshot suites pass.