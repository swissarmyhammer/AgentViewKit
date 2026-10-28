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
- actor: claude-code
  id: 01m61nn3kbvamcknp0a0p8bb55
  text: |-
    ### review — clean
    - evidence: review sha cf88bff..34bb804 — 0 findings, 0 confirmed, 1 refuted; 47 files reviewed, 2 not matched by any validator (Docs/decisions/accessibility.md, comparison.md). EditorKit pin 14abdc9 is the ^gfv7042 commit. Tests on main after merge 30c54c7: 1896 + 285 + 37 + 1 passed, 0 skipped.
    - next: none; card moved to done
  timestamp: 2026-10-28T16:31:52.427548+00:00
position_column: done
position_ordinal: fffff480
title: Adopt EditorKit's Announcer and FocusReporter, and delete AVK's copies (after EditorKit ^gfv7042)
---
AVK and KVK each have identical public Announcer, AnnouncementPriority, VoiceOverAnnouncer, FocusReporter and the `\.announcer` / `\.focusReporter` keys. These collide when a host imports both kits. EditorKit ^gfv7042 moves one copy to EditorCommandsUI, next to Accessibility.swift, and puts the recording doubles in EditorTestSupport.

## Work
- [x] Bump EditorKit to the ^gfv7042 SHA
- [x] Delete AVK's Announcer, AnnouncementPriority, VoiceOverAnnouncer, FocusReporter and the environment keys. Use EditorKit's at every call site, with no typealias or shim.
- [x] Delete AgentViewKitTestSupport's RecordingAnnouncer and RecordingFocusReporter, and use EditorTestSupport's
- [x] Every announcement and focus test still passes
- [x] `swift test` is green

Blocked on EditorKit ^gfv7042.