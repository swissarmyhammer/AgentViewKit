---
comments:
- actor: claude-code
  id: 01m2nz7apdtr8ytzkqkv165y63
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — SessionSummary.swift, SessionListModel.swift, SessionListView.swift, ACPSessionList.swift, 2 new test files, ScriptedWireAgent gets resultQueues and bounded(_:)
    - test: green — swift test: 707 + 91 + 71 + 20 + 1 tests pass; only the accepted mlx warning
    - commit: bc77a8a
    - review: findings — Sources/AgentViewKit/Sessions/SessionListView.swift:182
    - decisions: SessionListModel is a public Observable model, so a host can set the search text or reload. The search field is a TextField in the header, not .searchable, because .searchable needs a toolbar container. The delete action is a row button (not a context menu), because menu items are not visible until the menu opens. ACPSessionList.delete(_:) sends session/delete; the host gives it to onDelete.
  timestamp: 2026-09-16T20:41:08.045242+00:00
- actor: claude-code
  id: 01m2nzacg55ecnmawhtzhzswcn
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — SessionListView.swift: rowLineSpacing and sectionSpacing constants
    - test: green — swift test: 707 + 91 + 71 + 20 + 1 tests pass; only the accepted mlx warning
    - commit: 3fd2cc1
    - review: clean — review sha HEAD~1..HEAD, 0 findings (7 validators attempted)
  timestamp: 2026-09-16T20:42:48.197162+00:00
depends_on:
- 01M21AGCKBQJRDAVFZD6Q9P7JZ
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: done
position_ordinal: a580
title: SessionListView with cursor paging over ACP session/list (plan §9 A)
---
## What
Create `Sources/AgentViewKit/Sessions/SessionSummary.swift`, `SessionListView.swift`, and `Sources/AgentViewKitACP/ACPSessionList.swift`, per plan.md §9 A.

- `SessionSummary { id, title, cwd, updatedAt }` in the core, source-neutral.
- `SessionListProvider` protocol: `func page(after cursor: String?) async throws -> (sessions: [SessionSummary], next: String?)`. The ACP target implements it over `session/list` with `cwd` and `cursor`.
- `SessionListView(provider:onSelect:)`: a `List` with title and relative updated time, a "load more" row that fetches the next page, and a search field that filters the loaded rows. New session and delete (`session/delete`) actions through closures.

## Acceptance Criteria
- [x] The first page renders; "load more" appends the second page and disappears when `next` is nil.
- [x] Selecting a row calls `onSelect` with the id.
- [x] The ACP provider sends `session/list` with the cursor from the prior response.

## Tests
- [x] `Tests/AgentViewKitTests/Sessions/SessionListViewHostedTests.swift`: two-page fake provider.
- [x] `Tests/AgentViewKitACPTests/ACPSessionListTests.swift`: cursor passthrough over the in-memory agent.
- [x] `swift test` exits 0 for both targets.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 15:38)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 8 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Sources/AgentViewKit/Sessions/SessionListView.swift:182` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
