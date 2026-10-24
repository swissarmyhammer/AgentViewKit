---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5nw5qzea5te72az1yemd3xd
  text: |-
    BLOCKED on EditorKit ^aqqd6sb (filed by editorkit-28, 2026-10-23); breaking change. Shape:
    - `FontFace` (family: String?, design: Font.Design, size: CGFloat?) with `font(_ style: Font.TextStyle = .body) -> Font`: no family gives `.system(style, design:)`; a family gives `.custom(family, size:, relativeTo: style)`; statics `.system` and `.monospaced`.
    - Theme requirements become `uiFace` / `displayFace` / `codeFace`; extension `face(for:)` and `font(for: role, style: = .body)`; `uiFont` / `displayFont` / `codeFont` are derived only (the face at .body).
    AVK work when it lands: Theme conformers (DistinctRolesTheme, EnlargedRoleTheme, maybe AgentTheme) set faces; route the ~60 `.caption`/`.headline`/`.callout` sites to `theme.font(for: .ui, style: …)`; extend FontRoleTests to forbid a bare system text style in a view.
    Asked editorkit-28 to land it via a hold branch: AVK adapts against the SHA, then EditorKit pushes, so a fresh resolve never breaks.
  timestamp: 2026-10-24T02:34:55.854965+00:00
position_column: todo
position_ordinal: b480
title: Chrome text styles (.caption, .headline, .callout) do not follow a custom uiFont
---
Found while doing ^p6e0v5w. The kit draws its smaller and larger chrome text in SwiftUI text styles (`.font(.caption)`, `.headline`, `.callout`, about 60 sites in Sources/AgentViewKit), as the EditorKit chrome does (palette, completion popup, tag chips). With the default themes this is the ui role, because `ThemeRoleDefaults.uiFont` is the system font. But a theme that sets `uiFont` to another family (a Zed `ui_font_family`, for example) changes only the body-size chrome that reads `editorTheme.uiFont`; a caption or a headline stays in the system font. A SwiftUI `Font` cannot be re-styled to another text style, so AVK cannot derive "uiFont at caption" by itself.

Needs an EditorKit API first, for example `Theme.uiFont(_ style: Font.TextStyle) -> Font` (or a family on the role) so a host chrome can ask for the ui role at a text style. Then route the AVK text-style sites through it and extend `Tests/PackageStructureTests/FontRoleTests.swift` to forbid a bare system text style in a view.

#avk-8 #cross-repo