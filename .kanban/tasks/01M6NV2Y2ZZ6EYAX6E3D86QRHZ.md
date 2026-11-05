---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6nyjhz8n5nh7cc7ms58qxwk
  text: 'Picked up. Research: EK fca868d4 (^khab74z, 4c9b4101) adds EditorSymbol.Action .back ("chevron.backward"), .forward ("chevron.forward") and .conversation ("bubble.left.and.bubble.right"). AVK uses: AgentSymbol.previousRequest/nextRequest (RequestDeck step buttons, AgentCommandVerb.icon), previousSibling/nextSibling (AgentCommandVerb.icon), conversation (ConversationEmptyContent.standard, SessionListView empty state, PreviewFixtures.headerSymbols). The symbol-concept tests (SymbolConceptTests) had no back/forward/conversation concept. Plan: RequestDeck.previousSymbol/nextSymbol (EditorSymbol) drawn with EditorSymbolImage in the step button Label; AgentCommandVerb.icon reads EditorSymbol.action(...).systemImage (EK command definitions take a String icon); SessionListView.emptySymbol (EK ThemedEmptyState takes a String); DecorativeSymbolImage (empty-thread header) now draws EditorSymbolImage(systemName:tone: .neutral), so the conversation symbol draws with EditorSymbolImage too. SymbolConceptTests gain back/forward/conversation concepts read from the views, and a test that they are EK''s actions.'
  timestamp: 2026-11-05T13:32:34.664318+00:00
- actor: claude-code
  id: 01m6nz0k7d4da4030stjgra5tb
  text: |-
    Implementation landed in 7a3d72fb (worktree branch worktree-agent-abe93fb5c14c9482e, on AVK a1fe3d0d; EK resolved at fca868d4 in root, IntegrationTests and ScreenshotTests via `swift package update`, no pins).
    - AgentSymbol: removed previousRequest, nextRequest, previousSibling, nextSibling (all chevron.backward/forward) and conversation; header doc lists Back/Forward/conversation among EK's shared symbols.
    - RequestDeck: previousSymbol = .action(.back), nextSymbol = .action(.forward); the step button's Label icon is EditorSymbolImage(symbol).
    - AgentCommandVerb.icon: previousRequest/previousSibling -> EditorSymbol.action(.back).systemImage, nextRequest/nextSibling -> .action(.forward) (EK CommandDefinition takes a String icon).
    - SessionListView.emptySymbol = .action(.conversation) (EK ThemedEmptyState takes a String); ConversationEmptyContent.standard and PreviewFixtures.headerSymbols read .action(.conversation).
    - DecorativeSymbolImage now draws EditorSymbolImage(systemName:tone: .neutral) + accessibilityHidden, so the empty-thread conversation symbol draws through EditorSymbolImage (adds hierarchical rendering to the agent-header symbol too).
    - SymbolConceptTests: concepts back/forward/conversation with uses read from the deck, the verbs and the empty states; new test theHistoryAndConversationSymbolsAreTheActionsOfEditorKit (RED was a compile failure on the missing statics).
  timestamp: 2026-11-05T13:40:14.701033+00:00
- actor: claude-code
  id: 01m6nz0q5rcrrpyk1m5yq7beya
  text: |-
    ### implement — changed
    - evidence: 8 files — Sources/AgentViewKit/Items/AgentSymbol.swift, Sources/AgentViewKit/Items/DecorativeSymbolImage.swift, Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift, Sources/AgentViewKit/Commands/AgentCommandPlacement.swift, Sources/AgentViewKit/Sessions/SessionListView.swift, Sources/AgentViewKit/Thread/ConversationEmptyState.swift, Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift, Tests/AgentViewKitTests/Items/SymbolConceptTests.swift
    - next: review

    ### test — green
    - evidence: root `swift test` 970 tests in 107 suites + 60 in 9 suites passed; `swift test --package-path IntegrationTests` 951 tests in 124 suites passed (5 known issues, pre-existing withKnownIssue); zero warnings in AVK targets (only mlx-swift dependency warnings)
    - next: review

    ### commit — changed
    - evidence: 7a3d72fb on worktree-agent-abe93fb5c14c9482e (not pushed, not merged)
    - next: /review
  timestamp: 2026-11-05T13:40:18.744432+00:00
position_column: doing
position_ordinal: 8f80
title: Move back, forward and chat symbols from AgentSymbol onto EditorKit's EditorSymbol
---
**Blocked** on EK's card (being built, 2026-11-05) that adds `.action(.back)`, `.action(.forward)` and a chat or conversation symbol to EditorSymbol. editorkit-b5 sends the SHA. Second-kit rule: Testudo uses `chevron.backward`/`chevron.forward` (SAHKit InspectorAreaView) and `bubble.left.and.bubble.right` (SAHKit WindowLayout), so these leave AVK's internal AgentSymbol.

## What
- `swift package update` (all dependencies together).
- Move every AVK use of AgentSymbol's back, forward and chat bubble names onto EK's EditorSymbol, drawn with EditorSymbolImage, and delete the three from AgentSymbol.

## Acceptance Criteria
- [x] AgentSymbol has no back, forward or chat entry; AVK draws them with EK's EditorSymbol.

## Tests
- [x] The full AVK suite is green, with zero warnings in AVK targets.
- [x] The symbol-concept tests read EK's cases.