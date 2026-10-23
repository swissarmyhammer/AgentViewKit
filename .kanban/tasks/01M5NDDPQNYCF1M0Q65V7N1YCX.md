---
assignees:
- claude-code
position_column: todo
position_ordinal: b280
title: 'Snapshots: add AttachmentInspector images in Dark and Light'
---
Found while working ^bkhgxs5. That card asks to "re-record the AttachmentInspector snapshots in Dark and Light", but `Tests/AgentViewKitTests/Snapshots/__Snapshots__` has no AttachmentInspector images: `GlassSnapshotTests` and `HostedSnapshotTests` cover the thread, composer, bars, cards, code block, terminal and elicitation form only. ^bkhgxs5 kept to "re-record only the ones that change", so it recorded none.

## What to do
- [ ] Decide whether the inspector should have snapshot coverage at all. Its preview is a live `QLPreviewView` (an out-of-process QuickLook view), so check whether its pixels are deterministic in `ViewSnapshot` before adding images.
- [ ] If they are: add an `AttachmentInspector` case to `HostedSnapshotTests` over the four `SnapshotVariant`s (or Dark and Light only, as the requester asked), and list each new image by name.

#avk-8