---
assignees:
- claude-code
position_column: todo
position_ordinal: a280
title: 'Tool-call and message files select into the host inspector (resource blobs, file: resource links, locations)'
---
Requested by testudoapp-2c on 2026-10-24 (Testudo ^5wq4zfq waits on this).

At AVK 6493d6f a file in a tool-call result cannot be inspected. ContentBlockView renders:
- `.resourceLink` with a `file:` URL as a `LinkView` card; a click opens the file in its default app.
- `.resource` with a blob through `ResourceBlockView.blobChip`, a plain `AttachmentChip` that selects nothing on click.
- tool-call `locations` as static `LocationChips` labels.

Only `AttachmentView` and `ImageView` select into the host's File inspector, and in the transcript `AttachmentView` is reachable only through `ArtifactView`.

Goal: a click on a file in tool-call content (and in message content where it applies) selects it into the host inspector, the same way a message attachment does. Use `AttachmentView` or the same selection path. Keep the kit rule: one wrapping view or one modifier, no host glue.

- [ ] A blob `.resource` renders through the attachment selection path; a click selects it into the inspector.
- [ ] A `.resourceLink` whose URI is a `file:` URL renders through the attachment selection path. A non-file link (http and so on) stays a `LinkView`.
- [ ] Tool-call `locations` that name a file select that file the same way (a decision for this card; record it).
- [ ] The existing context menu stays: Open, Reveal, Share, Save, Quick Look.
- [ ] Hosted tests: a click on each of these selects the file (the inspector selection is set), and the context menu keeps its items.
- [ ] The demo's scripted tool call shows a file chip that selects into the inspector, if the demo has one.

When done, send testudoapp-2c the card id and the SHA after the user pushes. #avk-8 #cross-repo