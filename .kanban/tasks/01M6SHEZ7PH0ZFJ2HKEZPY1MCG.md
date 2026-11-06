---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: Demo composer editor is not hittable (CI red since Nov 4)
---
CI's Examples (AgentViewKitDemo) leg fails on every run since Nov 4 (last green AVK 4909e9fc): `ACPTabEndToEndTests.testASendOfHelloShowsTheReplyOfTheAgent` at Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift:92 — `XCTAssertTrue failed - The composer editor is not hittable.` The session shows and the `prompt-editor` element exists, but XCUI's isHittable (an AX hit test at the element's centre) answers another element. Latest run: https://github.com/swissarmyhammer/AgentViewKit/actions/runs/42292592822

EK's suspects (editorkit-b5), most likely first: 1fe50719 ^bavw691 (.floatingGlass()/FloatingGlassContainer content gets .contentShape(.accessibility, shape) — the composer sits in floating glass), 857ce5eb+ab2ddebf ^zg9xtj7 (same on GlassBackground/CapsuleGlass), 90a7528d ^q48kgc3 (leaf-control AX hit search order), 06f0697f/931c93b6 ^7v6rvdx (ScopeFocusRing is a view-sized Canvas). AVK changes since 4909e9fc are suspects too.

User decision: find it headless — no XCUI run, no focus stealing.

- [ ] Hosted (headless, accessibility) test that reproduces it: the AX hit test at the centre of the composer editor in the thread's floating bar answers the editor (fails today)
- [ ] Find the cause (AVK or EK; bisect EK pins if needed)
- [ ] Fix in AVK, or send EK the first bad SHA + the repro and take their fix
- [ ] CI's Examples leg green