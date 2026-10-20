---
assignees:
- claude-code
position_column: todo
position_ordinal: '8780'
title: 'Request deck: a card that does not show whole is still a nav target'
---
Found in AVK-7d (^56y8q6a).

Each request card scope is `.navVisible()` (AgentItemScope). The deck also keeps the edge cards and the hidden cards mounted, with opacity 0 or behind the front card. AVK-7d removes them from jump mode with `.jumpTarget(.hidden)`. But they stay in the EditorKit nav snapshot: the snapshot filters only AppKit-hidden and zero-area scopes. The edge cards are above the front card, so a `nav.*` move into the deck can land on an edge card that does not show whole.

AgentItemScope cannot apply `.navVisible()` only to the cards that show whole. An `if` on the role changes the view identity of the card, and the card loses its state (for example the comment text of PermissionView). DeckCard keeps the same modifiers for each role for this cause.

Needed from EditorKit: a value form, for example `.navVisible(_ isVisible: Bool)`, or a scope flag that the nav snapshot skips. Then pass `role.showsWhole` from DeckCard, and add a hosted test: the edge card is not in `system.geometry.snapshot(layer:)`. #avk-7