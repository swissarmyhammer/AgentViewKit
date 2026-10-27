---
assignees:
- claude-code
position_column: todo
position_ordinal: a880
title: AVK docs point to EditorKit/style.md as the one shared style guide (after EditorKit moves it)
---
User: "make sure we have unified style.md in editorkit i think, and that the other packages ARCHITECTURE.md clearly says use that style for editor, kanban, agent view … and testudo app".

EditorKit (editorkit-a9) is moving TestudoApp/features/style.md to `EditorKit/style.md`, and research-liquid-glass.md to `EditorKit/Docs/research-liquid-glass.md`, and bringing both up to date with the user's decisions. KanbanViewKit (kanbanviewkit-2c) and TestudoApp (testudoapp-5c) update their own docs.

## AVK work, after the EditorKit SHA lands
- [ ] ARCHITECTURE.md gets a clear "Style" section: AgentViewKit follows `../EditorKit/style.md`, the one style guide for EditorKit, KanbanViewKit, AgentViewKit and TestudoApp. AVK keeps no copy of its rules.
- [ ] Repoint every link to TestudoApp `features/style.md` and `features/research-liquid-glass.md`: plan.md:240, Docs/decisions/visual-audit.md:99, and any others `rg -n "features/style.md|research-liquid-glass"` finds.
- [ ] A package-structure test checks that ARCHITECTURE.md links ../EditorKit/style.md and that no doc links TestudoApp/features/style.md.
- [ ] `swift test` is green.

#cross-repo