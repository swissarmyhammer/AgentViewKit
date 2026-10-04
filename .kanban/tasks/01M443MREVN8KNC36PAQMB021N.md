---
assignees:
- claude-code
depends_on:
- 01M443JA9M77PZH4YN3ED04XQ2
- 01M443M8BHM2BDPPZ2FVDA5TFV
position_column: todo
position_ordinal: '9180'
title: Write the decision record "AgentViewKit is an ACP client kit" and update the dependency and ACP version records
---
## What
Record the new scope and mark the records that are no longer current. Source: update.md §2, §10 items 2, 4, 7. Write all text in ASD-STE100 Simplified Technical English. The ACP version record (`acp-version.md`) changes in the second pin move task, because the pins stay at alpha.3 until then.

- [ ] Add `Docs/decisions/acp-client-kit.md`: "AgentViewKit is an ACP client kit". Give the reasons of update.md §2 (the Transcript gaps, the Router coupling from commit `5200485`, research item R5 with no task, the Router `turn` API break). Give the owner decisions: one product, keep Textual and swiftui-math, remove branches, checkpoints, subagents and compaction markers, no trace context now.
- [ ] Change `Docs/decisions/dependencies.md`: the direct dependencies are FoundationModelsACPClient, FoundationModelsACP, EditorKit, Textual and swiftui-math. FoundationModelsExtras stays only as a dependency of FoundationModelsACPClient.
- [ ] Mark as not current, with one line that points to the new record: `subagent-source.md`, `checkpoints.md`, `usage-model.md`, `branches.md`, `compaction-ux.md`. Remove the Router column of `attachment-types.md`.

## Acceptance Criteria
- [ ] The new record exists, and each of the five old records has the "not current" line.
- [ ] `dependencies.md` does not list FoundationModelsRouter as a direct dependency.

## Tests
- [ ] Add `Tests/PackageStructureTests/DecisionRecordTests.swift`: assert that `Docs/decisions/acp-client-kit.md` exists, that `dependencies.md` does not list FoundationModelsRouter as a direct dependency, and that each of the five old records has the "not current" line.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.