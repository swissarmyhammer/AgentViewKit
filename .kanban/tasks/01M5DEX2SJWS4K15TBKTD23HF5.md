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
- actor: claude-code
  id: 01m5j17exa3zt6xwyt4pysymz0
  text: 'Picked up. `swift package update EditorKit` resolved main at 91f8352. Research: the only call site of the removed API is AgentItemScope (`.jumpTarget(isJumpTarget ? JumpTargetOverride() : .hidden)` and `.navVisible()`). `.targetable(_:)` is an Environment value that the ENCLOSING `.commandScope` reads, so it must be chained after (outside) `.commandScope`, as in EditorKit''s ScopeTargetingTests `DeckBoard`. Every `.commandScope` in AVK goes through AgentCommandScope (the thread), AgentItemScope (messages, tool calls, request cards, and via AgentAttachmentScope the attachments). `.targetable(false)` also removes every nested scope, so the thread scope cannot be marked untargetable without removing all items.'
  timestamp: 2026-10-22T14:46:17.258871+00:00
- actor: claude-code
  id: 01m5j1pvg63a53hepy9gv1qwmt
  text: |-
    Implementation landed on EditorKit 91f8352. Package.resolved is gitignored, and Package.swift tracks EditorKit `main`, so there is nothing to commit for the bump itself.
    - AgentItemScope: removed `.jumpTarget(isJumpTarget ? JumpTargetOverride() : .hidden)` and `.navVisible()`. Added `.targetable(isTargetable)` after `.commandScope`, because the enclosing scope reads it from the Environment. The parameter is renamed `isJumpTarget` -> `isTargetable`. It covers jump and nav, and the modifier chain is the same for every value, so identity is kept.
    - DeckCard: `.agentItemScope(..., isTargetable: role.showsWhole)`. The view structure did not change.
    - New hosted test `anEdgeDeckCardIsNotInTheNavigationSnapshotOfTheThread`. RED with the call sites migrated but no `.targetable` (it failed at `!scopes.contains(cards.edge)`), then GREEN.
    - New hosted test `aDeckCardKeepsItsCommentTextWhenItGoesBehindAndComesBack`: reject, type a comment, Next, Previous, then the comment value is still there. It already passed before `.targetable` was added. It guards identity: it would fail if the switch were made with an `if`.
    - `theJumpOverlayListsTheItemsOfTheThreadAtTheirFrames` broke because a chip anchor is now a zero-size rect at the centre of the scope rect. Renamed it to `...AtTheCentresOfTheirFrames` and changed it to assert that anchor.
    - Wrappers and containers: the only other `.commandScope` is the thread scope (AgentCommandScope). It is a real pane-level container. `.targetable(false)` on it would also remove every item nested in it, so it stays targetable. No other wrapper scope exists. AgentAttachmentScope goes through AgentItemScope and stays a real target.
  timestamp: 2026-10-22T14:54:41.670497+00:00
- actor: claude-code
  id: 01m5j1pxx1nfjvped0x1fpmsh9
  text: |-
    ### implement — changed
    - evidence: `swift test`: 1588 tests in 198 suites passed, plus 219 and 1 in the other runs. The 3 known issues are existing withKnownIssue self-tests. 3 files: Sources/AgentViewKit/Commands/AgentItemScope.swift, Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift, Tests/AgentViewKitTests/Commands/AgentNavigationHostedTests.swift. EditorKit resolved locally at 91f8352.
    - next: /review
  timestamp: 2026-10-22T14:54:44.129498+00:00
- actor: claude-code
  id: 01m5j24k0m3c61e2h534wjvb2a
  text: |-
    ### test — green (with the known failure of ^bc6fapz)
    - evidence: `swift test` — 1588 tests in 198 suites passed, 0 failures, 0 skipped; the 3 known issues are the withKnownIssue negative-path tests (SnapshotStoreTests, HostedLayoutExpectationsTests and one more), not failures. No compiler warnings from project code; only the known mlx-swift "missing creator" notice.
    - evidence: `Scripts/test-examples.sh` — the demo builds against EditorKit 91f8352 (BUILD SUCCEEDED, no code warnings). UI tests: 4 of 5 pass in the ACP and gallery suites (3 + 1 executed, 0 failures); the only failing test is `ACPTabEndToEndTests.testASendOfHelloShowsTheReplyOfTheAgent` ("Unable to find hit point for ScrollView"), the known failure tracked on ^bc6fapz, not fixed here.
    - note: XCUITest prints a runtime notice "This method should not be called on the main thread" inside its own UI-interruption handler for the settings-sheet test; the class is already @MainActor, and the notice comes from the XCTest framework, not project code.
    - next: review, then commit.
  timestamp: 2026-10-22T15:02:11.732725+00:00
- actor: claude-code
  id: 01m5j2aeev8zanvznzy5b54ab2
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (4569599) — 0 findings, 0 confirmed, 0 refuted; 7 attempted, 0 failed, 0 skipped; 3 files reviewed, 6 .kanban/ files excluded by .reviewignore. No prior Review Findings sections.
    - next: task moved to done
  timestamp: 2026-10-22T15:05:23.675424+00:00
- actor: claude-code
  id: 01m5j2arhn9x9e5mqr3cjc1fkt
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — 3 files (AgentItemScope.swift, RequestDeck.swift, AgentNavigationHostedTests.swift); EditorKit resolved 91f8352; red first: the edge card was in the nav snapshot
    - test: green — swift test 1588 passed, 0 failed, 0 skipped; demo builds; the demo UI gate's only failure is the known ^bc6fapz
    - commit: 4569599 (local, not pushed)
    - review: clean — 0 findings, task in done
  timestamp: 2026-10-22T15:05:34.005780+00:00
position_column: done
position_ordinal: ffffb080
title: 'Request deck: a card that does not show whole is still a nav target'
---
Found in AVK-7d (^56y8q6a).

Each request card scope is `.navVisible()` (AgentItemScope). The deck also keeps the edge cards and the hidden cards mounted, with opacity 0 or behind the front card. AVK-7d removes them from jump mode with `.jumpTarget(.hidden)`. But they stay in the EditorKit nav snapshot: the snapshot filters only AppKit-hidden and zero-area scopes. The edge cards are above the front card, so a `nav.*` move into the deck can land on an edge card that does not show whole.

AgentItemScope cannot apply `.navVisible()` only to the cards that show whole. An `if` on the role changes the view identity of the card, and the card loses its state (for example the comment text of PermissionView). DeckCard keeps the same modifiers for each role for this cause.

Needed from EditorKit: a value form, for example `.navVisible(_ isVisible: Bool)`, or a scope flag that the nav snapshot skips. Then pass `role.showsWhole` from DeckCard, and add a hosted test: the edge card is not in `system.geometry.snapshot(layer:)`. #avk-7