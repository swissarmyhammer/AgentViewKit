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

## Host hooks

The owner decided on 2026-10-06 that each view of the kit binds directly to
`ConnectionModel`, `SessionModel` and the `TranscriptEntry` objects of the
transcript. The kit keeps no parallel session state and no turn logic. Task
^gzj5cye removed the old kit session model: `AgentThread`, `ThreadItem`,
`ThreadChange`, `ItemPatch`, the record types, `StreamingMessage`,
`StreamingCoalescer`, `ComposerTurn`, the `AgentThreadActions` protocol and
the `actions:` parameter of `AgentThreadView`.

The host gives the kit only these two environment values. The models do not
have this behavior:

- `terminalAuthRunner`: runs the `terminal` auth methods of the agent.
  `AgentAuthView` shows a Run button only when the host gives this value.
- `agentReconnect`: connects to the agent again after a terminal sign-in.
  `AgentAuthView` shows a Reconnect button that calls it while `authState`
  is `.reconnectRequired`.

Each other verb of the views calls the models: a prompt, a cancel, a
permission answer, an elicitation answer, a config option and a resume.

## ACP values in the views

Task ^71k836q removed the kit copies of the ACP value types: `JSONValue`,
`ContentBlock` and its parts (`Annotations`, `Audience`, `ImageContent`,
`AudioContent`, `ResourceLink`, `ResourceIcon`, `EmbeddedResource`),
`ThreadState` with its `StopReason`, `SlashCommand`, `ConfigOption` with
`ConfigValue`, `SelectOption`, `SelectGroup` and `SelectChoices`,
`ContextUsage`, `PatchField` and `WireValueEnum`. Earlier tasks removed the
kit `ToolKind`, `ToolCallStatus`, `PlanEntry`, `AuthMethod` and
`SessionSummary`. The views read the ACP values of FoundationModelsACP that
the client models hold. No kit function converts an ACP value to a kit value
of the same meaning. `RemovedVocabularyTests` fails when a source of the kit
declares a type with the name of one of these ACP types.

The kit adds members to the ACP `JSONValue` in an extension
(`JSONValue+Members.swift` and `ACPJSONText.swift`): parse, encode,
subscripts, scalar readers and JSON text. An extension is not a copy.

The kit keeps these types, because a view needs a value that ACP does not
define:

| Type | Reason |
|---|---|
| `UserInput` | The draft of the composer: the text and the URLs of local files. ACP has no value for a draft. The composer makes the ACP content blocks from it when it sends the prompt. |
| `Identifier`, `AttachmentID`, `ToolToggleID` | Typed ids for kit view state: the attachments of the composer and the tool toggles. ACP has no such values. |
| `ISO8601Time` | Reads the time text of ACP values. It holds no value. |
| `ElicitationFieldSchema` | The control kind of one form field, normalized from the four choice encodings of the requested schema. ACP has no single value for a control. Each choice is the ACP `EnumOption`. |

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
- `Docs/decisions/required-thread-actions.md`

`Docs/decisions/attachment-types.md` does not name the Router as a source.
