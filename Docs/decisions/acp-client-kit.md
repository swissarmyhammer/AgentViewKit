# AgentViewKit is an ACP client kit

Status: decided. Source: update.md §1, §2, §3 and §10. Task ^qmb021n.
Date: 2026-10-05.

This file records the scope of the kit. `DecisionRecordTests` in
`Tests/PackageStructureTests/` reads the title line of this file. Keep the
title line.

## Decision

AgentViewKit is the SwiftUI view kit to make the UI of an ACP client. It shows
the client-side ACP objects and types. It does not keep its own session state.
The views bind to the observable models of FoundationModelsACPClient:
`ConnectionModel` and its `SessionModel` objects.

A FoundationModels agent or a Router agent reaches the kit as an ACP agent:

```
LanguageModelSession / Router  ->  FoundationModelsACPAgent  ->  ACP  ->  ACP client  ->  AgentViewKit
```

The agent can run in a subprocess, or in the same process through
`InMemoryTransport.pair()`.

## Reasons

1. **A FoundationModels `Transcript` has gaps.** The first plan (June 2026,
   commit `82547cd`) showed a `Transcript`. A `Transcript` has no
   elicitation, permission request, plan, terminal, config option, slash
   command, authorization, session state or stop reason. ACP has all of
   these.
2. **The kit was coupled to the Router.** The plan rewrite of 2026-09-08
   (commit `5200485`, `plan-review.md`) filled these gaps with Router types:
   `SessionEvent`, `SessionProjection`, `OperationEvent`,
   `PersistableStructuredSegment` and `RouterSegmentSchemaNames`. It made
   `AgentViewKitRouter` a product. But `RouterSegmentSchemaNames` and
   `PersistableStructuredSegment` are internal to the Router, so there was
   no public contract to agree with. The Router target also did not use the
   `transcript` property of the Router correctly: a seeded Router thread
   showed no user messages.
3. **Research item R5 had no task.** R5 (the runtime contract) was to examine
   the Router decision. Nobody did this work, because R5 did not get a task.
4. **Each Router update breaks the kit.** The Router update of 2026-10-01
   (251 commits) removed the `turn` API and broke `AgentViewKitRouter`.

ACP is the correct layer. It defines all of the agent surfaces that the kit
shows, and the ACP packages hold them as client-side state.

## Owner decisions

The owner made these decisions on 2026-10-02:

- **One product.** The package has one library product and one library
  target, `AgentViewKit`. The `AgentViewKitACP` target is merged into it.
  The `AgentViewKitFoundationModels` and `AgentViewKitRouter` targets are
  removed.
- **Keep Textual and swiftui-math.** Textual renders Markdown, and
  swiftui-math renders math. They stay as UI dependencies.
- **Remove branches, checkpoints, subagents and compaction markers now.** ACP
  has no producer for them. Add them again when ACP gives a producer.
- **No trace context now.** The kit does not send `_meta.traceparent`.

The owner also decided on 2026-10-04 to show the `CompactionEntry` rows and
the `SessionNotice` banners of the client model.

## Dependencies

The direct dependencies are FoundationModelsACPClient, FoundationModelsACP,
EditorKit, Textual and swiftui-math. `Docs/decisions/dependencies.md` gives
the table. FoundationModels, FoundationModelsRouter and FoundationModelsExtras
are not direct dependencies. FoundationModelsExtras stays in the package
graph only because the library target of FoundationModelsACPClient depends
on it.

## Records that are not current

These records describe the earlier scope. Each one has the line
"Not current" that points to this file:

- `Docs/decisions/subagent-source.md`
- `Docs/decisions/checkpoints.md`
- `Docs/decisions/usage-model.md`
- `Docs/decisions/branches.md`
- `Docs/decisions/compaction-ux.md`

`Docs/decisions/attachment-types.md` does not name the Router as a source.
