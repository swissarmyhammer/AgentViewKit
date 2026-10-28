---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m61dk957ah51sg66yp30a5xb
  text: |-
    ### review — clean
    - evidence: review sha c43ef30~1..c43ef30 — counts findings 0, confirmed 0, refuted 0 (7 attempted, 0 failed); 24 files reviewed, 3 Markdown files matched no validator (ARCHITECTURE.md, Docs/decisions/visual-audit.md, plan.md). The code-hygiene tool rules (disallowed-constructs, function-length, idioms, magic-numbers, missing-docs; all -swift) declined Sources/AgentViewKit/Status/StatusBar.swift and Tests/PackageStructureTests/StyleGuideLinkTests.swift because they read the main working tree, where those files are absent. All four acceptance items checked against c43ef30; swift test in the worktree reported 2169 tests, 0 failures.
    - next: none; card moved to done.
  timestamp: 2026-10-28T14:11:03.975079+00:00
- actor: claude-code
  id: 01m61dm0sa1aenavh1m1d7jyq8
  text: |-
    ### finish iteration 1 — held in review (moved back from done)
    - implement, test and commit: c43ef30 on worktree branch wt/style-docs. Full swift test passed 2169 tests, 0 failures; 1 skip, worktree only (demo project not generated); 1 mlx-swift_Cmlx warning (card filed).
    - review: 0 findings, but five Swift hygiene rules read the main working tree and skipped StatusBar.swift and StyleGuideLinkTests.swift. The review isn't complete.
    - Moved back to review: the code isn't on main yet. Next: merge wt/style-docs into main once main is clean (after ^qpbamj2 commits), resolve the StatusBar.swift comment conflict (main moves that file into AgentViewKitStyle), then re-review the merged commit in main.
  timestamp: 2026-10-28T14:11:28.170212+00:00
position_column: review
position_ordinal: '8380'
title: AVK docs point to EditorKit/style.md as the one shared style guide (after EditorKit moves it)
---
User: "make sure we have unified style.md in editorkit i think, and that the other packages ARCHITECTURE.md clearly says use that style for editor, kanban, agent view … and testudo app".

EditorKit (editorkit-a9) is moving TestudoApp/features/style.md to `EditorKit/style.md`, and research-liquid-glass.md to `EditorKit/Docs/research-liquid-glass.md`, and bringing both up to date with the user's decisions. KanbanViewKit (kanbanviewkit-2c) and TestudoApp (testudoapp-5c) update their own docs.

## AVK work, after the EditorKit SHA lands
- [x] ARCHITECTURE.md gets a clear "Style" section: AgentViewKit follows `../EditorKit/style.md`, the one style guide for EditorKit, KanbanViewKit, AgentViewKit and TestudoApp. AVK keeps no copy of its rules.
- [x] Repoint every link to TestudoApp `features/style.md` and `features/research-liquid-glass.md`: plan.md:240, Docs/decisions/visual-audit.md:99, and any others `rg -n "features/style.md|research-liquid-glass"` finds.
- [x] A package-structure test checks that ARCHITECTURE.md links ../EditorKit/style.md and that no doc links TestudoApp/features/style.md.
- [x] `swift test` is green.

#cross-repo