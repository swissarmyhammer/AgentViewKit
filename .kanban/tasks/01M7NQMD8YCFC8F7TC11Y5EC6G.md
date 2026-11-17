---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7nv9y0xpemzfwmfr78cfse2
  text: |-
    ### commit — changed
    - evidence: f60b266b (pushed after testudoapp-9a approved the API). `swift test` green; IntegrationTests and ScreenshotTests compile.
    - API: `ComposerMention`, `ComposerMentionSource(_ mentions: (body) async -> [ComposerMention])`, `.composerMentions(_:)`. Kit source `AtReferenceSource`: file rows, then mention rows, ranked.
  timestamp: 2026-11-17T22:51:08.189518+00:00
position_column: done
position_ordinal: ffffffe280
title: 'AVK-15.1: Host @ mention rows add to the @file rows'
---
D199 (TestudoApp/features/decisions.md, commit 740cd1a). Brief: .briefs/at-sessions/avk-brief-at-sessions.md, item 1.

Now a host `@` route turns `@file` off: `kitFileRoot` is nil when `PromptEditorSession.routes(routes, take: FileReferenceSource.trigger)` (Input/EditorKitPromptEditor.swift:409-411, :804-806). Then FileReferenceSource is not in the engine (:847-849).

Do:
- Add `ComposerMentionSource` (a provider of rows for the body after `@`) and the modifier `.composerMentions(_ sources:)`. Each row can carry a link `URL`.
- The `@` popup shows the FileReferenceSource rows first, then the rows of each mention source. A mention source does not set `kitFileRoot` to nil.
- `.composerCompletions` keeps its current rule. A host `@` route with no mention source keeps its documented behavior (Input/ComposerCompletions.swift:33-41).
- Send the API proposal to testudoapp before the push.

Tests (TDD, unit, Tests/AgentViewKitTests/Input/): the `@` engine with a file root and one mention source lists the file rows, then the mention rows; a mention source keeps FileReferenceSource; the old route tests stay green. Hosted test in IntegrationTests/.../Input/: type `@` and see both kinds of row (compile only, hosted runs are not permitted).

#avk-15