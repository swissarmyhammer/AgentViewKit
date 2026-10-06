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
Make the documents agree with the built kit. Source: update.md §10 items 1, 3 and 6. Write all text in ASD-STE100 Simplified Technical English. Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient (`ConnectionModel`, `SessionModel`, the `TranscriptEntry` objects). A view shows what the model holds and calls the model methods. The kit keeps no parallel state, no copy of model data and no logic that the model owns (turn tracking, turn order, turn-gated queues, pending request lists, connection state, session list, usage or config copies). The documents must state this rule.

- [ ] `Docs/decisions/acp-client-kit.md`: add a "Binding rule" section with the rule above, the allowed view state (open state, scroll position, focus, selection, composer draft), and the host closures that stay (for work that no model gives).
- [ ] `plan.md`: rewrite §1 (the sources: one ACP client), §3 (the model is `ConnectionModel` and `SessionModel` of FoundationModelsACPClient, bound directly), §11 decisions 1 and 5, §13 (elicitation through the pending requests of the models), §14 R5, R13, R14 and R17. Remove the text about turn summaries, turn-gated queues and kit streaming copies.
- [ ] Change `Docs/decisions/required-thread-actions.md`, `accessibility.md` and `permission-ux.md` where they refer to `AgentThread`, the Router, the kit pending requests or kit turn tracking.
- [ ] Change `Docs/decisions/connection-states.md`: the agent connection states are `ConnectionModel.state`.
- [ ] `README.md`: describe AgentViewKit as the SwiftUI kit for an ACP client that binds to the observable models; list the dependencies; point to the two quick starts. Run `Scripts/check-readme.sh`.
- [ ] Delete `update.md` when all its items are on the board or done.

## Acceptance Criteria
- [ ] No document in `Docs/`, `plan.md` or `README.md` names `AgentThread`, `AgentViewKitRouter`, `AgentViewKitFoundationModels`, `TurnSummary` or `StreamingMessage` as a current part of the kit.
- [ ] `Docs/decisions/acp-client-kit.md` has the "Binding rule" section.

## Tests
- [ ] Extend `Tests/PackageStructureTests/DecisionRecordTests.swift`: scan `plan.md`, `README.md` and `Docs/decisions/*.md` (except the records marked "not current") and fail on the names `AgentThread`, `AgentViewKitRouter`, `AgentViewKitFoundationModels`, `TurnSummary` and `StreamingMessage`; and fail when `acp-client-kit.md` has no "Binding rule" heading.
- [ ] `swift test` and `Scripts/check-readme.sh` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.