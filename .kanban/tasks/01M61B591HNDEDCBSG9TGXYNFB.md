---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m61dw07gr5zpdr1d8n1bgcrj
  text: |-
    Unblocked: EditorKit ^gfv7042 is on main at 14abdc9.
    - Delete AVK's Announcer, AnnouncementPriority, VoiceOverAnnouncer, FocusReporter, the `\.announcer` and `\.focusReporter` keys, ObservationReport, and the RecordingAnnouncer / RecordingFocusReporter doubles, with no shims. They now live in EditorCommandsUI, and the doubles in EditorTestSupport. ObservationReport is public with `init(report:)`.
    - A host must set `\.announcer` ABOVE `.commandSystem(_:)` for jump mode to announce through it. Check every place AVK and the demo inject it.
    - Breaking: `OverlayAccessibilityNotification.announcement` is removed.
    - EditorKit's scan test forbids posting announcements outside Announcer.swift. Do the same in AVK, or call EditorKit's shared scanner once ^3q7j9nd lands.
    Runs after ^qpbamj2 and the worktree merges.
  timestamp: 2026-10-28T14:15:49.744685+00:00
position_column: todo
position_ordinal: ae80
title: Adopt EditorKit's Announcer and FocusReporter, and delete AVK's copies (after EditorKit ^gfv7042)
---
AVK and KVK each have identical public Announcer, AnnouncementPriority, VoiceOverAnnouncer, FocusReporter and the `\.announcer` / `\.focusReporter` keys. These collide when a host imports both kits. EditorKit ^gfv7042 moves one copy to EditorCommandsUI, next to Accessibility.swift, and puts the recording doubles in EditorTestSupport.

## Work
- [ ] Bump EditorKit to the ^gfv7042 SHA
- [ ] Delete AVK's Announcer, AnnouncementPriority, VoiceOverAnnouncer, FocusReporter and the environment keys. Use EditorKit's at every call site, with no typealias or shim.
- [ ] Delete AgentViewKitTestSupport's RecordingAnnouncer and RecordingFocusReporter, and use EditorTestSupport's
- [ ] Every announcement and focus test still passes
- [ ] `swift test` is green

Blocked on EditorKit ^gfv7042.