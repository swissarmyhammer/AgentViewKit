---
assignees:
- claude-code
position_column: todo
position_ordinal: b480
title: Chrome text styles (.caption, .headline, .callout) do not follow a custom uiFont
---
Found while doing ^p6e0v5w. The kit draws its smaller and larger chrome text in SwiftUI text styles (`.font(.caption)`, `.headline`, `.callout`, about 60 sites in Sources/AgentViewKit), as the EditorKit chrome does (palette, completion popup, tag chips). With the default themes this is the ui role, because `ThemeRoleDefaults.uiFont` is the system font. But a theme that sets `uiFont` to another family (a Zed `ui_font_family`, for example) changes only the body-size chrome that reads `editorTheme.uiFont`; a caption or a headline stays in the system font. A SwiftUI `Font` cannot be re-styled to another text style, so AVK cannot derive "uiFont at caption" by itself.

Needs an EditorKit API first, for example `Theme.uiFont(_ style: Font.TextStyle) -> Font` (or a family on the role) so a host chrome can ask for the ui role at a text style. Then route the AVK text-style sites through it and extend `Tests/PackageStructureTests/FontRoleTests.swift` to forbid a bare system text style in a view.

#avk-8 #cross-repo