---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5d0a0j6203msfd406r387md
  text: |-
    Shape from D105 (f) (TestudoApp 4d75aa8):
    - A public type `AgentCommandGroup`. Each verb is in exactly one group.
    - A group id has the kit prefix, for example `agent.navigate`.
    - The host gives the groups to turn off when the kit registers its commands.
    - A group with the same job in two kits has the same last word, for example `navigate` for the content verbs and `clipboard` for Copy.

    Planned split of the 13 verbs:
    - `agent.compose`: Send Message, Focus Composer.
    - `agent.control`: Stop, Approve Request, Reject Request.
    - `agent.navigate`: Next and Previous Prompt, Next and Previous Request, Scroll to Bottom, Expand or Collapse All.
    - `agent.clipboard`: Copy Message, Copy Thread.
    Check this split again when the card starts.
  timestamp: 2026-10-20T15:54:00.134359+00:00
- actor: claude-code
  id: 01m5dfy7hz2smym6yv6yhqa289
  text: |-
    Research:
    - The split in the first comment is still correct: 2 + 3 + 6 + 2 = 13 verbs, each verb in exactly one group.
    - EditorKit has no type that turns off a group of commands. EK-5 is the menu placement (`SystemMenuSlot`, SwiftUI `CommandGroup` in `EditorMenuCommands`). The verbs already use it through `MenuPlacement` (`.view` and `MenuPath.session`). Thus `AgentCommandGroup` is a type of the kit, and the menus stay as they are.
    - `CommandRegistry.unregister(_:at:)` removes a definition and each key binding whose source is its id. The secondary chords (Escape for Stop) have the verb id as source. Thus a registration with a group off unregisters the verbs of that group, and a change of the groups at run time removes the old definitions and keys.
    - The host gives the groups through an environment value with a public modifier. The value reaches the scope of `agentCommandScope(session:)` and the scope that `AgentThreadView` applies itself.
    - The composer buttons (Send, Stop) and the Copy button of a message call `AgentCommandTarget.perform` and use their direct action when the command is not there. Thus a group that is off does not break a button.
  timestamp: 2026-10-20T20:27:11.295715+00:00
- actor: claude-code
  id: 01m5dg5qn1c1c79rvbyhr8j9dv
  text: |-
    Implementation landed.
    - New public `AgentCommandGroup` (`compose`, `control`, `navigate`, `clipboard`), with `id` (`agent.<group>`) and `verbs`. New public `AgentCommandVerb.group` with an exhaustive switch.
    - New public modifier `.agentCommandGroups(off:)` writes the environment value `agentCommandGroupsOff`. `AgentCommandScope` reads it and gives it to the mount, so the scope of `agentCommandScope(session:)` and the own scope of `AgentThreadView` both obey it. Apply the modifier outside the scope.
    - `AgentCommandRegistration.register(_:at:into:groupsOff:)` registers each verb that is on and calls `CommandRegistry.unregister` for each verb that is off. `AgentKeymap.bindSecondaryChords(into:at:groupsOff:)` binds no chord of a verb that is off. Thus Escape does not stop the agent when `control` is off.
    - Each verb that is on stays an EditorKit command, so the palette, the menus and the context menus show it (D108, D109). The menu placement (EK-5 `SystemMenuSlot` through `MenuPath.view` and `MenuPath.session`) did not change.
    - Process note: the hosted test of the environment wiring was written after the wiring. The headless tests were written first and failed to compile before the code existed.
    - KanbanViewKit and SnapshotViewKit have no code for groups yet. Their plans must use the same shape (D105 (f)); this card did not change them.
  timestamp: 2026-10-20T20:31:17.153831+00:00
- actor: claude-code
  id: 01m5dg5t8rgsdpc4cm03xnh9xc
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Commands/AgentCommandGroup.swift (new), Sources/AgentViewKit/Commands/AgentCommandScope.swift, Sources/AgentViewKit/Commands/AgentKeymap.swift, Tests/AgentViewKitTests/Commands/AgentCommandGroupTests.swift (new, 6 tests), Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift (1 test), README.md. `swift test`: 1363 tests in 160 suites passed with 2 known issues, plus 130 tests in 17 suites passed, plus 1 test passed. Only the mlx bundle warning, which existed before.
    - next: /review
  timestamp: 2026-10-20T20:31:19.832981+00:00
- actor: claude-code
  id: 01m5dg9jq7yfrkhkc7nzzh405v
  text: |-
    ### test — green
    - evidence: swift test — 1363 tests in 160 suites passed, 0 failed, 0 skipped, 2 known issues (before this change). The only warning is the mlx bundle build warning (before this change). No new warnings.
    - next: review
  timestamp: 2026-10-20T20:33:23.175376+00:00
- actor: claude-code
  id: 01m5dgc9sbm018kftgp3c02gnz
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (bf664b3): 0 findings, 0 confirmed, 1 refuted. 5 files reviewed. README.md and 2 .kanban files were not reviewed (no validator, or ignore rule).
    - next: none. The task moved to done.
  timestamp: 2026-10-20T20:34:52.331216+00:00
- actor: claude-code
  id: 01m5dgck0eqqb741n3mqkrjfrh
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 6 files
    - test: green — swift test, 1363 passed, 2 known issues that were there before
    - commit: bf664b3
    - review: clean — 0 findings
  timestamp: 2026-10-20T20:35:01.774961+00:00
position_column: done
position_ordinal: fff680
title: AVK-7e Command groups that the host can turn off
---
Design: AVK-7, D105 (f). KanbanViewKit plan §3.4 has the same rule. Step 5 work.

Today `AgentCommand.definitions(for:)` (Commands/AgentCommands.swift:250) registers all 13 verbs.

Do:
- Define the groups of the `agent.*` verbs (for example: prompt and stop, requests, thread view, copy). Agree the group names with KanbanViewKit and SnapshotViewKit so the three kits use one shape.
- A host gives the groups that are off, for example through an environment value or a parameter of `agentCommandScope(session:)`. A verb in a group that is off is not registered, so it does not show in the menus, the context menus or the palette, and its keys do not resolve.

Acceptance: headless tests for one group off: its verbs are not in `definitions(at:)`, not in `contextMenuMirror`, and its chords resolve to nothing. #avk-7