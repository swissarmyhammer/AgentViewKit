---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5j8vcq6varsdg2mq4qm3h7e
  text: |-
    Research (in push checkout avk-push, FoundationModelsACPAgent at a1fe667 incl. 159a87a + f065690):
    - Before 159a87a, DemoAgent called compose(name:workingDirectory:environment:modelSource:transcriptLocation:) with no rootSettingsFolder / hooksDataDirectory / skillsMarketplaceCacheDirectory / modelCacheDirectory. So its folders were: user layer under $XDG_CONFIG_HOME/agentviewkit-demo (read from the given `environment`), hooks in AgentHooks.dataDirectory(name:environment:) = XDG data home, marketplace cache from SKILLS_MARKETPLACE_CACHE, HF cache default.
    - `AgentHome.makeXDG(name:environment:)` is documented as exactly that set of folders ("keeps the folders that the CLI always used"), and acp-agent's AgentComposition.home(environment:) uses it when no ACP_AGENT_HOME is set. makeCustom would move everything under two app roots — a behaviour change the demo never asked for.
    - The demo does deliberately redirect the config root, but through the environment (RecordedSessionsStage.agentEnvironment = XDG_CONFIG_HOME=<stage>/configuration; DemoAgentTests the same). makeXDG reads XDG_CONFIG_HOME from that same environment, so the stage still owns the user layer and project registry (RecordedSessionsAgentTests check this).
    - Only compile call site: Sources/DemoSupport/DemoAgent.swift. No SettingsFolders( use in Sources/Tests/Examples. Doc-comment examples of compose without home: Sources/AgentViewKit/ACP/InProcessAgent.swift, Examples/ReadmeSnippets/Snippets/InProcessQuickStart.swift and the README copy of it (kept equal by ReadmeSnippetTests).
  timestamp: 2026-10-22T16:59:30.406276+00:00
- actor: claude-code
  id: 01m5j9ctzg2rqdntrbcme8e8h9
  text: |-
    ### implement — changed
    - where: push checkout avk-push (branch push-tmp), uncommitted; FoundationModelsACPAgent resolved at main a1fe667.
    - preset: `AgentHome.makeXDG(name: agentviewkit-demo, environment:)` through new `DemoAgent.home(environment:)`. Reason: before 159a87a the demo passed no rootSettingsFolder/hooks/cache folders, so it got the XDG defaults read from its `environment`. makeXDG is documented as exactly those folders. The demo's deliberate redirect (Gallery stage and tests) goes through XDG_CONFIG_HOME in the environment, which makeXDG still reads. makeCustom would have moved everything under two new roots.
    - files: Sources/DemoSupport/DemoAgent.swift (home(environment:) + `home:` on compose); Tests/AgentViewKitTests/ACP/DemoAgentTests.swift (new test theHomeOfTheAgentIsTheDemoDotfolderInTheConfigurationRootOfTheEnvironment, RED = build failure, then GREEN); stale doc examples of compose given `home: .makeCustom(synced:local:)` in Sources/AgentViewKit/ACP/InProcessAgent.swift, Examples/ReadmeSnippets/Snippets/InProcessQuickStart.swift and README.md (the snippet and the README stay equal).
    - No other ComposedAgent.compose / SettingsFolders( call in Sources, Tests or Examples.
    - swift build: Build complete. swift test: 1589 tests in 198 suites passed, 0 failures, 3 known issues (by-design withKnownIssue harness tests), 1 skip = theGeneratedDemoProjectPinsTheRootACPRevisions (no generated demo project at the time). Afterwards generated the project and ran `xcodebuild ... -scheme AgentViewKitDemo build`: BUILD SUCCEEDED against ACPAgent a1fe667; the pin test then passed when run alone.
    - Only warning in swift build/test output: SwiftPM "missing creator for mutated node ... mlx-swift_Cmlx.bundle", from the build of the mlx dependency, not from this package's code.
    - next: review.
  timestamp: 2026-10-22T17:09:02.064294+00:00
- actor: claude-code
  id: 01m5j9r1jz5w3dh94y8dzat51a
  text: |-
    ### review — findings
    - evidence: review sha f1c7d65~1..f1c7d65 (commit on push-tmp) — 1 finding (1 confirmed, 1 refuted): Sources/DemoSupport/DemoAgent.swift:212 swift/fluent-usage; README.md not reviewed (no validator matched)
    - next: rename DemoAgent.home(environment:) to makeHome(environment:) and update its call site and the DemoAgentTests call
  timestamp: 2026-10-22T17:15:09.279059+00:00
- actor: claude-code
  id: 01m5j9rfqcb7sfydmyfvz05k8j
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 5 files in the push worktree (avk-push, branch push-tmp): DemoAgent.swift, DemoAgentTests.swift, InProcessAgent.swift, InProcessQuickStart.swift, README.md; preset AgentHome.makeXDG
    - test: green — swift test 1589 passed, 0 failed; the demo-project pin test skipped in the full run, then passed alone after the project was generated; demo xcodebuild BUILD SUCCEEDED
    - commit: f1c7d65 (push-tmp, local)
    - review: findings — Sources/DemoSupport/DemoAgent.swift:212 (swift/fluent-usage: factory method should begin with `make`)
  timestamp: 2026-10-22T17:15:23.756111+00:00
- actor: claude-code
  id: 01m5ja0d03m81b63c2kde3dnd0
  text: |-
    ### implement — changed
    - finding: `Sources/DemoSupport/DemoAgent.swift:212` `swift/fluent-usage` — Factory method should begin with `make`. Renamed `DemoAgent.home(environment:)` to `makeHome(environment:)`; updated the compose call site, the DocC reference ``makeHome(environment:)`` in the doc comment of `makeInProcess(foundationModelsIn:...)`, and the DemoAgentTests call. No other reference in Sources, Tests, Examples or README. The other factory methods in the file (makeInitializeRequest, makeInProcess x3, makeStarted) already begin with `make`.
    - where: push checkout avk-push (branch push-tmp), uncommitted, on top of f1c7d65.
    - RED: `swift test --filter DemoAgent` after the test change — build error `type 'DemoAgent' has no member 'makeHome'`. GREEN: 22 tests in 4 suites passed.
    - full `swift test`: 1589 tests in 198 suites passed, 0 failures, 0 skipped, 3 known issues (by-design withKnownIssue). Only warning: SwiftPM "missing creator for mutated node ... mlx-swift_Cmlx.bundle" from the mlx dependency build.
    - files: Sources/DemoSupport/DemoAgent.swift, Tests/AgentViewKitTests/ACP/DemoAgentTests.swift
    - next: review.
  timestamp: 2026-10-22T17:19:43.107136+00:00
- actor: claude-code
  id: 01m5ja4c9hmqh3w66z3z82bm0d
  text: |-
    ### review — clean
    - evidence: review sha 2d52fb1~1..2d52fb1 (worktree avk-push, branch push-tmp) — 0 findings, 0 confirmed, 0 refuted, 7 validator runs attempted, 0 failed; 2 files reviewed (Sources/DemoSupport/DemoAgent.swift, Tests/AgentViewKitTests/ACP/DemoAgentTests.swift). Prior finding `swift/fluent-usage` (DemoAgent.home -> makeHome) checked and verified fixed in the diff: definition, doc reference, call site in compose, and test call.
    - next: none — task moved to done.
  timestamp: 2026-10-22T17:21:53.457915+00:00
- actor: claude-code
  id: 01m5ja6dk7z4m8x85aj1wam50c
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — renamed DemoAgent.home(environment:) to makeHome(environment:) (finding checked)
    - test: green — swift test 1589 passed, 0 failed, 0 skipped (push worktree, latest dependency mains)
    - commit: 2d52fb1
    - review: clean — 0 findings, task in done
    - PUSHED (user approved): origin/main 00a8c7f..2d52fb1, together with ^32a58sq ^1ye0jj6 ^brhhdf4 ^786dxt8 ^td23hf5. The main checkout was reset to origin/main, with the uncommitted ^cwdb5zg work kept.
  timestamp: 2026-10-22T17:23:00.327045+00:00
position_column: done
position_ordinal: ffffb180
title: 'DemoSupport builds against FoundationModelsACPAgent main: ComposedAgent.compose requires home: AgentHome'
---
Found by the pre-push build on 2026-10-22, which resolves every dependency at its latest `main`. FoundationModelsACPAgent 159a87a ("compose, the agent and the CLI take one AgentHome") and f065690 ("AgentHome presets in the make form, makeXDG and makeCustom") made `home: AgentHome` a required parameter of `ComposedAgent.compose(name:workingDirectory:home:environment:modelSource:...)`.

`Sources/DemoSupport/DemoAgent.swift:222` fails: `error: missing argument for parameter 'home' in call`. The checkout of AgentViewKit origin/main is broken against the latest dependency mains too, not only the local commits.

Work:
- Pass an `AgentHome` in DemoAgent, built with the preset form that ACPAgent documents (`AgentHome.make...`). Pick the one that matches what the demo did before: the default home under the user's dotfolder, unless the demo deliberately used a throwaway or custom folder. Then keep that behaviour, e.g. with `makeCustom` over the demo's folder.
- Check every other `ComposedAgent.compose` / `SettingsFolders(name:home:environment:)` call in Sources, Tests and Examples.
- `swift test` green against the latest dependency mains (`swift package update`), and the demo app builds. #bug #cross-repo

## Review Findings (2026-10-22 12:10)

> Scope: `review sha f1c7d65~1..f1c7d65` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 1 not reviewed.

> 1 file(s) not reviewed — no validator matched:
> - `README.md` — no validator matches this file

- [x] `Sources/DemoSupport/DemoAgent.swift:212` `swift/fluent-usage` — Factory method should begin with `make`. The function constructs and returns an `AgentHome` from parameters, making it a factory method. Per the Swift API Design Guidelines, factory methods begin with `make`. Rename to `static func makeHome(environment:)` and update the call site at line 243 from `home: try home(environment: environment)` to `home: try makeHome(environment: environment)`, and the test at line 96 from `let home = try DemoAgent.home(environment: environment)` to `let home = try DemoAgent.makeHome(environment: environment)`.
