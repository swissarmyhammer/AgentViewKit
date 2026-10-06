---
assignees:
- claude-code
depends_on:
- 01M443Q580KBFG7JE5M6A6X9X9
- 01M48MR5W3YAB8VFA4KTJZVCYN
position_column: todo
position_ordinal: ac80
title: Show the permission and elicitation cards from the pending request values of the models, with no kit request copy and no answered flag
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. The kit keeps no copy of the pending requests. The cards still take the kit request types, so the session path converts each model request to a kit copy:

- `LinkedElicitations` in `Sources/AgentViewKit/Items/ToolCallView.swift` converts each `PendingElicitation` with `SessionUpdateMapping.elicitationRequest` (kit `ElicitationRequest`).
- `Sources/AgentViewKit/HumanInTheLoop/PendingRequestReplies.swift` converts the answer with `SessionUpdateMapping.wireJSON` before `acceptElicitation(_:content:)`.
- `Sources/AgentViewKit/Elicitation/ElicitationCard.swift` takes a kit `ElicitationRequest`.
- `Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift` takes a kit `PermissionRequest`, and keeps `@State isAnswered`, a second record of "this request has an answer". The model removes the request from `pendingPermissions` when the user selects an option, so the model already holds that fact.

Do this task after the pending request binding task, which owns these files now.

- [ ] `ElicitationCard`, `ElicitationView` and `ElicitationURLConsentView` take a `PendingElicitation` (the request, its `id`, `url`, `toolCallId`) directly. The form answer goes to `acceptElicitation(_:content:)` as ACP `JSONValue`, with no `SessionUpdateMapping` call.
- [ ] `PermissionView` takes a `PendingPermissionRequest` directly and calls `selectPermission(_:option:)` or `cancelPermission(_:)` on the model that owns it. Remove `isAnswered`. The card goes away because the model removes the request.
- [ ] `LinkedElicitations` passes each `PendingElicitation` of `SessionModel.pendingElicitations` whose `id` is in `ToolCallEntry.linkedElicitationIDs` to the card, with no conversion.
- [ ] No file of this task calls a `SessionUpdateMapping` function.

## Acceptance Criteria
- [ ] A `session/request_permission` from the scripted agent shows a card. A select sends the response frame, and the card goes away when the model removes the request.
- [ ] A linked elicitation shows in its tool call row. Accept, decline and cancel each send the matching response frame.
- [ ] When the model cancels a pending request (for example at session close), the card goes away with no user step.
- [ ] `rg "SessionUpdateMapping|isAnswered" Sources/AgentViewKit/HumanInTheLoop Sources/AgentViewKit/Elicitation Sources/AgentViewKit/Items/ToolCallView.swift` finds nothing.

## Tests
- [ ] `Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift`: add a test that `cancelAllPending()` on the model removes the shown cards; a test that a select removes the card through the model.
- [ ] `Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift`: a linked elicitation card from a `PendingElicitation`; accept sends the frame with the ACP content.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.