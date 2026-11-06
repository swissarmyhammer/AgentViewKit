---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6qbwedztbcz2fyfm1q9pvwc
  text: 'Research: EK 3fd4a204 EditorMenuButton(title, systemImage:, look:) { rows } — one AX element, hides caption when squeezed (label stays title, tooltip=title via AX help), jump target. No custom label, so it cannot carry the breadcrumb crumbs (truncating session titles, no icon; AgentInfoHeaderBreadcrumbHostedTests.aLongCrumbTruncatesInANarrowPane pins that). SessionBreadcrumb''s `dropdown` (the Menu the card names) is shared by crumbs, overflow and children; the card names the children menu, so children moves to EditorMenuButton and crumbs/overflow keep the dropdown (follow-up card for those). buttonTitle: only multi-word command button caption is AgentAttachmentVerb.revealAttachment "Reveal in Finder" in AttachmentActions (inspector/artifact action row) → buttonTitle "Reveal". isOn: AVK has no command toggle; the Reasoning toggle is a hand-built action toggle (Show/Hide reasoning titles swapping) → EK''s EditorToolbarButton(_:symbol:isOn:) binding toggle. Gallery: config-controls and buttons-narrow/wide cover these views; add the two menu buttons to ButtonGalleryFixtures. EK''s harness.perform(.showMenu) returns the opened NSMenu, so hosted tests can open a menu now (the ToolToggles test comment saying a hosted window cannot open the menu is stale).'
  timestamp: 2026-11-06T02:44:24.639890+00:00
- actor: claude-code
  id: 01m6qdfzz1fvgxhtn77ajgkr47
  text: |-
    ### implement — changed
    - evidence: commit 9b4a1330 on worktree-agent-a5e473c8e4eb01579. 14 files: ARCHITECTURE.md; Sources ConfigOptionsView, ToolToggles, SessionBreadcrumb, ReasoningView, AgentAttachmentCommands, Localizable.xcstrings; Tests AgentAttachmentCommandsTests; IntegrationTests MenuButtonHostedTests (new), SqueezedButtonHostedTests, AttachmentCommandsHostedTests, AttachmentInspectorHostedTests, ToolTogglesHostedTests; ScreenshotTests ButtonGalleryFixtures. Root swift test: 1065 + 50 passed. IntegrationTests swift test: 1012 tests in 139 suites passed (5 known issues, all the pre-existing withKnownIssue in FontRoleExpectationsTests). ScreenshotTests build --build-tests complete, captures not run. Only warning: the known mlx bundle warning.
    - decisions: the children menu is EditorMenuButton (symbol childSession, warning symbol when a child needs the user; custom AX label kept; the crumb hint dropped because EK's tooltip is the AX help). Crumbs and overflow keep the shared dropdown — follow-up ^dax7gt3. "Turn tools on or off" help dropped (EK owns the tooltip); catalog entry removed. buttonTitle: revealAttachment → "Reveal" (tooltip "Reveal in Finder"). isOn: no AVK command toggle exists; the Reasoning expand button became EditorToolbarButton("Show reasoning", symbol:, isOn:) (one title, toggle trait, value 1/0; "Hide reasoning" removed from the catalog).
    - RED notes: one-element and showMenu tests already passed on raw Menu; the squeezed-tooltip, Reveal, Reasoning and buttonTitle tests failed first. Tools needed a 32 pt width since "Tools" fits in 60 pt; menu titles filter separators.
    - next: /review
  timestamp: 2026-11-06T03:12:33.761432+00:00
- actor: claude-code
  id: 01m6qdye8jmk781wjknaabt8v3
  text: |-
    ### implement — changed (review findings)
    - evidence: commit 09eada34. (1) one mount helper: SqueezedButtonHostedTests.mountSqueezed became mount(_:width:) (width required); MenuButtonHostedTests' local mount is gone and it uses that helper at the window width or the squeezed width. (2) element count: EK EditorTestSupport already has `accessibilityElements(identifiedAs:under:includingScrollAreas:)` (AccessibilityHitTest.swift); MenuButtonHostedTests.elementCount and MathViewHostedTests.count are deleted and both suites call it with `harness.hostingView`. Root swift test 1065 + 50 passed; IntegrationTests 1012 tests in 139 suites passed (5 known issues in FontRoleExpectationsTests, pre-existing); only warning the known mlx bundle one.
    - note: other AVK suites still filter `harness.accessibilityElements()` by identifier inline (ComposerCompletionRoutesHostedTests, SlashCommandSessionModelTests, ElicitationWhoAsksHostedTests, ThreadFloatingControlsHostedTests, Helpers/SingleLineFieldChecks) — not helper copies, left as they are.
  timestamp: 2026-11-06T03:20:27.154674+00:00
position_column: done
position_ordinal: ffffffbb80
title: 'Menu buttons on EK EditorMenuButton: Session Options, Tools, session breadcrumb'
---
EK 3fd4a204 adds `EditorMenuButton`, a themed menu button. It is one AX element, collapses its caption instead of clipping it, and is a jump target. AVK still uses raw SwiftUI `Menu` for its menu buttons:
- `Sources/AgentViewKit/Config/ConfigOptionsView.swift:208`: Session Options
- `Sources/AgentViewKit/Input/ToolToggles.swift:119`: Tools
- `Sources/AgentViewKit/Sessions/SessionBreadcrumb.swift:185`: children menu (`.menuStyle(.borderlessButton)`)

Rule (buttons collapse, never clip): a button uses EK's button, with no per-call button styling.

- [x] Each menu button above uses `EditorMenuButton`; drop the per-call menu styling
- [x] Check the EK 3fd4a204 additions `CommandDefinition.buttonTitle` and `EditorToolbarButton(command:…, isOn:)`. Adopt them where AVK has command buttons with long titles, or a hand-built command toggle such as the Reasoning toggle
- [x] Hosted tests through accessibility: each menu button is one element and opens its menu through an AX action
- [x] Add a gallery capture where the existing gallery covers these views