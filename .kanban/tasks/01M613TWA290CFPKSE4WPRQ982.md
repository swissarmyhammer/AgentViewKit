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
- actor: claude-code
  id: 01m618wjcdf55htyqxaa006awe
  text: |-
    Picked up; research done.
    - EditorKit has no review gallery helper yet (EditorTestSupport has no ReviewGallery, no SnapshotVariant); the user decided AVK builds the generic writer now and EditorKit ^p9rqatc lifts ReviewGallery.swift and ReviewGalleryPage.swift unchanged. The two files still use SnapshotVariant, RenderedPixels and SnapshotStore.write of AgentViewKitTestSupport; EditorKit has to bring those along (or its own equivalents) when it lifts them.
    - One `__Snapshots__` folder only: Tests/AgentViewKitTests/Snapshots/__Snapshots__ with GlassSnapshotTests (20) and HostedSnapshotTests (46) = 66 PNGs, plus a stray .DS_Store (not a PNG, skipped). KanbanViewKit uses the same `<suite>/<name>-<variant>.png` layout, so parsing the variant from the longest known SnapshotVariant suffix works for the siblings too.
    - AVK-specific bits in the two generic files today: the folder `AgentViewKit/screenshot-check`, the page title "AgentViewKit review gallery", and a ^8q34yt8 card cite. These become parameters (package name).
    - Plain `swift test` launches no UI test or demo; only Scripts/test-examples.sh takes the UI-test lock, so this card runs no lock.
    - EditorKit/style.md "Review gallery" (83d1949): `~/Library/Caches/<Package>/screenshot-check/index.html`, full screens first, then every reference PNG grouped by suite and name, Light and Dark side by side, a test fails when a PNG is missing.
  timestamp: 2026-10-28T12:48:45.453132+00:00
- actor: claude-code
  id: 01m619arzg33shwy8nc3wzby62
  text: |-
    Rescoped after the user said: "can you guys actually collaborate and come up with one solution please". AVK doesn't build the complete gallery itself. The one solution is EditorKit ^p9rqatc in EditorTestSupport, and editorkit-a9 is starting it now. This card is now an adoption card:
    - bump EditorKit;
    - switch ReviewGalleryTests and ReviewGalleryScreen to the EditorKit helper, with package "AgentViewKit" and AVK's __Snapshots__ roots;
    - delete Sources/AgentViewKitTestSupport/ReviewGallery.swift, ReviewGalleryPage.swift and the compositing code EditorKit takes over;
    - add the missing-PNG check call;
    - add the ARCHITECTURE.md "Review gallery" section.
    The stopped implementer's work in progress (discovery, folder mode, missing-PNG check; 954-line patch, targeted tests green) was reverted out of AVK. It's saved for EditorKit to start from at /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/c880133d-bf6f-444f-8105-515cb9db8591/scratchpad/gallery/avk-complete-gallery-wip.patch. Blocked until the EditorKit ^p9rqatc SHA arrives.
  timestamp: 2026-10-28T12:56:30.960674+00:00
position_column: doing
position_ordinal: '8380'
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