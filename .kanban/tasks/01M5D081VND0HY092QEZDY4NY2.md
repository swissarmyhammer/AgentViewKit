---
assignees:
- claude-code
position_column: todo
position_ordinal: '8680'
title: 'AVK-7g Import boundary: AgentViewKit does not import the other view kits'
---
Design: D105 (g). Step 5 work, small.

Tests/PackageStructureTests/ImportBoundaryTests.swift has `forbiddenInSources` (line 14). Add `KanbanViewKit` and `SnapshotViewKit` to the forbidden modules of Sources, so that no kit links another kit. The scope kind text is the contract between the kits.

Acceptance: the test fails on a fixture that imports KanbanViewKit and passes on the sources. #avk-7