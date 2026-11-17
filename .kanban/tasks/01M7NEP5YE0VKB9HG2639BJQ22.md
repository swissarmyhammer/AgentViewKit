---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7neqme8mbvqgpbg5bam18ee
  text: 'Decision from testudoapp-75 (user rules, D193 (f)): option (ii) with no Copy button. "Copy Code Block" is a command at the scope of the focused code block, in the context menu and the palette. The header is a borderless label (language or file name) with no controls. Requested from editorkit-7a: a fence decoration hook and a code-block scope. BLOCKED until EditorKit gives both.'
  timestamp: 2026-11-17T19:11:25.640953+00:00
- actor: claude-code
  id: 01m7nt9cas36st6hqck3dp1q50
  text: |-
    ### implement — changed
    - EditorKit main b7396d3 has the fence header hook and the code block scope.
    - RenderedMarkdownView: `.editorCodeBlockHeader` shows a borderless label: the file name, else the language, else nothing (`headerTitle(of:)`). No buttons.
    - New verb `AgentCommandVerb.copyCodeBlock` ("Copy Code Block"), group clipboard, Edit menu, context menu. The gate is `EditorCodeBlockScope.isInside`, so the palette and the context menu show it only in a code block. It copies `CommandContext.codeBlock.text`, or the payload `AgentCommandPayload.code(_:)`.
    - AVK copy of `EditorModel.syncStreaming(to:)` removed: EditorKit now has the same method, and the two names were ambiguous.
    - `swift test`: 1308 tests in 149 suites and 50 tests in 10 suites pass. IntegrationTests and ScreenshotTests compile. The hosted attachment test checks the header text ("json"), not run.
    - Not in this task: chat answers still render fences with CodeBlockView through Textual, until AVK-9.7. EditorKitCodeBlockStyle goes with AVK-9.8.
  timestamp: 2026-11-17T22:33:21.497311+00:00
position_column: done
position_ordinal: ffffffe180
title: 'AVK-9.2: Code fences in chat Markdown render through EditorKit (decision needed on CodeBlockView chrome)'
---
D185. EditorKit renders fences in the rendered text layout. Then `EditorKitCodeBlockStyle` and its `Mirror` read of the private Textual `CodeBlockProxy` go away.

Open decision (ask testudoapp / the user before the start): EditorKit has no host block-widget hook. The header, the file name, the Copy button and `CodeBlockModelCache` of `CodeBlockView` are lost in chat Markdown, unless EditorKit adds a block-widget hook for fences. editorkit-7a offered to add one if we give the use case.

Acceptance: unit tests; update CodeBlockViewHostedTests (compile only).

#avk-9