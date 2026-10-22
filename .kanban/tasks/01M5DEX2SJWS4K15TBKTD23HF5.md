---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5hkv55b8tpd7zf8xyrsxyzt
  text: |-
    Blocked: EditorKit does not have the API this card needs yet.

    Checked the sibling checkout ../EditorKit after `git fetch origin`. origin/main is still 348324f ("chore(kanban): record the final ledger of ^c3ya9ed"). That is the same revision AgentViewKit resolves now, so there is no newer EditorKit to bump to.

    - `Sources/EditorCommandsUI/CommandScopeModifier.swift` has only the parameterless `public func navVisible() -> some View`. It sets `request.isNavVisible = true`. There is no `.navVisible(_ isVisible: Bool)` overload, and `isNavVisible` is internal, not public.
    - `GeometryRegistry.snapshot(layer:focused:)` drops a scope only when `probe.isProbeHidden` is true or `windowRect` is nil or has zero area. No scope flag or metadata field makes the nav snapshot skip a scope.

    AgentViewKit cannot work around this. An `if` on `role.showsWhole` in DeckCard changes the view identity, and the card loses its state. That is the reason this card exists.

    Needed first: an EditorKit change on origin/main that adds a value form (`.navVisible(_ isVisible: Bool)`) or a scope flag that `snapshot(layer:)` skips. After that lands, bump the resolution, pass `role.showsWhole` from DeckCard without changing the view identity, and add the hosted test that checks the edge card is not in `system.geometry.snapshot(layer:)`. No code was changed in AgentViewKit or EditorKit.
  timestamp: 2026-10-22T10:52:22.571235+00:00
- actor: claude-code
  id: 01m5hkv7692zmfyw0twg7pfq8x
  text: |-
    ### implement — stuck
    - evidence: EditorKit origin/main is 348324f, the same revision AgentViewKit resolves. It has only the parameterless `navVisible()`, and `GeometryRegistry.snapshot(layer:)` skips only probes that are hidden or have zero area. No files changed.
    - next: add `.navVisible(_ isVisible: Bool)`, or a scope flag that the snapshot skips, to EditorKit main. Then implement this card again.
  timestamp: 2026-10-22T10:52:24.649950+00:00
- actor: claude-code
  id: 01m5hkvkeev1p48fkn08as03vb
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — EditorKit origin/main 348324f (= resolved) has only parameterless navVisible() (Sources/EditorCommandsUI/CommandScopeModifier.swift); GeometryRegistry.snapshot(layer:) has no skip flag. 0 files changed.
    - test, commit, review: not run
    - next: EditorKit main needs `.navVisible(_ isVisible: Bool)` or a scope flag the nav snapshot skips; then /implement this card again.
  timestamp: 2026-10-22T10:52:37.198497+00:00
- actor: claude-code
  id: 01m5hkyt9gfrmws1tndcv9hxd7
  text: 'Blocker tracked in EditorKit as ^azp1kd1 (01M5HKYG8A9F9WBJ0FCAZP1KD1), per editorkit-28. Planned API: `.navVisible(_ isVisible: Bool = true)`. With false, GeometryRegistry.snapshot(layer:) skips the scope, and identity and @State are kept when it toggles. Not landed yet; editorkit-28 will send the SHA.'
  timestamp: 2026-10-22T10:54:22.512384+00:00
- actor: claude-code
  id: 01m5hnvzjghpbndh0n05z3stvy
  text: |-
    API change from editorkit-28 (2026-10-22), replacing the planned `.navVisible(Bool)`. EditorKit ^azp1kd1 now lands after ^xm5pawz; SHA to follow. Rules from the user: every .commandScope is targetable by default, which covers jump, nav and commands. There is one opt-out, and the old API is removed, not deprecated.
    - `.targetable(_ isTargetable: Bool)`: with false, the scope has no jump label and is not in the nav snapshot. Jump, nav and drill can't focus it. Commands at its path resolve at the nearest targetable ancestor. Its descendants follow it. Toggling keeps identity and @State, so DeckCard uses `.targetable(isOnTop)` (or `role.showsWhole`) directly.
    - `.navVisible()` is REMOVED. Drop every `.navVisible()` call (AgentItemScope and others) when you bump.
    - `.jumpTarget(.hidden)` is REMOVED. Use `.targetable(false)`. `.jumpTarget(_:)` keeps only label, anchor and action customization.
    When you implement: bump EditorKit, migrate all the call sites, and add the hosted test that an edge card is not in `system.geometry.snapshot(layer:)`.
  timestamp: 2026-10-22T11:27:46.768401+00:00
- actor: claude-code
  id: 01m5j0qap0sw6dqxtytha0s9ey
  text: 'UNBLOCKED: EditorKit main 91f8352 (^azp1kd1), a BREAKING change. Every .commandScope is a jump, nav and command target by default; its beacon has the content''s area. `.targetable(_ isTargetable: Bool)`: false removes the scope and its descendants from jump labels, the nav snapshot and focus by jump/nav/drill. Commands at its path resolve at the nearest targetable ancestor. Toggling keeps identity and @State, so DeckCard uses `.targetable(role.showsWhole)`. REMOVED: `.navVisible()` (delete the calls), `JumpTargetOverride.hidden` / `isHidden`, and the no-argument `.jumpTarget()`; use `.targetable(false)`. `.jumpTarget(_:)` keeps label, anchor, action and kind. Jump labels now anchor at the scope centre. To do: `swift package update EditorKit` to 91f8352 or later, migrate every call site, and add the hosted test that an edge card is not in `system.geometry.snapshot(layer:)`.'
  timestamp: 2026-10-22T14:37:28.640845+00:00
position_column: todo
position_ordinal: '8780'
title: 'Request deck: a card that does not show whole is still a nav target'
---
Found in AVK-7d (^56y8q6a).

Each request card scope is `.navVisible()` (AgentItemScope). The deck also keeps the edge cards and the hidden cards mounted, with opacity 0 or behind the front card. AVK-7d removes them from jump mode with `.jumpTarget(.hidden)`. But they stay in the EditorKit nav snapshot: the snapshot filters only AppKit-hidden and zero-area scopes. The edge cards are above the front card, so a `nav.*` move into the deck can land on an edge card that does not show whole.

AgentItemScope cannot apply `.navVisible()` only to the cards that show whole. An `if` on the role changes the view identity of the card, and the card loses its state (for example the comment text of PermissionView). DeckCard keeps the same modifiers for each role for this cause.

Needed from EditorKit: a value form, for example `.navVisible(_ isVisible: Bool)`, or a scope flag that the nav snapshot skips. Then pass `role.showsWhole` from DeckCard, and add a hosted test: the edge card is not in `system.geometry.snapshot(layer:)`. #avk-7