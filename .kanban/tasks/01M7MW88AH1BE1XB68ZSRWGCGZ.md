---
assignees:
- claude-code
position_column: done
position_ordinal: ffffffdd80
title: 'D191: the attachment verb Inspect replaces Quick Look'
---
From testudoapp-75 (TestudoApp 732f2b0 has its own File inspector). The attachment verb `.quickLookAttachment` and the `.quickLookPreview` modifier of the attachment scope opened the floating Quick Look panel.

Done: `.inspectAttachment` ("Inspect") replaces it. It runs at the scope, not on the service: it writes the files to the inspector selection (`AttachmentSelectAction.inspect`), that is the host binding of `.agentAttachmentInspector(.host(_:))` or the built-in inspector. It is not available where no inspector gets the selection, such as a block of an inspector. The action row of the inspector shows Open, Reveal, Share and Save only. `.openAttachment` stays. #feature