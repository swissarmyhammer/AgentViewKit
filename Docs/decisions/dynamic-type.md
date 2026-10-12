# Dynamic Type

Status: decided. Source: plan.md §6, §14 research R11.
Task ^6vztrss. Date: 2026-09-17.

This file records how the line height of kit text changes with the Dynamic
Type size on macOS 27.

## Rule

Each font of the kit uses a text style. The prose font is the `proseFont`
role of the EditorKit theme in the `\.editorTheme` environment value. Its
default is `Font.body`. The code font is the `editorFont` role of the same
theme. Its default is `.system(.body, design: .monospaced)`. The EditorKit
editor draws its text in `editorFont` too (EditorKit 95ef6c4 and later), and
its row height is the row height of the resolved font.

The code text of each kit view uses `editorFont` as it is. The role has one
size, and a view does not change it. Thus a command, a working directory and
a URL do not use a caption or a callout size: they use the size of the theme
(task ^ctff8rk). No kit view uses a fixed monospaced font, such as
`.body.monospaced()` or `design: .monospaced`.
`Tests/PackageStructureTests/FixedCodeFontTests.swift` scans the views of the
kit and of the examples for such a font.

Two views set a point size, and both sizes come from a resolved text style:

- `MathView` resolves the environment font (default `.body`) and scales the
  math font from that size. When the engine cannot parse the source, the
  view shows the source in `editorFont`.
- `InlineCitation` measures the size of the text font of its run, and scales
  the digit font from that size.

Thus, when the platform scales a text style, the kit text scales with it.

## Probe

`Tests/AgentViewKitTests/Accessibility/DynamicTypeHostedTests.swift` is the
probe. It stays in the suite, so that a change in the platform or in
EditorKit makes the test fail. Then update this file and the values in the
test.

- The probe hosts a view in a window, with `.dynamicTypeSize(size)` on it.
- It measures the height of the view with one line and with eleven lines.
  The line height is the difference divided by ten.
- The sizes are `.large` (the default) and `.accessibility3`.

## Result

| View | `.large` | `.accessibility3` |
|------|----------|-------------------|
| `CodeBlockView` (EditorKit editor, `editorFont`) | 16.0 pt | 16.0 pt |
| SwiftUI `Text` with `.font(.body)` | 16.0 pt | 16.0 pt |

Before EditorKit 95ef6c4, the editor kept its own font metrics, and the code
block row was 18.0 pt. At 95ef6c4, the editor draws in `editorFont`, and the
default row (`defaultEditorLineHeight`) is the 16.0 pt row of the system
monospaced font at 13 pt on macOS.

The line height does not change for the code block. It also does not change
for a SwiftUI body text. On macOS 27, the `dynamicTypeSize` environment value
does not change the size of a text style. Thus the result for EditorKit is
the same as the result for SwiftUI text, and the kit has no scale error of
its own today.

## EditorKit follow-up

The EditorKit editor does not scale with the Dynamic Type size in the probe.
The probe cannot show if EditorKit reads the `dynamicTypeSize` environment
value, because SwiftUI text also does not scale on macOS 27.

Follow-up for EditorKit (the orchestrator asks the EditorKit peer): make
sure that the editor resolves the font of its theme with the
`dynamicTypeSize` of the environment, and lays out the text again when that
value changes. This work has an effect only when macOS scales text styles
with Dynamic Type. The probe test then shows the change.
