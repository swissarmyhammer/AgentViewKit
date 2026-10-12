---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4pyfshhnr94bt7nzhaca6fe
  text: |-
    Research (implement):
    - Each recorded instance directory is one recording root: `sessions.jsonl`, `.gitattributes`, and one `<sessionId>/` directory. `transcripts.location: <absolute path>` names ONE root. Thus the demo makes one root in a temporary directory: it copies each `<sessionId>/` directory as it is, and it joins the lines of each `sessions.jsonl` (the `merge=union` rule of the agent for this file). The files in the repository do not change.
    - The demo sets `XDG_CONFIG_HOME` of the agent process to a temporary directory with `acp-agent/config.yaml` = `transcripts: location: <temporary root>`. The user layer of the owner (`~/.config/acp-agent/`) is not read and not written.
    - With `.path(URL)`, `session/list` with any `cwd` reads the same root. An unfiltered `session/list` gives an empty list (no `projects.jsonl` in the temporary user layer). The kit `SessionListView` sends the `cwd` filter, so this is correct.
    - Probe (python over stdio, `acp-agent acp`, built binary of 2026-10-11 11:52): `initialize`, `session/list`, and `session/resume` with `replayFrom: start` and the RECORDED cwd succeed for 4 sessions (no-otel-1011 django-14672, -13710, -14608 and code-context-1008 django-14155). Replay counts: 87, 129, 167, 919 updates. Resume time 0.7 s to 3 s.
    - Restore writes to the copy: `session-history.json` and `sessions.jsonl` change. Thus the temporary copy is necessary.
    - Fact for the FoundationModelsACPAgent session (not a failure): the resume makes the recorded cwd again when it does not exist, for example `/private/var/folders/l7/.../T/tmp20i_gz66/repo/.code-context/kit.db`. The code-context index of the restored session goes to a directory outside the transcript location. The demo cannot prevent this.
  timestamp: 2026-10-12T02:18:54.897811+00:00
- actor: claude-code
  id: 01m4pzke5ytcgab891z4dtvczp
  text: |-
    Implementation landed (not committed):
    - New: `Sources/DemoSupport/RecordedSessionsStage.swift`, `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/{GalleryTabView,GalleryLook,SessionThreadColumn,DemoFailureLabel}.swift`, `Examples/AgentViewKitDemo/Tests/GalleryTabEndToEndTests.swift`, `Tests/AgentViewKitTests/ACP/RecordedSessionsStageTests.swift`, `Examples/AgentViewKitDemo/RecordedSessions/` (4 instances + README).
    - Changed: `DemoAgent` (`makeConnected(recordedSessions:agentCommand:)`), `DemoLaunchOptions` (`DemoTab.gallery`, `--tab`), `DemoRootView` (Gallery tab), `ACPTabView` (uses the shared `SessionThreadColumn` and `DemoFailureLabel`, so the two tabs do not copy the thread column and the failure label), the xcodeproj generator (`resources:` folder references; `RecordedSessions` is a resource of the app), `DemoTestValues` (prefix element finder), README.md.
    - Swift-level check with the real binary (a temporary test file, removed after one run): `refreshSessions` lists 4 sessions; `resumeSession` gives 82, 162, 124 and 914 transcript entries. The recordings in the repository stay byte-equal to the source (`diff -r`).
    - `xcodebuild build-for-testing` of the demo: TEST BUILD SUCCEEDED, no compiler warning (the only lines are the `appintentsmetadataprocessor` notes of each build). UI tests not run (owner rule).
    - `swift test`: 1126 tests in 124 suites pass (1 known issue, `HostedLayoutExpectationsTests`, from before), plus 116 and 1 in the other runs. The `mlx-swift_Cmlx.bundle` "missing creator" build warning is in older logs too.
    - Load average: 36.07 / 51.45 / 56.35 before, 37.30 / 45.48 / 52.85 after.
    - Side effect of my probes outside the repositories: the agent made the recorded cwd directories again below `/private/var/folders/l7/3sxfw9k57n1dg_bhjfnfqcdh0000gn/T/tmp*/repo/.code-context/`. The shell rule did not let me remove them. Each Gallery open does the same.
  timestamp: 2026-10-12T02:38:22.910030+00:00
- actor: claude-code
  id: 01m4pzkjxn131v5qta1eeh1f4r
  text: |-
    ### implement — changed
    - evidence: 4 recorded instances copied as they are (8.1 MB, diff -r equal); new RecordedSessionsStage, GalleryTabView, GalleryLook, SessionThreadColumn, DemoFailureLabel, GalleryTabEndToEndTests, RecordedSessionsStageTests; changed DemoAgent, DemoLaunchOptions, DemoRootView, ACPTabView, DemoTestValues, xcodeproj generators, README.md. swift test: 1126 tests / 124 suites pass (1 known issue from before) + 116 + 1. xcodebuild build-for-testing succeeded; UI tests not run. Load average 36.07 before, 37.30 after. No restore error: 4 of 4 sessions restore (82, 162, 124, 914 entries).
    - next: /review. Send to the FoundationModelsACPAgent session: the resume makes the missing recorded cwd again with a .code-context index.
  timestamp: 2026-10-12T02:38:27.765723+00:00
- actor: claude-code
  id: 01m4pzndx881qf8x6kt18fcb6q
  text: '2026-10-11: The FoundationModelsACPAgent session accepted the missing-cwd problem as its task 01M4PZN4KNGZ8C573D32MRD96Z (code not written yet). Decision: the agent never creates a session cwd. session/resume of a session whose cwd is missing replays the history as now but gets no tool surface (no code-context index, no files, no shell, no MCP); a later session/prompt gives -32602 "the working directory of this session does not exist". The Gallery needs no change. When that commit is pushed, nothing in the Gallery changes; a prompt in a Gallery session will then show that error.'
  timestamp: 2026-10-12T02:39:28.168711+00:00
- actor: claude-code
  id: 01m4q0ke72axyacm2ad3xtnf6s
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (commit 853dd79). 2 findings (2 confirmed, 1 refuted): Examples/AgentViewKitDemo/AgentViewKitDemoFeature/DemoFailureLabel.swift:22, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryTabView.swift:185. The engine did not review the files in Examples/AgentViewKitDemo/RecordedSessions (no validator matches them) and gave no finding on them. These files are fixtures that the owner told us to copy as they are.
    - next: Correct the 2 findings in the "Review Findings (2026-10-11 21:43)" section. Then do the review again.
  timestamp: 2026-10-12T02:55:51.522978+00:00
- actor: claude-code
  id: 01m4q0kv2q576sfyxqy5brgcp8
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — Gallery tab, RecordedSessionsStage, 4 recorded sessions copied as they are (8.1 MB), look controls, README, tests; restore of 4/4 sessions worked
    - test: green — swift test, 1126 tests passed, 1 expected known issue, load average 34 to 43
    - commit: 853dd79 (secret scan of the recordings: nothing found)
    - review: findings — Examples/AgentViewKitDemo/AgentViewKitDemoFeature/DemoFailureLabel.swift:22, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryTabView.swift:185
  timestamp: 2026-10-12T02:56:04.695742+00:00
- actor: claude-code
  id: 01m4q1e9adww1d29ya94ebwj79
  text: |-
    Corrections of the 2 review findings (not committed):
    - Finding 1 (DemoFailureLabel, completeness/public-output-contract): new `DemoFailureText.text(of:)` in `Sources/DemoSupport/DemoFailureText.swift` gives `(error as? LocalizedError)?.errorDescription ?? String(describing: error)`. `DemoFailureLabel` shows this text. The missing-recordings error and the bundle lookup moved from `GalleryTabView` to DemoSupport (`RecordedSessionsStage.MissingRecordingsError`, `RecordedSessionsStage.recordingsResourceName`, `RecordedSessionsStage.recordingsDirectory(in:)`), so that a package test can assert on them. `GalleryTabView.StartError` and its `recordingsDirectory()` are removed.
    - Package tests: `RecordedSessionsStageTests.aBundleWithNoRecordingsGivesTheErrorDescriptionAsTheFailureText` (a start with no recordings gives the failure text "The app bundle has no RecordedSessions directory.", not the case name), `aBundleWithRecordingsGivesTheRecordingsDirectory`, and `DemoFailureTextTests` (2 tests: localized description, and the fallback). RED was a compile failure (no `DemoFailureText`), then GREEN: 13 tests in 2 suites.
    - Finding 2 (duplication): new `DemoStartView` (`Examples/AgentViewKitDemo/AgentViewKitDemoFeature/DemoStartView.swift`) with a `Phase` (starting, failed, started), the starting text, the starting identifier and the failure identifier. `ACPTabView` and `GalleryTabView` use it through `startView` and `startPhase`. Both `phaseView` copies are removed.
    - Discovery: in DemoSupport (default main actor isolation) a `LocalizedError` type must be `nonisolated`, and the static name that its `errorDescription` reads must be `nonisolated` too.
    - `ruby Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb` made the project again for the 2 new files. Nothing under `Examples/AgentViewKitDemo/RecordedSessions` changed.
  timestamp: 2026-10-12T03:10:31.245647+00:00
- actor: claude-code
  id: 01m4q1ecmv0t2ag0yahhnwedtr
  text: |-
    ### implement — changed
    - evidence: new Sources/DemoSupport/DemoFailureText.swift, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/DemoStartView.swift, Tests/AgentViewKitTests/ACP/DemoFailureTextTests.swift; changed Sources/DemoSupport/RecordedSessionsStage.swift, DemoFailureLabel.swift, GalleryTabView.swift, ACPTabView.swift, Tests/AgentViewKitTests/ACP/RecordedSessionsStageTests.swift. swift test: 1130 tests in 125 suites pass (1 known issue from before, HostedLayoutExpectationsTests) + 116 tests in 14 suites + 1; only warning is the mlx-swift "missing creator" build warning from before. xcodebuild build-for-testing of the demo: TEST BUILD SUCCEEDED (only the appintentsmetadataprocessor notes). UI tests not run. Load average 35.17 before the full run, 29.79 after.
    - next: /review. Both findings are checked.
  timestamp: 2026-10-12T03:10:34.651519+00:00
- actor: claude-code
  id: 01m4q1v1wb8pddxgk0yxj2pcs8
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (bd34515): 4 findings, 4 confirmed, 0 refuted. ACPTabView.swift:336, ACPTabView.swift:346, GalleryTabView.swift:163, GalleryTabView.swift:173 (all duplication/duplication).
    - next: implement the 4 open items in the section "Review Findings (2026-10-11 22:14)". Put the shared start view construction and the shared start phase mapping in DemoStartView. Then review again.
  timestamp: 2026-10-12T03:17:29.611967+00:00
- actor: claude-code
  id: 01m4q1vet3t4205tkx73m7ccpf
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — DemoFailureText, RecordedSessionsStage error and lookup, shared DemoStartView; 2 findings checked
    - test: green — swift test, 1130 tests passed, 1 expected known issue, load average 25 to 35
    - commit: bd34515
    - review: findings — Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift:336, ACPTabView.swift:346, GalleryTabView.swift:163, GalleryTabView.swift:173
  timestamp: 2026-10-12T03:17:42.851153+00:00
- actor: claude-code
  id: 01m4q2e0a8rbd5774dnevng2ed
  text: |-
    Corrections of the 4 duplication findings of "Review Findings (2026-10-11 22:14)" (not committed):
    - New `DemoStartPhase<Started>` in `Sources/DemoSupport/DemoStartPhase.swift`: one shared state enum (`starting`, `failed(any Error)`, `started(Started)`) that both tabs hold in `@State`. Thus no tab maps its state to the start view, and both `startPhase` copies are removed. `DemoStartPhase.start(_:with:)` is the shared start routine: it runs the operation only while the phase is `starting`, and sets `failed(error)` when the operation throws. Both tabs called the same guard and do/catch before; both `start()` functions now call this routine.
    - `DemoStartView` is now generic over `Started`, and has one init `init(phase:tab:)` that takes the tab. New protocol `DemoStartingTab` (in `DemoStartView.swift`) gives the starting text and the two accessibility identifiers. `ACPTabView` and `GalleryTabView` conform. Each tab calls `DemoStartView(phase: phase, tab: self)`. Both `startView` copies are removed.
    - `ACPTabView` keeps its tab-specific cases in a private `Content` enum (`signingIn`, `running`) that is the `Started` value. `GalleryTabView` uses `DemoStartPhase<DemoAgent>`. The accessibility identifier values did not change, so the UI tests need no change.
    - Package tests: `DemoStartPhaseTests` (4 tests). RED was a compile failure (no `DemoStartPhase`), then GREEN: 4 tests in 1 suite.
    - Discovery: the multi-edit form of `edit file` refused the edits, and `replace_all` replaced only the first match in one call. Each edit was then done one at a time.
    - `ruby Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb` made the project again (it is gitignored; it now holds `DemoStartPhase.swift`). Nothing under `Examples/AgentViewKitDemo/RecordedSessions` changed.
  timestamp: 2026-10-12T03:27:50.600329+00:00
- actor: claude-code
  id: 01m4q2e3809p9bb8923m041mk4
  text: |-
    ### implement — changed
    - evidence: new Sources/DemoSupport/DemoStartPhase.swift, Tests/AgentViewKitTests/ACP/DemoStartPhaseTests.swift; changed Examples/AgentViewKitDemo/AgentViewKitDemoFeature/DemoStartView.swift, ACPTabView.swift, GalleryTabView.swift. swift test: 1134 tests in 126 suites pass (1 known issue from before, HostedLayoutExpectationsTests) + 116 tests in 14 suites + 1; the only warning is the mlx-swift "missing creator" build warning from before. xcodebuild build-for-testing of the demo: TEST BUILD SUCCEEDED, no warning other than the appintentsmetadataprocessor notes. UI tests not run. Load average 21.39 before the full run, 16.67 after.
    - next: /review. All 4 findings are checked.
  timestamp: 2026-10-12T03:27:53.600248+00:00
- actor: claude-code
  id: 01m4q2rfsc11y8q8df9mqee0f2
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (b0df063). 0 findings, 0 confirmed, 0 refuted. 5 files reviewed, 2 .kanban files not reviewed (ignore rule). All prior findings are checked.
    - next: none. The task moved to done.
  timestamp: 2026-10-12T03:33:34.124514+00:00
- actor: claude-code
  id: 01m4q2rsxj8rpth7p07s7ev5wx
  text: |-
    ### finish iteration 3 — clean
    - implement: changed — DemoStartPhase, generic DemoStartView with DemoStartingTab, DemoStartPhase.start; 4 findings checked
    - test: green — swift test, 1134 tests passed, 1 expected known issue, load average 13 to 24
    - commit: b0df063
    - review: clean — 0 findings (5 files); task in done
  timestamp: 2026-10-12T03:33:44.498248+00:00
position_column: done
position_ordinal: ffac80
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
- [x] Copy a few whole session directories (for example 3 to 5 instances with different sizes) into the demo, for example `Examples/AgentViewKitDemo/RecordedSessions/`. Keep each file as it is. Add a short README in that directory that tells where the files come from and that they are replaced over time.
  - Done: 4 instances, 8.1 MB, `diff -r` equal to the source: `django__django-14672` (0.65 MB), `-13710` (1.1 MB), `-14608` (1.6 MB) from `no-otel-1011`, and `-14155` (4.9 MB) from `code-context-1008`. `RecordedSessions/README.md` added.
- [x] The demo starts FoundationModelsACPAgent (the sibling `acp-agent` program, as `DemoLaunchOptions` does today, or the in-process `ComposedAgent`) with its transcript location (`transcripts:` configuration, `TranscriptLocation.path(URL)`) set to a COPY of the recorded sessions in a temporary directory, so that a restore never changes the files in the repository.
  - Done: `RecordedSessionsStage` (DemoSupport) copies the recordings to one temporary transcript location, writes `acp-agent/config.yaml` with `transcripts.location: <copy>` below a temporary `XDG_CONFIG_HOME`, and `DemoAgent.makeConnected(recordedSessions:agentCommand:)` starts `acp-agent acp` with that environment.
- [x] A Gallery tab (or section) lists the sessions from `ConnectionModel.sessions` (`session/list`) and opens one with `session/load`, in the drop-in `AgentThreadView`.
  - Done: `GalleryTabView` with `SessionListView` and `AgentThreadView` (through `SessionThreadColumn`). In ACP v2 the restore is `session/resume` with `replayFrom: start`, which `SessionListView` sends.
- [x] Controls to judge the look: the EditorKit theme (`SystemTheme`, the `DefaultTheme` presets), light and dark appearance, increased contrast, density, and text size.
  - Done: `GalleryLook` and `GalleryLookControls` in an inspector.
- [x] If the restore of a recorded session fails in FoundationModelsACPAgent (for example because the recorded `cwd` does not exist, or the layout of the recordings differs from the transcript location), do not work around it in the kit. Record the problem and send it to the FoundationModelsACPAgent session.
  - The restore does not fail (4 of 4 sessions restore). One fact for the FoundationModelsACPAgent session is in the comments: the resume makes the missing recorded cwd again, with a `.code-context` index in it.
- [x] Tests: only that the Gallery opens a session and shows a transcript (no assertion on the content of the recordings). The UI tests of the demo may cover the Gallery tab.
  - Done: `GalleryTabEndToEndTests` (demo UI test, compiled, not run on the screen of the owner) and `RecordedSessionsStageTests` (unit tests with their own fixtures).
- [x] README of the demo: how to replace the recorded sessions with new ones.
  - Done: README.md "The demo app" and "Replace the recorded sessions", and `RecordedSessions/README.md`.

## Review Findings (2026-10-11 21:43)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 16 file(s) reviewed, 28 not reviewed.

> 6 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 6 file(s)

> 22 file(s) not reviewed — no validator matched:
> - `Examples/AgentViewKitDemo/RecordedSessions/README.md` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-13710/.gitattributes` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-13710/01M4NZ53EKQN37BF9S7ABMVMC5/session-history.json` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-13710/01M4NZ53EKQN37BF9S7ABMVMC5/session.json` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-13710/01M4NZ53EKQN37BF9S7ABMVMC5/transcript.jsonl` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-13710/sessions.jsonl` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14155/.gitattributes` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14155/01M4E1KW6GVA1KPVRD411G7SFQ/session-history.json` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14155/01M4E1KW6GVA1KPVRD411G7SFQ/session.json` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14155/01M4E1KW6GVA1KPVRD411G7SFQ/transcript.jsonl` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14155/sessions.jsonl` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14608/.gitattributes` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14608/01M4PF8QH2HSSYSSJS6JVAW9B2/session-history.json` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14608/01M4PF8QH2HSSYSSJS6JVAW9B2/session.json` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14608/01M4PF8QH2HSSYSSJS6JVAW9B2/transcript.jsonl` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14608/sessions.jsonl` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14672/.gitattributes` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14672/01M4PK9Z6EC0GH5VCXH778X4RW/session-history.json` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14672/01M4PK9Z6EC0GH5VCXH778X4RW/session.json` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14672/01M4PK9Z6EC0GH5VCXH778X4RW/transcript.jsonl` — no validator matches this file
> - `Examples/AgentViewKitDemo/RecordedSessions/django__django-14672/sessions.jsonl` — no validator matches this file
> - `README.md` — no validator matches this file

- [x] `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/DemoFailureLabel.swift:22` `completeness/public-output-contract` — The label renders `String(describing: error)`. For the Gallery start, the error is `GalleryTabView.StartError`, a plain enum whose intended message is its `LocalizedError.errorDescription` ("The app bundle has no RecordedSessions directory."). `String(describing:)` ignores `errorDescription` and prints the case name (`missingRecordings`), so the intended user-facing message is silently dropped whenever the bundle has no recordings. The `identifier`-based failure check still passes, which hides the regression. Render the localized text when the error provides it, for example `(error as? LocalizedError)?.errorDescription ?? String(describing: error)`, or use `error.localizedDescription` if that matches the contract the previous `failureLabel` used. Add one assertion that a missing-recordings start shows the `errorDescription` text, not the case name.
- [x] `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryTabView.swift:185` `duplication/duplication` — The new GalleryTabView.phaseView repeats the structure of ACPTabView.phaseView. Both switch over the start phase, show a ProgressView with an accessibility identifier while starting, show DemoFailureLabel on failure, and show EmptyView otherwise. The copies differ only in the progress text and the identifier values. The copies can drift apart, for example when the failure presentation changes in one tab and not the other. Extract one shared view that takes the starting text, the starting identifier, and the failure identifier as parameters. Use it from both tabs and delete the copy in GalleryTabView.swift.

## Review Findings (2026-10-11 22:14)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 8 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift:336` `duplication/duplication` — The `startView` property builds the same DemoStartView call, with the same four arguments and the same identifier wiring, as the matching property in GalleryTabView. The two copies can drift apart when the start view changes. Extract one shared construction in DemoStartView, for example a static function or an initializer that takes the start phase, the starting text, and the two identifiers. Call it from both tabs and delete both copies of `startView`.
- [x] `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift:346` `duplication/duplication` — The `startPhase` mapping from the tab state to DemoStartView.Phase repeats the same `.starting` and `.failed` arms as GalleryTabView. Both tabs map the same start states, so a change to one mapping can leave the other stale. Put the shared mapping in DemoStartView, for example a static function that takes the start state and returns the Phase, with the tab-specific running and signing-in cases passed in as a Bool or as the already-mapped value. Call it from both tabs and delete both copies of `startPhase`.
- [x] `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryTabView.swift:163` `duplication/duplication` — The `startView` property in GalleryTabView repeats the DemoStartView construction from ACPTabView. Both copies are in this change, so neither is protected as existing code. Move the shared construction into DemoStartView, as described for ACPTabView.swift:336, and call it here. Delete this copy of `startView`.
- [x] `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryTabView.swift:173` `duplication/duplication` — The `startPhase` mapping in GalleryTabView repeats the `.starting` and `.failed` arms of the ACPTabView mapping. Both copies are in this change. Share the mapping with ACPTabView as described for ACPTabView.swift:346, then delete this copy of `startPhase`.
