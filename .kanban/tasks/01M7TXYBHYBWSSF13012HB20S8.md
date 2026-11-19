---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7ty0228b6drersrrrzn6j57
  text: 'API approved by testudoapp-9a (2026-11-19): AVK reads `session.isReadOnly`; the change verbs are absent from the registry (no disabled rows); the read verbs stay; a replace keeps the scroll position. Still blocked until foundationmodelsacpclient-1d sends the D208 sha (read-only SessionModel, isReadOnly, replace(with:)).'
  timestamp: 2026-11-19T22:14:22.536021+00:00
position_column: todo
position_ordinal: '80'
title: 'Read-only thread for a shared session: no composer and no change verbs (D208 i)'
---
Brief: /Users/wballard/github/swissarmyhammer/.briefs/share/avk-brief.md and overview.md (testudoapp-9a, D208, TestudoApp commit d803f1a). Read D208 and D110 in TestudoApp/features/decisions.md.

Blocked: this task waits for FoundationModelsACPClient D208 on main (the read-only `SessionModel` from a snapshot, `SessionModel.isReadOnly`, and `replace(with:)`). On 2026-11-19 ACPClient main is af57058, without them. Send the API proposal to testudoapp-9a before the first push (sent 2026-11-19, see the comments).

Do:
- When `SessionModel.isReadOnly` is true, the thread shows no composer, no queue, no elicitation form and no permission buttons.
- The change verbs are not in the registry for a read-only thread: send, stop or cancel, approve and reject of a request, Fork from Here, Mention, Focus Composer, retry, edit, rewind, and the mode and model pickers. Check each verb, button and menu row of the thread.
- The read verbs stay: Copy Message, Copy Thread, Copy Code Block, Export as Markdown…, Find Next Hit, Find Previous Hit, Clear Search Hits and the navigation verbs.
- When the model gets a newer snapshot (`replace(with:)`), the thread keeps its scroll position.
- D110: no glass in the content.

Tests (unit, no window): a read-only model has no composer, the change verbs are not in the registry, the read verbs work, and a replace keeps the scroll anchor.

Push when `swift test` is green, and send the sha to testudoapp-9a.