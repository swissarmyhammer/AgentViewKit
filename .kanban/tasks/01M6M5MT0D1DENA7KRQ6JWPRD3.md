---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6madg2hn54yh8rgt45rcb41
  text: |-
    EK half unblocked (editorkit-b5, 2026-11-04): EK ^g2f8jhx (the done commit after b9d96333) makes EditorSymbol cover all of SharedSymbol.
    - Tool and file kinds already matched, with the same SF Symbols.
    - New: `.severity(.information/.warning/.error)` in severity tokens, `.session(.closed)`, and `.action(.reload/.dismiss/.link/.disclosure)`, neutral in `\.placedSecondary`.
    - `FileKind(diffOperation:)` maps EditorDiff's FileDiff.Operation.
    Plan:
    1. Move AVK's own SharedSymbol uses onto EditorSymbol now. Start after the status ^0cqh945 and path chip ^hpxbqhx cards merge, because they touch the same symbol call sites.
    2. Delete the public SharedSymbol only once SVK and KVK have moved off it. Grep them first.
    3. AVK's `EditorSymbol.FileKind(_: DiffSummary.Operation)` extension stays until DiffSummary.Operation is replaced by EK's FileDiff.Operation. AVK's has `.unknown(String)`, which EK's lacks. SVK's test also uses it until SVK ^06qg54z.
  timestamp: 2026-11-04T22:21:02.929786+00:00
- actor: claude-code
  id: 01m6manb1d9p2j0sfkfcj1j523
  text: 'From ^hpxbqhx: `DiffFileChip.symbolName(for:)` is deleted there (SVK e9fb54f, KVK a87351a and Testudo 2bd4341 no longer call it). It did not move to `EditorSymbol.FileKind(location:)`: that initializer maps a URL to `.folder`/`.document`, not a diff change. SVK''s CheckpointFileContentTests now compares `EditorSymbol.file(EditorSymbol.FileKind(operation))` with its expected symbol, through AVK''s `EditorSymbol.FileKind(_ operation: DiffSummary.Operation)` extension, which stays until EK has its own diff-operation initializer. So the symbolName bullet of this card is done by ^hpxbqhx.'
  timestamp: 2026-11-04T22:25:19.917626+00:00
- actor: claude-code
  id: 01m6md60d1tar9090bz7sgr7ew
  text: 'Consumer check, 2026-11-04: SVK b25a20c and TestudoApp 37845ac use no SharedSymbol (grep empty, kanban and md excluded). KVK 9784a5d still uses it in 7 files, so the public type''s removal waits only for KVK. AVK''s own uses can move onto EditorSymbol now, once the status ^0cqh945 and path chip ^hpxbqhx cards merge.'
  timestamp: 2026-11-04T23:09:23.233733+00:00
- actor: claude-code
  id: 01m6nnmqs8rwsecj00r0pgspcp
  text: 'Fully unblocked by consumers (2026-11-05): KVK d73069b (0e89ee2 + 2e4215c), SVK b03783e and TestudoApp 5c3a4bd have no SharedSymbol (grep empty, kanban and md excluded). Delete the public type and its DocC entries once AVK''s own uses move onto EditorSymbol. Start after the path chip card ^hpxbqhx merges, since it touches the same symbol call sites (DiffFileChip and others). KVK''s banners still use AVK''s `StatusBar.Message.Severity`, so keep StatusBar as it is.'
  timestamp: 2026-11-05T10:56:28.968735+00:00
- actor: claude-code
  id: 01m6nrd7n484g8fpz2ktraee8n
  text: |-
    Picked up (base 5f52457d, EK checkout 01b49c34). Consumer re-grep of origin mains, shallow clones, no truncation, .md and .kanban included: KVK d73069b, SVK b03783e, TestudoApp 5c3a4bd have no `SharedSymbol`, no `ChipFlowLayout`, no `symbolName(for:` (grep exit 1).
    Research:
    - SharedSymbol's own names map 1:1 onto EK's EditorSymbol with the same SF Symbols: error/warning/information → `.severity`, closed → `.session(.closed)`, reload/dismiss/link/disclosure → `.action`, tool and file names → `.tool`/`.file` (AVK no longer reads those through SharedSymbol).
    - `Sources/AgentViewKit/Items/SharedSymbol+Agent.swift` extends SharedSymbol with ~70 agent-only names (send, stop, copy, accept, userAction, usage, ...). EditorSymbol has no case for them and EK is not edited here, so they cannot move onto EditorSymbol. Deleting SharedSymbol takes that extension with it, so it becomes AVK's own internal table `AgentSymbol` (same names, same SF Symbols) in AgentViewKit.
    - StatusBar.Message already draws through `EditorSymbolImage(systemName:tone:)` in the severity tone, so the bars keep their themed tones; StatusBar and `StatusBar.Message.Severity` stay (KVK banners).
    - Drawn sites that hand-built an Image of a SharedSymbol name (disclosure chevrons of ToolCallView, ReasoningView, SessionBreadcrumb, AgentInfoHeader; the link mark of SourcesView; the warning mark of a breadcrumb crumb) move onto `EditorSymbolImage(EditorSymbol)`.
  timestamp: 2026-11-05T11:44:48.804942+00:00
- actor: claude-code
  id: 01m6ns500vs414h18nmz0p408x
  text: |-
    Implementation landed in commit 4e7de07e (branch worktree-agent-a9021a0a21b612f9c, on base 5f52457d; not pushed or merged).
    - Every AVK SharedSymbol read is EditorSymbol now: `.severity(.error/.warning/.information)`, `.session(.closed)`, `.action(.reload/.dismiss/.link/.disclosure)`. A failed connection is `EditorStatus(.failed, detail:)`.
    - Drawn sites on EditorSymbolImage: the disclosure chevrons of ToolCallView, ReasoningView, SessionBreadcrumb and AgentInfoHeader (decorative ones `.accessibilityHidden(true)`), the link mark of SourcesView, and the breadcrumb warning mark (was a hand-tinted severityWarning Image).
    - Agent-only names (send, stop, copy, accept, userAction, usage, ...) have no EditorSymbol case and EK was not edited, so `SharedSymbol+Agent.swift` became AVK's internal `AgentSymbol` enum (Sources/AgentViewKit/Items/AgentSymbol.swift), same names and SF Symbols.
    - Deleted Sources/AgentViewKitStyle/Symbols/SharedSymbol.swift, its DocC `### Symbols` entry and Tests/AgentViewKitStyleTests/SharedSymbolTests.swift (EK's tests own the names now). ARCHITECTURE.md and plan.md updated. StatusBar and `StatusBar.Message.Severity` kept.
    - Gallery: the capture runs once at the end of the paired ChipFlowLayout card ^3e9ynej, in the same worktree.

    ### implement — changed
    - evidence: commit 4e7de07e, 65 files; `swift test` 969 + 62 passed; `swift test --package-path IntegrationTests` 945 passed (5 known issues are FontRoleExpectationsTests' deliberate negative checks); zero warnings in AVK targets (only mlx-swift dependency warnings)
    - next: review
  timestamp: 2026-11-05T11:57:47.419755+00:00
- actor: claude-code
  id: 01m6ntvha2mgx56vwrt9q51rm1
  text: |-
    Review fixes landed in commit ecfe4825, on top of main b8a468dc (branch fast-forwarded first). All 4 findings are fixed and ticked under Review Findings.
    - 1: new IntegrationTests helper `StatusBarFixtures.reloadAction(identifier:hint:)` (Helpers/StatusBarFixtures.swift). StatusBarTests and StatusTitleLineHostedTests both call it.
    - 2: `StatusBarTests.message(_:explanation:)` defaults the explanation to "Explanation"; the title-only test calls `Self.message(.neutral, explanation: "")`.
    - 3: ChipRowsGalleryFixtures names its numbers (`lineStep`, plus `patchFolder` for the patch path). The sample paths are shorter (/Board/), so chip-rows-narrow now shows two chips sharing a row as well as wrapping, in light and dark.
    - 4: AgentAuthView keeps one `symbol` for the title and each Sign In button; SymbolConceptTests reads it.

    ### implement — changed
    - evidence: commit ecfe4825, 6 files; `swift test` 969 + 60 passed; `swift test --package-path IntegrationTests` 945 passed (5 known issues are FontRoleExpectationsTests' deliberate negative checks); ScreenshotTests capture 25 passed; zero warnings in AVK targets
    - next: main fast-forwards to ecfe4825
  timestamp: 2026-11-05T12:27:34.594592+00:00
position_column: done
position_ordinal: ffffffa180
title: Delete AgentViewKitStyle SharedSymbol once EditorSymbol has the generic names
---
**Blocked** on EK's card that adds SharedSymbol's missing names to `EditorSymbol` (editorkit-b5, 2026-11-04):
- severity: error, warning, information
- closed
- file changes: added, deleted, modified, renamed, copied, binary, document
- actions: reload, dismiss, link, disclosure

The SF Symbol names stay the same, the tones are themed, and tool kinds reuse EditorSymbol's existing cases. editorkit-b5 sends the SHA.

## What
- Move every AVK use of `SharedSymbol` onto `EditorSymbol` and `EditorSymbolImage`.
- Delete `Sources/AgentViewKitStyle/Symbols/SharedSymbol.swift` and its DocC entries.
- `DiffFileChip.symbolName(for:)`: deleted by ^hpxbqhx (no kit calls it at SVK e9fb54f, KVK a87351a, Testudo 2bd4341). It did not move to `EditorSymbol.FileKind(location:)`, which maps a URL to folder/document, not a diff change: SVK's test uses AVK's `EditorSymbol.FileKind(_ operation:)` extension, which stays until EK has its own diff-operation initializer.

## Sequencing (no shims)
Before pushing the removal, grep the origin mains of KVK, SVK and Testudo for `SharedSymbol` and `symbolName(for:` with no truncation. At 2026-11-04, SVK b5d1e8a used SharedSymbol in 10 files plus its own `SharedSymbol+Timeline` extension, and KVK 701a93d in 7. Wait for each kit's SHA that moves off it.

## Acceptance Criteria
- [ ] AVK has no SharedSymbol.
- [ ] Every symbol AVK draws comes from EditorSymbol, with themed tones.
- [ ] The review gallery shows the banners, file chips and action buttons, light and dark.

## Tests
- [ ] The full AVK test suite is green, with zero warnings in AVK targets.

## Review Findings (2026-11-05, merge b8a468dc)
- [x] IntegrationTests/Tests/IntegrationTests/Status/StatusTitleLineHostedTests.swift:70 reuse — `action` builds the same "Reload" button as `StatusBarTests.action(hint:)`, differing only in the identifier. Make one shared test helper that takes the identifier, and call it from both suites.
- [x] IntegrationTests/Tests/IntegrationTests/Style/StatusBarTests.swift:133 reuse — `aBarWithNoExplanationShowsNoExplanationLine` builds its message inline. Give `message(_:)` an optional `explanation` parameter that defaults to "Explanation", and call `Self.message(.neutral, explanation: "")`.
- [x] ScreenshotTests/Tests/ScreenshotTests/ChipRowsGalleryFixtures.swift:30 magic-numbers — replace the magic numbers with named constants.
- [x] Sources/AgentViewKit/Connections/AgentAuthView.swift:102 reuse — `signInSymbol` repeats `symbol` (AgentSymbol.signIn). Keep one constant.