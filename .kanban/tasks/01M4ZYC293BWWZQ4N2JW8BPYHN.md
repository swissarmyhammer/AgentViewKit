---
assignees:
- claude-code
position_column: todo
position_ordinal: '8580'
title: 'Mail step 7: Correct the README host snippet for the ordered openSessions list of ACPClient 838bbad'
---
T0 (^dbmnhsv) found this build break. It is not in T1 to T4. It is not a change of the ACPAgent wire behavior. It comes from ACPClient `8cc5afe` ("make openSessions an ordered list of Identifiable SessionModel"), which is in the ACPClient main `838bbad`.

`swift build --build-tests` fails in the target `ReadmeSnippetsTests`:

- `Examples/ReadmeSnippets/Snippets/HostApp.swift:21:48: error: value of type '[SessionModel]' has no member 'values'` (`connection.openSessions.values.first`).
- The same text is in `README.md:217` (the `readme:compile` block). `Scripts/check-readme.sh` compares the README and the snippet files, so change both.
- `plan.md:97` says that `openSessions` is a dictionary from `SessionId` to `SessionModel`. Now it is an ordered list (`[SessionModel]`, with `session(for:)` for a lookup by id).

The library, `AgentViewKitTests`, `PackageStructureTests` and the demo app build with no error. Only this target fails. T1 requires "commit with AgentViewKit green", so do this task before T1.

Work:
1. Change the snippet in `README.md` to `connection.openSessions.first`, then run `Scripts/extract-readme-snippets.sh` so that `Examples/ReadmeSnippets/Snippets/HostApp.swift` agrees.
2. Change `plan.md` (the open set item) to the ordered list.
3. `swift build --build-tests` has no error. `Scripts/check-readme.sh` passes.

Write all text in STE. #mail-step-7