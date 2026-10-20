---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dsrsqmfhkxsbtmrr99j6sy
  text: 'Research: The three lines are still at the card locations (ConversationView `loadEarlierRow`, MessageActions `body`, AttachmentActions `body`). A pixel test cannot show a glass button style: the window cache shows no glass (GlassRenderProbeHostedTests), and the surface probe checks only the surface. Thus the test is a source scan, as in MessageViewsHostedTests and SessionStateBannersHostedTests. It uses `SourceLines.matching(_:inPackageFiles:)`. The test checks that each file has no `.buttonStyle(.glass` and no `.buttonStyle(.glassProminent` line, and that each file has the style of the card. The other glass button styles (SuggestionsView, DefaultPromptAccessory, SpeechInputButton, ScrollToBottomPill, PermissionView, StatusBar, SessionNoticeBanner, AgentAuthView, Elicitation views) are not in the scope of this card.'
  timestamp: 2026-10-20T23:18:59.060546+00:00
- actor: claude-code
  id: 01m5dszt3cgmk7j21jwnvfc3r5
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKit/Thread/ConversationView.swift (`.bordered`), Sources/AgentViewKit/Items/MessageActions.swift (`.borderless`, `.foregroundStyle(.secondary)` kept), Sources/AgentViewKit/Attachments/AttachmentActions.swift (`.borderless`), Tests/AgentViewKitTests/Theme/ContentButtonStyleTests.swift (new source-scan test, 2 tests x 3 files; RED with 6 issues, then GREEN). Labels, help text, identifiers and actions did not change. Full `swift test`: 1408 tests in 171 suites passed, 2 known issues (existed before), only the mlx bundle warning.
    - next: /review
  timestamp: 2026-10-20T23:22:48.812031+00:00
- actor: claude-code
  id: 01m5dt5b76d98bv4cy2zb38m86
  text: |-
    ### test — green
    - evidence: swift test — 1408 tests in 171 suites passed, 0 failed, 0 skipped, 2 known issues (existed before). swift build --build-tests — only the known mlx bundle warning.
    - next: review
  timestamp: 2026-10-20T23:25:50.182934+00:00
- actor: claude-code
  id: 01m5dt7rdxbw8qwjyz805r01ft
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 4da77d6). 0 findings, 0 confirmed, 0 refuted. 7 validator runs attempted, 0 failed. 4 files reviewed. 2 .kanban files are excluded by .reviewignore.
    - next: none. The task moved to done.
  timestamp: 2026-10-20T23:27:09.245173+00:00
- actor: claude-code
  id: 01m5dt8p0nqhfpz925xr0nsb4r
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 4 files
    - test: green — swift test, 1408 passed, 2 known issues that were there before
    - commit: 4da77d6
    - review: clean — 0 findings
  timestamp: 2026-10-20T23:27:39.541088+00:00
position_column: done
position_ordinal: ffff80
title: 'AVK-8h Remove the glass button style from buttons in content: Load Earlier, message actions, attachment actions'
---
## Why

D110 (b), (c). Glass is only for floating controls and for the action buttons of request cards. These buttons are in content rows or in the inspector, which is system glass. A glass button in the inspector is glass on glass.

## Files

- `Sources/AgentViewKit/Thread/ConversationView.swift` line 296: the Load Earlier row uses `.buttonStyle(.glass)`.
- `Sources/AgentViewKit/Items/MessageActions.swift` line 153: the action row of a message uses `.buttonStyle(.glass)`.
- `Sources/AgentViewKit/Attachments/AttachmentActions.swift` line 77: the attachment actions use `.buttonStyle(.glass)`. Users: `Attachments/ArtifactView.swift:50` (content) and `Attachments/AttachmentInspector.swift:126` (inspector).

## What to do

- [x] Load Earlier: use `.buttonStyle(.bordered)`.
- [x] Message actions: use `.buttonStyle(.borderless)`. Keep `.foregroundStyle(.secondary)` (a vibrant style).
- [x] Attachment actions: use `.buttonStyle(.borderless)`.
- [x] Do not change labels, help text, identifiers or actions.

## Acceptance

- The three files have no `.buttonStyle(.glass)` and no `.buttonStyle(.glassProminent)`.
- All tests in `Tests/AgentViewKitTests/Thread/`, `Items/` and `Attachments/` pass. The tests that find these buttons by identifier still find them.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest.

## Open question

`comparison.md` line 365 and 732 describe a future floating glass hover bar for message actions. If a message action bar floats over the transcript later, it becomes a floating control and can use glass. This card covers only the row as it is today. #avk-8