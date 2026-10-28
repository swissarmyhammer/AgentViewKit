---
assignees:
- claude-code
position_column: todo
position_ordinal: b380
title: 'SessionStreamBanner: don''t show a stale reload failure after missed updates clear elsewhere and come back'
---
From the wt/banner work (reload-failed phase). The banner keeps a private reload state: idle, reloading or failed. If `hasMissedUpdates` is cleared somewhere other than this banner and later comes back, the old `failed` state is still there, and the banner shows an old failure. KVK's board banner has the same behaviour, so fix both in the same way. Ask the KVK session to do theirs.

## Work
- [ ] Reset the reload state whenever missed updates clear, from any source, and make that state follow the model.
- [ ] A hosted test: fail a reload, clear the missed updates through the model, raise them again, and expect the plain missed-updates message.
- [ ] `swift test` is green.

Order: after the wt/banner merge.