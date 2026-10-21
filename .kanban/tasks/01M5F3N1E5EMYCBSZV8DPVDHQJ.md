---
assignees:
- claude-code
position_column: todo
position_ordinal: b480
title: AVK-11 Make the attachment actions EditorKit commands in the scope of the attachment (D108)
---
Source: testudoapp-4c, after AVK-10 (^0svs7g7). Rules D108 and D109: each UI action is an EditorKit command that the palette can run.

Problem: the attachment actions Open, Reveal in Finder, Share, Save and Quick Look are plain SwiftUI buttons in `AttachmentActions` (Sources/AgentViewKit/Attachments/AttachmentActions.swift). They are not EditorKit commands, so the palette cannot run them and the context menu does not show them from the command system.

Do:
- Add a scope kind for an attachment, with the kit prefix (D105, for example `agentAttachment`), and give the live attachment as the subject (`.commandScope(segment:subject:)`), as AVK-7b (^bghprs8) did for messages and requests. Add it on each attachment chip, image and the inspector view.
- Add the five commands (Open, Reveal in Finder, Share, Save, Quick Look) as `agent.*` verbs that read the attachment with `@FromTarget`. Put them in a command group (AVK-7e, ^mafqm8q), give each an icon, a title in Localizable.xcstrings, and a menu and context menu placement (AVK-1).
- The buttons in `AttachmentActions`, the context menu and the palette all run the same commands. Remove the button-only actions.
- This works in both inspector modes of AVK-10: `.builtIn` and `.host($selection)` (the host shows `AttachmentInspector` in its own inspector).
- Keep each command available only when it can run (for example Reveal in Finder only for a file URL).

Acceptance:
- Headless tests: each command is in `definitions(at:)` at an `agentAttachment` path, and is not available at other paths; `contextMenuMirror(at:)` shows them; a run of each command does its action on the subject (use test doubles for the workspace and the share/save/Quick Look services, so no real UI opens).
- A hosted test: a press on each button in the inspector runs the command (the recorder of the test double gets the call), in `.builtIn` and in `.host` mode.
- No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-11