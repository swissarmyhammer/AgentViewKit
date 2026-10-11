---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4nqefatw5gc8846137ff15n
  text: '2026-10-11: The EditorKit work was sent to the EditorKit session (editorkit-c9): a system theme from Apple system colors as the fallback in place of `DefaultTheme.dark`, and color roles for status (running, completed, failed, cancelled, pending), severity (info, warning, error) and accent. That session will send back the commit and the final API names. This card waits for that commit.'
  timestamp: 2026-10-11T14:56:37.210582+00:00
position_column: todo
position_ordinal: '8580'
title: Make the EditorKit theme the theme of the kit
---
## What
Decision of the owner (2026-10-11): EditorKit themes are the themes of AgentViewKit. There is one theme: the EditorKit `Theme`. The kit does not keep its own color system next to it. EditorKit must have an Apple system default theme (separate work in the EditorKit repository).

Today `AgentTheme` has its own colors (`accent`, `statusColors`) and fonts, and `AgentTheme.editorTheme` (`Sources/AgentViewKit/Theme/AgentTheme+EditorKit.swift:28-71`) is a bridge that sends only the accent and the code font to EditorKit. The editor colors come from the kit copy `AgentTheme.EditorSystemColors`. All captures get one color, so the code has no syntax colors. The diff bands use the fixed EditorKit diff colors, but the `+N/−N` counts use `statusColors` (`Diff/DiffView.swift:240`, `:242`). EditorKit falls back to `DefaultTheme.dark` (fixed hex) when no theme is set.

## Work
- [ ] When EditorKit has its Apple system default theme (and the color roles that the kit needs, see below), move the EditorKit pin to that revision.
- [ ] The kit reads each color from the EditorKit theme in the environment (`\.editorTheme`): accent (`tokenTint`), the status colors, the diff colors, the editor background, foreground, selection and bars. Remove `accent`, `statusColors` and `EditorSystemColors` from `AgentTheme`, and remove the bridge `AgentEditorTheme`. Do not keep a kit copy of a color. If a color role that the kit needs (for example running, completed, failed, cancelled, pending, warning) is not in the EditorKit `Theme` protocol, record it for the EditorKit work; do not add it to the kit.
- [ ] Decide what stays in `AgentTheme`: only the layout tokens that EditorKit does not have (spacing, radii, density, material level, symbol weight). Fonts come from the EditorKit theme where it has them.
- [ ] Each EditorKit host uses the theme from the environment, with no override: `Code/CodeBlockView.swift:83`, `Input/EditorKitPromptEditor.swift:95`, `Diff/DiffRendererSlot+EditorKit.swift:74`, `Terminal/TerminalView.swift:180`, `Content/CommandOutputView.swift:180`, `Elicitation/ElicitationFieldViews.swift:224`. The frames and bars (`Code/CodeBlockView.swift:77`, `:116`, `Terminal/TerminalView.swift:174`, `:224`, `Content/CommandOutputView.swift:174`, `:217`) read the theme.
- [ ] The diff counts and the diff bands use the same diff colors of the theme.
- [ ] `Attachments/AttachmentPreview.swift:206` uses `EditorKitCodeBlockStyle`.
- [ ] Tests: a custom EditorKit theme changes the status, diff, frame and accent colors of the kit views. Update `AgentThemeTests`, `AgentThemeGoldenTests` / `DefaultTokens.json` and `StatusColorsTests`.
- [ ] README: a theme section ("set an EditorKit theme with `.editorTheme(_:)`"). Demo: set a theme. Update `plan.md` and `Docs/decisions/visual-audit.md` where they describe the kit colors.