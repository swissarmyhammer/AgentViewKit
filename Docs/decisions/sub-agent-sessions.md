# Sub-agent sessions

Status: decided by the owner on 2026-11-03.

This record supersedes one part of `Docs/decisions/acp-client-kit.md`: the
line "Remove branches, checkpoints, subagents and compaction markers now".
Only the word "subagents" is superseded. Branches, checkpoints and
compaction markers stay as that record says.

## What the old removal meant

The removal of 2026-10-05 (done card `01M443JYXF`) deleted the kit types
`SubagentRun`, `SubagentSource`, `SubagentTreeView` and the thread method
`upsertSubagent`. Those types were a kit-side copy of data. The kit built the
tree from Router records, and ACP had no producer for it. The decision record
`Docs/decisions/subagent-source.md` is not current.

`RemovedVocabularyTests` lists `SubagentRun`, `SubagentSource`,
`SubagentTreeView` and `upsertSubagent`. That list stays. The new work must
not use these names, and it must not use any other name that starts with
`Subagent`.

## What is new

ACP v2 now gives a producer: a sub-agent is a child session. The client model
holds the tree, and the views only read it. The kit adds no parallel state
(see "Binding rule" in `acp-client-kit.md`).

The model is plain parent and child sessions. It is parent and child all the
way down. The kit has no rule for a number of levels. A test that uses a chain
of three sessions only picks a test size.

Names (all from FoundationModelsACPClient, none from the kit):

- `SessionModel.parent`, `children`, `ancestors`, `siblings`, `descendants`.
- `SessionModel.workState` and `SessionModel.needsAttention`.
- `SessionPathEntry`: one entry of a path from the root to a session.
- `SessionModel.startedByToolCallId` and the tool call entry property
  `childSession`.

The kit names for new types start with `Session` or `Child`, for example
`SessionBreadcrumb`. They never start with `Subagent`.

## Rules that the owner decided

1. **Shown session is view state.** Which session a window shows is state of
   the view (the host, or `AgentThreadView`). It is not model state. Two
   windows can show different sessions of one connection.
2. **After a resume, the view shows the root.** A child that needs the user
   shows through `needsAttention` on its ancestors and through a jump button
   in the banner.
3. **A child is unconfirmed until its first current snapshot.** After the
   resume response, a child is shown as unknown, and its controls are
   disabled, until the first current snapshot of that child arrives.
4. **Replay is history.** Everything that comes inside the replay phase is
   history: no attention marks and no notifications.
5. **A finished child is removed.** The client removes a child when its linked
   tool call has a final status. The link is `_meta.sah.agentRun` (wire card
   `01M6GP1QC785QS2BS3TNVMKT7A`). A child with no link stays until its parent
   closes.
6. **The `agents` tool row jumps to the child.** The `agents` tool row in the
   parent thread is a link to the child while the child exists. After the
   removal, the row stays as history and shows the result.
7. **A child that failed to restore** is shown as unknown, with a reason.
8. **Breadcrumb width rule.** The middle crumbs collapse when the path does
   not fit the width of the bar. This is a rule about width. It is not a rule
   about the number of levels.

## Public API break

`AgentThreadView.init(session:connection:sessionTitle:headerContextMenuPath:composer:)`
changes, because the header reads the `SessionModel` and not a title text.
The parameter `sessionTitle` is removed. `AgentInfoHeader.init(connection:sessionTitle:)`
changes the same way, and `DefaultThreadComposer` forwards the new form. The
kit keeps no shim (no backward compatibility, as for the earlier removals).

## Work

The cards carry the `subagents` tag. The old card
`01M6GJ1SEKFK6V5QFY3VST23R5` is split into four cards with `depends_on`.
They wait for the client model card `01M6GH6FH41C6VSFC3QRT8H1FS`, and for the
wire card `01M6GP1QC785QS2BS3TNVMKT7A`. Start no card without the owner's word.
