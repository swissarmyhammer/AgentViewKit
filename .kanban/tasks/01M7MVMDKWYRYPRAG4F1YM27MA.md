---
assignees:
- claude-code
position_column: done
position_ordinal: ffffffdc80
title: 'Textual text: menu(for:) gives the item menu'
---
From testudoapp-75 (TestudoApp 2f28a3f, AVK 862fdca8). The hosted test still fails: `HostedViewHarness.contextMenu(at:)` and the VoiceOver show-menu action call `menu(for:)` of the Textual `NSTextInteractionView` directly, and it gives "Share…" and "Copy". The event monitor of 862fdca8 sees only real presses.

Fix: replace the implementation of `menu(for:)` of the Textual class one time at run time. The new implementation gives the menu of the first view above it that gives one, or else the Textual menu. Keep the monitor for real presses, because Textual `rightMouseDown` shows its own menu with no call to `menu(for:)`. Do not run the `willOpen` hook from the lookup: the EditorKit monitor and the harness run it one time.

Tests: a unit test with a test class; the hosted test calls `harness.contextMenu(at:)` on the text. #bug