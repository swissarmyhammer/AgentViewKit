---
assignees:
- claude-code
position_column: todo
position_ordinal: ad80
title: 'Thread header: Agent › Session breadcrumb, and a host context menu path on the header'
---
Requested by testudoapp-2c (2026-10-23). Testudo's user decided to remove Testudo's plain tab-header bar over the chat, so AVK's floating glass `AgentInfoHeader` (the thread top bar, ^1ye0jj6) becomes the ONE header. Testudo then removes `tabHeaderBar` and moves 14 UI-test uses off its `tabHeader` element. Tell testudoapp-2c the API BEFORE pushing, and send the SHA.

1. Breadcrumb "Agent › Session" (user: "this is a great breadcrumb Agent > Session"; follow the HIG and SwiftUI idioms):
- The macOS HIG pattern is the path control: clickable segments with a chevron separator, each able to open a menu. SwiftUI has no breadcrumb view, so inside the ONE glass capsule use plain buttons for the segments, `Image(systemName: "chevron.right")` in `.secondary` between them, and the last segment (the current session) in `.primary`. No glass on the segments (that would be glass on glass), and no second bar.
- The first segment is the agent: what the header shows today. The second segment is a session title the host gives, e.g. an optional `sessionTitle:` on `AgentThreadView(session:connection:)` or a modifier. Testudo passes its tab title (the folder name when the session has no title). With no title, the header shows the agent alone, as today.
- Segment tap and menu actions: PROPOSE in the card before implementing: none for now, host hooks, or menus. Keep it the smallest public API that fits, and leave room for later hooks.
- VoiceOver reads it as ONE header element, "Agent, Session". Keep the `agent-info-header` accessibility identifier on it.
2. A host context menu on the header:
- A host hook so that right-clicking the header shows the EditorKit context menu of a HOST-GIVEN path, rendered with `contextMenuMirror(at:unavailable: .hide)` (^sq1j7ce style). For example, a `headerContextMenuPath: FocusPath?` parameter on AgentThreadView, or ONE modifier. Testudo's case is its `session:<tab id>` scope commands: Show in Finder, Open Tasks in New Window, Stop.
- User rule: kit features are ONE wrapping view or ONE modifier, so Testudo must not add a view of its own for this.
- No path means no context menu, as today.
Not needed: when Testudo's large area shows the Tasks board there is no header at all (user decision).

Tests: hosted tests for the breadcrumb layout (agent alone; agent › session; long titles truncate, with the session segment truncating first; Dark/Light snapshot), the single VoiceOver element and its label, the identifier, and the context menu at the host path (items from that path; unavailable items hidden; no path, no menu). Snapshots re-recorded where the header changes, listed by name. The full `swift test` must be green; the demo builds. #avk-8 #testudo-request