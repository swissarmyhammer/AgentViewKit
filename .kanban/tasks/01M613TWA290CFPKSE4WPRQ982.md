---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m614qeqgrbkbv1ry4x8ntge2
  text: |-
    The user widened this: "EK, AVK, KVK, SVK all need complete gallery as well, using EK themes + style guidelines".
    - Every AVK gallery entry renders under EditorKit's theme system: `.editorTheme(_:)` at the root, with SystemTheme as the default. The AVK snapshot fixtures already do this; check it holds for the discovered snapshots' page too. The views follow ../EditorKit/style.md.
    - EditorKit ^p9rqatc (built on ^1b4z2mv) adds the generic helper to EditorTestSupport, with discovery of every reference PNG and the missing-PNG check. When it lands, AVK switches to it and deletes AVK's ReviewGallery.swift and ReviewGalleryPage.swift. If it lands before this card starts, do this card in EditorKit's helper and don't extend AVK's copy.
    - KanbanViewKit (^1fas8q0) and SnapshotViewKit build theirs on the same helper.
  timestamp: 2026-10-28T11:36:03.568088+00:00
- actor: claude-code
  id: 01m617xjc3qh7xk2c195c35eqv
  text: 'User standard: "our standard for sibling packages will be screenshot-check/index.html make it so". AVK''s path stays ~/Library/Caches/AgentViewKit/screenshot-check/index.html. EditorKit is writing the standard into style.md as a "Review gallery" section. This card also adds a short "Review gallery" section to ARCHITECTURE.md (where the page is, that `swift test` regenerates it, and what it contains), and a test that pins the path.'
  timestamp: 2026-10-28T12:31:49.635903+00:00
position_column: todo
position_ordinal: ab80
title: Review gallery shows every recorded snapshot, not only the full screens
---
User: "we actually need a COMPLETE gallery of all taken snapshots, not just these full screens".

Today ~/Library/Caches/AgentViewKit/screenshot-check/index.html shows only the 7 full screens from ReviewGalleryScreen (thread, scrolled, request-deck, banners, sign-in, inspector, gallery), in light and dark. The 66 reference PNGs under Tests/AgentViewKitTests/Snapshots/__Snapshots__/ (GlassSnapshotTests: 20, HostedSnapshotTests: 46) aren't in it.

## Work
- [ ] The gallery page gets a section for every snapshot suite, after the full screens. It discovers every reference PNG under `__Snapshots__/**` by itself, so a new snapshot shows up with no registration step. Group by suite and by snapshot name, with light and dark side by side.
- [ ] Copy each reference image into the gallery folder, or link it by absolute file URL, so the page works when opened from the caches folder
- [ ] Every snapshot entry shows its name and the test that records it. A note is optional; ReviewGalleryNotes can hold notes keyed by snapshot name.
- [ ] A test fails if a reference PNG under `__Snapshots__` is missing from the generated page
- [ ] The writer stays generic (package name, snapshot root), because EditorKit is taking it into EditorTestSupport. Say so on the card if EditorKit lands first, and then do this in EditorKit's helper instead.
- [ ] `swift test` is green, and the regenerated page lists all snapshots

Order: after the Reduce Transparency and Increase Contrast removal card, so those variants never appear.