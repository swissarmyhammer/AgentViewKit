---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m46g1gfmdd6neb5vwt00x7a2
  text: |-
    Research:
    - update.md §2 gives the reasons, §3 gives the owner decisions D1 to D8, §10 items 2, 4 and 7 give the document work.
    - `dependencies.md` has rows for FoundationModelsRouter and FoundationModelsExtras, and a target table with `AgentViewKitFoundationModels` and `AgentViewKitRouter`. These targets do not exist now.
    - `attachment-types.md`: `AttachmentResolutionTests` reads the table with `MarkdownTable` and requires three cells for each row. Thus the Router part goes out of the "source support" cell; the table keeps three columns. The Router survey section goes out too.
    - `usage-model.md` is read by `ContextUsageTests` (merge table). One added line does not change the table.
    - `MarkdownTable` is in `Tests/AgentViewKitTests/Helpers/`. PackageStructureTests links only PackageFileSupport. Plan: move `MarkdownTable` into PackageFileSupport as public API, so that the new `DecisionRecordTests` reads the dependency table with the same parser and does not make a second parser.
  timestamp: 2026-10-05T16:58:35.892573+00:00
- actor: claude-code
  id: 01m46g93dfd5kc5wb44yjdet19
  text: |-
    ### implement — changed
    - evidence: new `Docs/decisions/acp-client-kit.md`; changed `Docs/decisions/dependencies.md` (Router and Extras rows out, AgentViewKitFoundationModels and AgentViewKitRouter target rows out, new section "The ACP packages"); "Not current. See `Docs/decisions/acp-client-kit.md`." line under the title of `subagent-source.md`, `checkpoints.md`, `usage-model.md`, `branches.md`, `compaction-ux.md`; Router part out of each "source support" cell and the Router survey section out of `attachment-types.md` (the table keeps three columns for `AttachmentResolutionTests`); new `Tests/PackageStructureTests/DecisionRecordTests.swift` (5 tests, 9 cases); `MarkdownTable` moved from `Tests/AgentViewKitTests/Helpers/` to `Sources/PackageFileSupport/MarkdownTable.swift` as public API, so that PackageStructureTests reads tables with the same parser; two comment lines in `Package.swift`.
    - TDD: `swift test --filter DecisionRecordTests` RED with 10 issues (no record, Router and Extras rows, Router cells, no "not current" lines), then GREEN 5 of 5.
    - Full `swift test`: 1274 tests, 1 issue in `ACPDemoSessionTests.eachTurnGivesANewReply()` (the second reply blocks were not complete). This test does not touch the changed files. `swift test --filter ACPDemoSessionTests` then passed 15 of 15. It is a timing race; recorded as new task ^xbr8qmh.
    - Not done here, by the card: `acp-version.md` (task ^sbncn28). README not changed, so `Scripts/check-readme.sh` was not run. The README line that names "the branches" decision belongs to the README rewrite task.
    - next: /review
  timestamp: 2026-10-05T17:02:44.655883+00:00
- actor: claude-code
  id: 01m46gh4z3hbz8b88y8sf661bm
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit 7a5a31f) — 0 findings (0 confirmed, 0 refuted, 7 attempted, 0 failed). The task had no earlier `## Review Findings` sections. No validator matched the eight `Docs/decisions/*.md` files. The engine did not read `Tests/AgentViewKitTests/Helpers/MarkdownTable.swift`, because this commit removed that file (it moved to `Sources/PackageFileSupport/MarkdownTable.swift`).
    - next: none — task moved to done.
  timestamp: 2026-10-05T17:07:08.387331+00:00
- actor: claude-code
  id: 01m46gh6c85gpb4n5yg9zbxthn
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — acp-client-kit.md (new); dependencies.md, attachment-types.md; five records marked not current; DecisionRecordTests (new); MarkdownTable moved to PackageFileSupport
    - test: green — swift test, 1274 passed (one earlier run had the race recorded as ^xbr8qmh)
    - commit: 7a5a31f
    - review: clean — 0 findings
  timestamp: 2026-10-05T17:07:09.832823+00:00
depends_on:
- 01M443JA9M77PZH4YN3ED04XQ2
- 01M443M8BHM2BDPPZ2FVDA5TFV
position_column: done
position_ordinal: e280
title: Write the decision record "AgentViewKit is an ACP client kit" and update the dependency and ACP version records
---
## What
Record the new scope and mark the records that are no longer current. Source: update.md §2, §10 items 2, 4, 7. Write all text in ASD-STE100 Simplified Technical English. The ACP version record (`acp-version.md`) changes in the second pin move task, because the pins stay at alpha.3 until then.

- [x] Add `Docs/decisions/acp-client-kit.md`: "AgentViewKit is an ACP client kit". Give the reasons of update.md §2 (the Transcript gaps, the Router coupling from commit `5200485`, research item R5 with no task, the Router `turn` API break). Give the owner decisions: one product, keep Textual and swiftui-math, remove branches, checkpoints, subagents and compaction markers, no trace context now.
- [x] Change `Docs/decisions/dependencies.md`: the direct dependencies are FoundationModelsACPClient, FoundationModelsACP, EditorKit, Textual and swiftui-math. FoundationModelsExtras stays only as a dependency of FoundationModelsACPClient.
- [x] Mark as not current, with one line that points to the new record: `subagent-source.md`, `checkpoints.md`, `usage-model.md`, `branches.md`, `compaction-ux.md`. Remove the Router column of `attachment-types.md`.

## Acceptance Criteria
- [x] The new record exists, and each of the five old records has the "not current" line.
- [x] `dependencies.md` does not list FoundationModelsRouter as a direct dependency.

## Tests
- [x] Add `Tests/PackageStructureTests/DecisionRecordTests.swift`: assert that `Docs/decisions/acp-client-kit.md` exists, that `dependencies.md` does not list FoundationModelsRouter as a direct dependency, and that each of the five old records has the "not current" line.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.