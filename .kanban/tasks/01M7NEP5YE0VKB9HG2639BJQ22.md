---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7neqme8mbvqgpbg5bam18ee
  text: 'Decision from testudoapp-75 (user rules, D193 (f)): option (ii) with no Copy button. "Copy Code Block" is a command at the scope of the focused code block, in the context menu and the palette. The header is a borderless label (language or file name) with no controls. Requested from editorkit-7a: a fence decoration hook and a code-block scope. BLOCKED until EditorKit gives both.'
  timestamp: 2026-11-17T19:11:25.640953+00:00
position_column: todo
position_ordinal: '8180'
title: 'AVK-9.2: Code fences in chat Markdown render through EditorKit (decision needed on CodeBlockView chrome)'
---
D185. EditorKit renders fences in the rendered text layout. Then `EditorKitCodeBlockStyle` and its `Mirror` read of the private Textual `CodeBlockProxy` go away.

Open decision (ask testudoapp / the user before the start): EditorKit has no host block-widget hook. The header, the file name, the Copy button and `CodeBlockModelCache` of `CodeBlockView` are lost in chat Markdown, unless EditorKit adds a block-widget hook for fences. editorkit-7a offered to add one if we give the use case.

Acceptance: unit tests; update CodeBlockViewHostedTests (compile only).

#avk-9