---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7qeb4n4fhhcwvy2egn8zwbd
  text: |-
    The EditorKit API is on origin/main (editorkit-7a): feature commit 29db1752, head adee09b3. This task is not blocked now.

    API (Sources/EditorSwiftUI/EditorLabelForeground.swift):
    - `public enum EditorLabelForeground: Sendable, Equatable { case theme; case vibrant(EditorTextColorRole) }`. `.vibrant(.primary)` gives labelColor, and `.vibrant(.secondary)` gives secondaryLabelColor.
    - `extension View { public func editorLabelForeground(_ foreground: EditorLabelForeground) -> some View }`.

    Use: `EditorLabel(verbatim: "3 files changed").editorLabelForeground(.vibrant(.secondary)).padding().glassEffect()`.

    - The modifier applies to each EditorLabel below it, as `.editorLabelFont` does. It replaces the `editorTextColor(_:)` role.
    - A run that has its own color keeps that color.
    - On macOS, the label view returns allowsVibrancy true. Under SwiftUI glass or a material, AppKit gives it the vibrant appearance, so Increase Contrast and Reduce Transparency come from the system.
    - Content text keeps the theme colors (D110).

    Use it where AVK-9.5 now uses the plain NSColor.labelColor or secondaryLabelColor on glass or on a material.
  timestamp: 2026-11-18T13:43:05.124892+00:00
position_column: todo
position_ordinal: '8280'
title: Vibrant text for each EditorLabel on glass (D110)
---
TestudoApp decision (testudoapp-9a, 2026-11-18): text on glass is "vibrant" (D110: text on glass uses vibrant foreground styles). testudoapp-9a asked editorkit-7a for a vibrant role for `EditorLabel` on glass.

Now: keep `labelColor` and `secondaryLabelColor`. Do not change the labels before the EditorKit API is on main.

Do, when editorkit-7a sends the API commit:
- Update the EditorKit pin in the three packages.
- Use the vibrant role for each `EditorLabel` on glass or on a material: the card text, the status-bar explanation, and each other label on glass or on a material.
- Keep the theme colors for content text (message text, code, tool output).
- Add a unit test that each label on glass gets the vibrant role, and that content text keeps the theme color.
- Run `swift test`, push, and send the commit to testudoapp-9a.

Blocked: this task waits for the EditorKit API. Without it, this task is stuck.