---
assignees:
- claude-code
depends_on:
- 01M44449VVAEJBQER0A71K836Q
- 01M443RTQWKFHNWK4SH96PTE46
- 01M443S0EDEB23N7RPAR39TGZ5
position_column: todo
position_ordinal: a580
title: Rewrite plan.md, the remaining decision records and the README for an ACP client kit
---
## What
Make the documents agree with the built kit. Source: update.md §10 items 1, 3 and 6. Write all text in ASD-STE100 Simplified Technical English.

- [ ] `plan.md`: rewrite §1 (the sources: one ACP client), §3 (the model is `ConnectionModel` and `SessionModel` of FoundationModelsACPClient), §11 decisions 1 and 5, §13 (elicitation through the pending requests of the models), §14 R5, R13, R14 and R17.
- [ ] Change `Docs/decisions/required-thread-actions.md`, `accessibility.md` and `permission-ux.md` where they refer to `AgentThread`, the Router or the kit pending requests.
- [ ] Change `Docs/decisions/connection-states.md`: the states are `ConnectionModel.state`.
- [ ] `README.md`: describe AgentViewKit as the SwiftUI kit for an ACP client; list the dependencies; point to the two quick starts. Run `Scripts/check-readme.sh`.
- [ ] Delete `update.md` when all its items are on the board or done.

## Acceptance Criteria
- [ ] No document in `Docs/`, `plan.md` or `README.md` names `AgentThread`, `AgentViewKitRouter` or `AgentViewKitFoundationModels` as a current part of the kit.

## Tests
- [ ] Extend `Tests/PackageStructureTests/DecisionRecordTests.swift`: scan `plan.md`, `README.md` and `Docs/decisions/*.md` (except the records marked "not current") and fail on the names `AgentThread`, `AgentViewKitRouter` and `AgentViewKitFoundationModels`.
- [ ] `swift test` and `Scripts/check-readme.sh` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.