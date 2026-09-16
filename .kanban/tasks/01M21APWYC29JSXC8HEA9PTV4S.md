---
depends_on:
- 01M21AGCKBQJRDAVFZD6Q9P7JZ
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: doing
position_ordinal: '8180'
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