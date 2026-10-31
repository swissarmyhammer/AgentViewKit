---
assignees:
- claude-code
position_column: todo
position_ordinal: '8580'
title: Adopt ThemedEmptyState for EmptyStateView once it works on chrome (blocked on EditorKit)
---
EditorKit 3b29fc66 added `ThemedEmptyState`, the one empty state of the kits, and style.md now names it. It draws `\.themeSecondary` and is for content only (rule 6), but SessionListView, ConnectionsView (settings sheet) and ActivityTimeline (inspector) stand on chrome. I asked editorkit-82 to make it follow its place, by moving `\.isOnChrome`, `.onChrome()`, `\.showsVibrantText` and `\.placedSecondary` into EditorStyle. Waiting on its SHA or decision.

- [ ] Update EditorKit.
- [ ] Replace each `EmptyStateView` with `ThemedEmptyState`, and delete `EmptyStateView` with no wrapper. Its title goes from `title2` to `title3`.
- [ ] Update FontRoleHostedTests and any test that reads `EmptyStateView.titleIdentifier` or `descriptionIdentifier`.
- [ ] Regenerate the gallery.

`ConversationEmptyState` stays as it is: it is a scrolling Markdown block, not this layout.

#cross-repo