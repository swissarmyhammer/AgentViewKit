---
assignees:
- claude-code
position_column: done
position_ordinal: ffffff8f80
title: Adopt ThemedEmptyState for EmptyStateView
---
EditorKit 7b1a7082 (^cnnrdka) moved `\.isOnChrome`, `.onChrome()`, `\.showsVibrantText` and `\.placedSecondary` into EditorStyle, and `ThemedEmptyState` now follows its place.

- [x] Update EditorKit.
- [x] Replace each `EmptyStateView` with `ThemedEmptyState`, delete `EmptyStateView` and `PlacedSecondary.swift` with no wrapper. Titles go from `title2` to `title3`.
- [x] Delete `PlacedSecondaryTests`, `PlacedSecondaryHostedTests` and the two empty state tests of FontRoleHostedTests.
- [x] Regenerate the gallery.

`ConversationEmptyState` stays as it is: it is a scrolling Markdown block, not this layout.

#cross-repo