---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5yvc3j6aknrmz8sggewvzew
  text: |-
    ### Waits on EditorKit ^1b4z2mv
    EditorKit filed the move as ^1b4z2mv. It is queued after EditorKit ^1gab15j and ahead of ^bcsmt4w (the tile tokens). editorkit-a9 merges each helper with its EditorKit equivalent, and will send the main SHA plus a map from each old AVK name to its new EditorTestSupport name. Until that arrives, don't change the AVK test-support files listed above. They are the source the move reads.
  timestamp: 2026-10-27T14:14:05.638812+00:00
- actor: claude-code
  id: 01m62an25xyqpwrbteb4e1v307
  text: |-
    2026-10-28, agreed with editorkit-40: the EditorKit card is ^1b4z2mv, and it runs after ^p9rqatc. EditorKit reads AVK's canonical files read-only from local main cc9ee2d, so no push is needed.
    The scope is smaller now. Moving to EditorTestSupport, each merged with its EditorKit equivalent: HostedViewHarness(+TextViews), HostedLayoutExpectations, HostedSerialTrait, NSEvent+KeyEvent, NSView+Descendants, ObservationWait, RunLoopBlockFence, ChangeCounter, ChangeFlag, SnapshotText, SnapshotVariant, SnapshotStore, the data part of RenderedPixels and RenderedPixels+PNG (merged into CapturedImage), and possibly FakePasteboard.
    Not ported (renderer code, deleted under "real capture only", which is ^x7z136m's job): LayerTreeRenderer, VibrantLabelFilters, ScrollPocketProbe, CATransaction+WithoutActions, ViewSnapshot's composited path, and `RenderedPixels.init(rendering:)`. ReviewGallery(+Page) are replaced by EditorReviewGallery (^wprq982).
  timestamp: 2026-10-28T22:38:51.069563+00:00
position_column: todo
position_ordinal: a680
title: 'AVK-8 test support: delete AVK''s copies of the generic test helpers and use EditorKit''s EditorTestSupport (after the EditorKit move)'
---
## Why

User directive (2026-10-27): "move those test helpers into actual editor kit then, don't be dense". Generic test helpers belong in EditorKit's EditorTestSupport, so EditorKit, AVK and KanbanViewKit share one copy. editorkit-a9 has been asked to move them, merging each with any EditorKit helper that already does the same job.

Generic helpers moving to EditorKit (from `Sources/AgentViewKitTestSupport/`):
- ViewSnapshot, LayerTreeRenderer, VibrantLabelFilters, CATransaction+WithoutActions
- RenderedPixels(+PNG), SnapshotStore, SnapshotVariant, SnapshotText
- ReviewGallery, ReviewGalleryPage
- HostedViewHarness(+TextViews), HostedLayoutExpectations, HostedSerialTrait, ScrollPocketProbe
- NSEvent+KeyEvent, NSView+Descendants, ObservationWait, RunLoopBlockFence, ChangeCounter, ChangeFlag
- Possibly FakePasteboard, RecordingAnnouncer, RecordingFocusReporter (EditorKit's call)

These stay in AVK (agent-specific): ScriptedSession, BackgroundRunScript, FakeProcessLauncher, FakeSpeechTranscriber, FakeTerminalAuthRunner, FakeWebAuthSession.

## Depends on

The EditorKit card for the move. Wait for the EditorKit main SHA and the final API names from editorkit-a9.

## What to do

- [ ] `swift package update EditorKit` to the SHA that has the moved helpers.
- [ ] Delete every AVK file that EditorKit now provides, and switch every test and test-support caller to EditorTestSupport. Use EditorKit's names; no typealiases or compatibility shims.
- [ ] AgentViewKitTestSupport keeps only the agent-specific helpers listed above.
- [ ] Add a structure test: a file in AgentViewKitTestSupport that declares a type or function with the same name as one in EditorTestSupport fails it, so the duplication can't return.
- [ ] The review gallery still writes `~/Library/Caches/AgentViewKit/screenshot-check/`, with the same screens, both looks and the contact sheet. The existing `__Snapshots__` show no diffs.
- [ ] The full `swift test` is green with the same known issues.

## Acceptance

- AVK has no copy of a generic test helper; they all come from EditorTestSupport.
- The duplication guard passes, the gallery output is unchanged, and the suite is green. #avk-8 #cross-repo