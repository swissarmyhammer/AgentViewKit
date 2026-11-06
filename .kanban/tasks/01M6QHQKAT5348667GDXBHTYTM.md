---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: Inspector of several files shows the attachment actions
---
Found while doing ^zsr2pbf. The attachment commands now act on every selected file from the context menu and the keys of a selected file view. The `AttachmentInspector` of several files still shows no action row, because its action row is the attachment scope of one file (`.agentAttachmentScope(soleAttachment)`). Decide whether the folded inspector shows Open, Reveal in Finder, Share, Save and Quick Look that run on every file of the inspector, and through which scope (a scope whose context gives the files as its selection, as `AgentAttachmentTarget.contributeSelection(to:)` does).

- [ ] Decide with the user whether the folded inspector shows the actions
- [ ] If yes: the action row of a folded inspector runs each verb on every file, in the inspector's order, with availability over the whole set
- [ ] Hosted test through accessibility: fold several files, press each action, the recording hook gets every file