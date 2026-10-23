---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5mqvekdz3bfcnqarzy23qdn
  text: 'Push coordination from testudoapp-2c (2026-10-23): message testudoapp-2c BEFORE pushing this card. EditorKit''s font-role push (^wg1hac2) has to land just before it, and Testudo will hold its own pushes during that window. Agreed order: ^8zmkh1a → ^2sg9taf → ^p6e0v5w → ^bkhgxs5.'
  timestamp: 2026-10-23T16:00:09.837251+00:00
- actor: claude-code
  id: 01m5na05kph5yg9hw7gw39x797
  text: 'From editorkit-28 (2026-10-23): EditorKit ^wg1hac2 (font roles) is held on branch hold/font-roles and will be rebased onto main, so its SHA will differ from fd08d2e. API: `FontRole`, `uiFont` / `displayFont` / `codeFont`, `font(for:)`, `.editorFontRole(_:)`; `editorFont` and `proseFont` are REMOVED. Build this card against that branch (or its rebased SHA) and don''t wait for main. When the card is ready, ping editorkit-28 and testudoapp-2c. editorkit-28 pushes ^wg1hac2 first and sends the SHA, then AVK bumps its EditorKit resolution to that SHA, and the AVK commit goes up after it. This card comes after ^xqday3k.'
  timestamp: 2026-10-23T21:17:18.838458+00:00
position_column: todo
position_ordinal: ae80
title: 'Use the theme font roles: display for the composer, inputs and prose; code for code; ui for chrome'
---
REQUIRES an EditorKit change: check EditorKit origin/main for the theme font roles (ui, display, code) and the EditorView / SingleLineField font-role choice first. If they're missing, record that the card is waiting, and stop. editorkit-28 will send the API before its push.

User decision (2026-10-23, relayed by testudoapp-2c): themes have three font roles: ui, display (content) and code. The user noticed the composer is monospace and wants it in the display role.

Map:
- display role: the composer (EditorKitPromptEditor), every SingleLineField (permission comment, session search, elicitation text fields; see ^8zmkh1a) and any in-place edit; transcript prose (MarkdownProse, TextBlockView, ParagraphView, message text).
- code role: code blocks (CodeBlockView), diffs (DiffView and the EditorKit diff renderer), tool output, command output and the terminal.
- ui role: buttons, chips, headers, the breadcrumb (^2sg9taf), banners, menus, the status bar and labels.

Work:
- After the EditorKit pin is bumped, route every font choice in Sources/AgentViewKit through the role (no hard-coded `.monospaced` or font names outside the code role).
- Replace AgentTheme / editorTheme font lookups with the roles where EditorKit owns them, and keep one source of truth.
- Add a structure test that fails if a view picks a font outside the roles (follow the existing PackageStructureTests patterns), and hosted tests that the composer and a SingleLineField use the display role and a code block uses the code role.
- Re-record the snapshots that change and list them by name; check the sizes.
- The full `swift test` must be green; the demo builds. Tell testudoapp-2c before pushing. #avk-8 #testudo-request #cross-repo