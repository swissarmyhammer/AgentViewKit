---
assignees:
- claude-code
position_column: done
position_ordinal: ffffffe980
title: 'AVK-15.5: Session messages show the sender kind and the session titles'
---
D199 (f). Brief item 5.

Now `SessionMessageView` (Items/SessionMessageView.swift:14-58) shows "From <id> to <id>" (:37-42) with raw ids. The inspector rows "From Session" and "To Session" (Inspection/TranscriptEntries+Inspectable.swift:220-233) show raw ids too.

Do:
- Read the sender of `_meta.sah.message` (the FoundationModelsACPClient accessor `SessionMessageEntry.sahMessage`, or the raw JSONValue of `meta` when the accessor is not there).
- Show "From the user, in <title>" for the kind `user`, and "From <title>" for the kind `session`.
- The title comes from the `_meta`, else from the host (`.sessionTitles { id -> String? }`), else the raw id.
- The inspector rows use the same titles.

Depends on ACPClient (acpc-brief-at-sessions.md) for the typed accessor; optional.

Tests (TDD, unit): each sender kind gives its text; the title order is meta, host, id; the inspector rows use the titles. Update the session-message snapshot fixture (compile only).

#avk-15