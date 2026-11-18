---
assignees:
- claude-code
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