---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6gz2z636ye4w2cpwv9x3tne
  text: |-
    Adoption done in the tree (not committed). Built against client main e9b15fd and the local Agent working tree. Tests: swift test passes (848 tests in 91 suites, plus 68), 0 warnings.
    1 cancelled outcome: not used in the kit.
    2 AvailableCommand union: done. SlashCommandSource reads the .command payload and skips .unknown. Test added.
    3 ElicitationSchema: done (PreviewFixtures: type .object).
    4 ClientAuthCapabilities: done (KitInitializeRequest and its test).
    5 ToolCallStatus.paused: done. Label "Paused", symbol SharedSymbol.stalled, not live, no result, plain tick, pending color. New string in Localizable.xcstrings. No PNG snapshot was changed (no fixture shows a paused call).
    6 LineNumber: done (ToolCallView maps to Int for the chips).
    7 cost PatchField: done (ContextUsageView reads .value).
    8 non-ISO currency: done. costText shows "12 credits". Test added.
    9 cancelToolCall and cancelTerminal: not used. No kit agent conforms to Agent.
    10 MethodSide.proxy: not used.
    11 unstable method table: not used.
    12 null id: not used.
    13 new generated types: not used, no compile break.
    Client changes: Command name clash with EditorCommands.Command fixed by naming EditorCommands.Command at 3 struct declarations. New TranscriptEntry.sessionMessage: new SessionMessageView (sender, recipient, content); the activity timeline and the exporter give it no row. Build needs the Agent package alpha.13 changes, which were still uncommitted in its working tree (ACPEventTranslator, CommandRegistry); main at a794c58 does not compile with the new wire.
  timestamp: 2026-11-03T15:05:20.323803+00:00
position_column: done
position_ordinal: ffffff9380
title: Adopt the 13 wire breaks of the ACP schema re-vendor (alpha.13) in AgentViewKit
---
## What
FoundationModelsACP moves to schema-v2.0.0-alpha.13 (ACP card 01M6GJ8GX6C0YRHJW0W2ADAVTE). Start after that card is done and the client and agent packages build with it. Fix every compile error and test failure in AgentViewKit. Change all callers at once. Keep no shim. The list of breaks is in the comment of the ACP card. Check each one here:
1. `RequestPermissionOutcome.cancelled` holds a value: write `.cancelled(CancelledPermissionOutcome())`. Fix every place that makes or matches it (test support, demo agents, permission views).
2. `AvailableCommand` is a union with a `type` discriminator: write `AvailableCommand.command(Command(description:name:))`. Fix the command list views and fixtures. A command with an unknown `type` is `.unknown`; the views must show a sane result.
3. `ElicitationSchema` needs `properties` and `type`. The empty initializer is gone: use `ElicitationSchema(properties: .object([:]), type: .object)`. Fix elicitation fixtures and views.
4. `ClientCapabilities.auth` has the type `ClientAuthCapabilities`. `AuthCapabilities` is gone. There is also `AgentAuthCapabilities`.
5. `ToolCallStatus` has the new case `.paused`. Handle it in each switch with no default. It is not a final status. Decide how a tool row shows it (icon, label, accessibility label), and add it to the removal rule for linked children (not final).
6. `ToolCallLocation.line` has the type `LineNumber?` (1-based, `UInt32`). A wire value `0` gives `nil`. Fix the location views and fixtures.
7. `UsageUpdate.cost` has the type `PatchField<Cost>`. Fix fixtures and the usage views (omitted keeps the last cost, `null` clears it).
8. `Cost.currency` accepts any string, such as `credits`. Check that the usage views show a non-ISO unit.
9. `Agent` has the new requests `cancelToolCall` and `cancelTerminal` (default: method-not-found). Fix any kit agent or test agent that conforms to `Agent`. Wire a cancel action only if the client package gives one; otherwise write no new UI here.
10. `MethodSide` has the new case `.proxy`. Handle it in each switch with no default.
11. The unstable method table changed (`document/*` and `nes/*` are gone; new `auth/status`, `session/archive`, `session/unarchive`, `session/status`, `session/set_title`, proxy methods). Fix any use of the removed methods.
12. A request with `"id": null` gets an invalid-request error. Fix any test that sends a null id.
13. New generated types (`BackgroundWork`, `ElicitationFormMode` with a scope union, shards `Models10` and `Models11`). Fix any compile break from them.
Use `get diagnostics` or the compiler to find the real list. Some items may not touch the kit; mark each one "done" or "not used" in a comment on this card.

## Acceptance Criteria
- [ ] `swift build` and `swift test` pass with no warning.
- [ ] A comment on this card marks each of the 13 breaks as done or not used.
- [ ] A `.paused` tool call shows in the thread with a label and an accessibility label, and the PNG snapshot is updated (give the paths to the user).
- [ ] No shim and no deprecated alias is left.

## Tests
- [ ] Update the tests of permission outcome, available commands, elicitation, tool call status, locations, usage and cost for the new types.
- [ ] Run `swift test`. All pass. Keep the test rules in the memory of the project: no flaky test, no hang.

## Workflow
- Use `/tdd`: write failing tests first, then implement. #acp