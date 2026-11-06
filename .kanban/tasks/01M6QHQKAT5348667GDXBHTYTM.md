---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: Inspector of several files lists them and acts on every one
---
Found while doing ^zsr2pbf. The `AttachmentInspector` of several files folds into one EK form that shows only the header (title and count) and a Preview row reading "Mixed". It never names the files, and it shows no action row, because the action row is the attachment scope of one file (`.agentAttachmentScope(soleAttachment)`).

User decision (2026-11-06): the inspector of several files lists them, and its actions act on every file.

- Files row: an EK paths row (Field over `[URL]`, as Working Directory / Locations use) listing every file of the inspector as chips, in selection order. A chip opens its file (`.opening { … }`, through the same open path as the Open command / `AttachmentFileService`). Show the row only for several files (a single file keeps today's form).
- Action row: Open, Reveal in Finder, Share, Save and Quick Look show for several files too, and each runs its `AgentAttachmentVerb` command on every file in the inspector's order, with availability over the whole set. Use a scope whose context gives the files as its selection, as `AgentAttachmentTarget.contributeSelection(to:)` does — no AVK-only button styling, EK buttons only.
- Display text from the catalog / FormatStyles only.

- [ ] Files row of chips for several files; a chip opens its file
- [ ] Action row for several files; each verb runs on every file, in inspector order, availability over the set
- [ ] Docs (AttachmentInspector doc comment, DocC) say what several files show
- [ ] Hosted test through accessibility: fold several files, read the chips (`InspectorDriver.pathChips(in:)`), open one (`openPath(at:in:)`) and the recording hook gets that file; press each action and the recording hook gets every file