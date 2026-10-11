---
assignees:
- claude-code
position_column: todo
position_ordinal: '8680'
title: 'Demo Gallery: show recorded SWE-bench sessions through the session restore of FoundationModelsACPAgent'
---
## What
Decision of the owner (2026-10-11): the demo gets a Gallery to see how the views look with real session data. It uses recorded sessions of FoundationModelsACPAgent from SWE-bench runs. There is no new replay agent: the demo runs FoundationModelsACPAgent itself and uses its session restore (`session/list`, `session/load`). The views bind to a real `SessionModel` and `ConnectionModel`.

Source of the recordings: `../FoundationModelsACPAgent/bench/preds.*.transcripts/<instance>/` (56 sessions, 23 MB in total on 2026-10-11). Each instance directory has `sessions.jsonl` (session id, title, cwd, updatedAt), `.gitattributes`, and `<sessionId>/session.json`, `session-history.json` (the ACP session updates that `session/load` replays: tool call updates, thoughts, terminal updates, messages, commands, config options, usage, session info, state), and `transcript.jsonl` (Router records with timestamps).

## Rules from the owner
- Copy some sessions into this repository as they are. Do not trim or edit them.
- The sessions will be replaced over time. No test asserts on their content. The purpose is to see how things look.
- Use a real session model. Do not write another replay agent: it would get out of step with FoundationModelsACPAgent.

## Work
- [ ] Copy a few whole session directories (for example 3 to 5 instances with different sizes) into the demo, for example `Examples/AgentViewKitDemo/RecordedSessions/`. Keep each file as it is. Add a short README in that directory that tells where the files come from and that they are replaced over time.
- [ ] The demo starts FoundationModelsACPAgent (the sibling `acp-agent` program, as `DemoLaunchOptions` does today, or the in-process `ComposedAgent`) with its transcript location (`transcripts:` configuration, `TranscriptLocation.path(URL)`) set to a COPY of the recorded sessions in a temporary directory, so that a restore never changes the files in the repository.
- [ ] A Gallery tab (or section) lists the sessions from `ConnectionModel.sessions` (`session/list`) and opens one with `session/load`, in the drop-in `AgentThreadView`.
- [ ] Controls to judge the look: the EditorKit theme (`SystemTheme`, the `DefaultTheme` presets), light and dark appearance, increased contrast, density, and text size.
- [ ] If the restore of a recorded session fails in FoundationModelsACPAgent (for example because the recorded `cwd` does not exist, or the layout of the recordings differs from the transcript location), do not work around it in the kit. Record the problem and send it to the FoundationModelsACPAgent session.
- [ ] Tests: only that the Gallery opens a session and shows a transcript (no assertion on the content of the recordings). The UI tests of the demo may cover the Gallery tab.
- [ ] README of the demo: how to replace the recorded sessions with new ones.