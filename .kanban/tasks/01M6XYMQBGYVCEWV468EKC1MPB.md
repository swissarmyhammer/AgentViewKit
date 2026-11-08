---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6xz1xx8j8evw9k6dmznzvmc
  text: |-
    EK answer (editorkit-9f): the ring does NOT stay. A focusable card is a kit item with a surface: focused fill, no outline.
    Blocked by EK card ^tmwpx2x (01M6XZ1K6YHH8HD8RKATMWPX2X). It adds public `.selectableItem(isSelected:isFocused:radius:)` and `.selectableItem(isSelected:isFocused:cornerRadius:)`. The host gives isFocused from @FocusState, as with .editorFocusRing. The fill is the focused fill when isFocused is true or the scope holds the focus.
    Do not start until EK sends the sha on main. Then update the EK pin, use the new form on the permission card (RequestDeck.swift, PermissionView.swift) in place of .editorFocusRing, and add the hosted test.
  timestamp: 2026-11-08T16:14:53.864732+00:00
position_column: todo
position_ordinal: '80'
title: 'Permission card: show keyboard focus as the focused fill, not as .editorFocusRing'
---
Found during ^v3zpcpd (style.md "Selection and focus").

The permission card of the request deck is focusable (`@FocusState`, `.focusEffectDisabled()`, for `defaultFocus` and Escape-to-cancel). A jump or a nav move gives the focus to the card itself, not to the beacon of its scope. Thus `\.commandScopeHoldsFocus` is false, the `.fill(.card)` look of `AgentItemScope` shows no focused fill, and the card shows `.editorFocusRing` (an outline) in Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift and PermissionView.swift.

The rule says: an item with a surface never shows a ring. EK permits `.editorFocusRing` for a focusable card, but EK has no public API to draw the focused fill from the focus of a focusable view (`selectableItemSurface(isSelected:isFocused:cornerRadius:)` is `package` in EditorStyle).

To do:
- [ ] Ask EK for a public form, for example `.selectableItem(isSelected:isFocused:cornerRadius:)`, or confirm that the ring stays for a focusable card.
- [ ] Then show the focus of the permission card as the focused fill, and remove `.editorFocusRing` from the card.
- [ ] Hosted test: a focused permission card shows no outline.