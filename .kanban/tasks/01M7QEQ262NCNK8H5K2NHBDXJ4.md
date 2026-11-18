---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7qf6t0wx921xsf3eb743085
  text: |-
    foundationmodelsacp-be: ACPMarkdown (D202) is on FoundationModelsACP main at 7e31ad0. This task still waits for the FoundationModelsACPClient adapter.

    Localized labels: `SessionMarkdown.Labels` is a struct of String fields: user, agent, thought, from, fromUserIn, to, unknownSession, plan, exitStatus, compacted, toolCall, terminal, image, audio, resource. It also has the nested structs toolCallStatus (pending, inProgress, paused, completed, failed, cancelled), toolKind (read, edit, delete, move, search, execute, think, fetch, switchMode, other), planItemStatus (inProgress, cancelled) and diffOperation (add, delete, modify, move, copy). Start from `Labels()`, and set each field from the string catalog of the kit.
  timestamp: 2026-11-18T13:58:11.740409+00:00
- actor: claude-code
  id: 01m7qfxe1k8dmx2waertqh1zqr
  text: |-
    foundationmodelsacpclient-1d: `SessionModel.markdown(options:)` is on FoundationModelsACPClient main at ae58bff. It is `@MainActor func markdown(options: SessionMarkdown.Options = .init()) -> String`. Import `ACPMarkdown` (FoundationModelsACP 7e31ad0) for `SessionMarkdown.Options`. A pending prompt, a failed prompt and a local request error are not in the document. A replay gives the same text as the live model.

    Still blocked: `exportFileName` and `exportFolder` are the next ACPClient task (01M7QEQ0JBJDRCNK00P3M450TV). foundationmodelsacpclient-1d sends the sha when it is on main. Start this task after that.
  timestamp: 2026-11-18T14:10:33.139063+00:00
position_column: todo
position_ordinal: '8380'
title: Export as Markdown… kit verb with a save panel (D202)
---
Brief: /Users/wballard/github/swissarmyhammer/.briefs/export-markdown/avk-brief.md and overview.md (testudoapp-9a, D202, TestudoApp commit 40450ab).

Blocked: this task waits for the FoundationModelsACPClient adapter on main (`SessionModel.markdown(options:)`, `exportFileName`, `exportFolder`, and the `ACPMarkdown` product of FoundationModelsACP). On 2026-11-18 ACPClient main is fe5bb44, without the adapter. Before that, this task is stuck.

Do:
- Update the ACPClient and ACP pins. At this time, think about `UserMessageEntry.sahMessage` and `SessionMessageEntry.sahMessage` (ACPClient 9257aa0) for AVK-15.5 (testudoapp-9a: optional, only with a pin update).
- Add `AgentCommandVerb.exportMarkdown`, id `agent.exportMarkdown`, title "Export as Markdown…" (string catalog). It is in the palette, and in the Session menu, group `agentThread`, order 1, after Copy Thread. It has no key. Its symbol is `square.and.arrow.down` through `EditorSymbol` or `AgentSymbol`.
- Enabled when the transcript has a wire entry. Else disabled, with the reason "The thread has no messages."
- Action: the text comes from `SessionModel.markdown(options:)` with `includeThoughts` false, the labels from the string catalog of the kit (`SessionMarkdown.Labels`), and the agent name when the kit knows it. Open `fileExporter` with `exportFileName` as the default name and `exportFolder` as the default folder (`fileDialogDefaultDirectory(_:)`). A failed save goes to `FileExportLog`.
- The Export button of `MessageActions` (Items/MessageActions.swift:159-166, :249-252) becomes the command button of `exportMarkdown` in an agent command scope, as Copy Thread is. With no scope, it runs the same action.
- The DocC page of the commands lists the verb.

Tests:
- Unit: the registry has `agent.exportMarkdown` with its title, Session menu group `agentThread` order 1, and no key. It is disabled with the reason for an empty transcript, and enabled after one agent message.
- Unit: the action makes the same text as `SessionModel.markdown(options:)` with the labels of the catalog (a fake model with scripted updates), and gives the default name and folder of the model.
- Hosted (IntegrationTests): compile only. Do not run it. The user runs the hosted suites.
- The tests of Copy Message, Copy Thread and the inspector stay green.

Push when `swift test` is green, and send the sha to testudoapp-9a.