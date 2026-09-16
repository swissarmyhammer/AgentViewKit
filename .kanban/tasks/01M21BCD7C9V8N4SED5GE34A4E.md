---
comments:
- actor: claude-code
  id: 01m2n8gc2hzygjyzdjep45f7wq
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Model/JSONValue.swift, Tests/AgentViewKitTests/Model/JSONValueTests.swift (21 tests).
    - decisions: The conversion properties have the names `boolValue`, `doubleValue`, `intValue`, `stringValue`. `jsonString` also sorts keys, so that its output is stable. Both printers do not escape `/`. A number that is not finite prints as `null`, so the printers do not throw. `intValue` uses `Int(exactly:)`: a fraction, a non-finite number, or a number out of range gives `nil`.
    - next: test, commit, review.
  timestamp: 2026-09-16T14:04:07.121622+00:00
- actor: claude-code
  id: 01m2n8n4nhmqd46bnt5632f328
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — JSONValue.swift, JSONValueTests.swift
    - test: green — swift test, 165 tests passed (21 in JSONValueTests)
    - commit: ce97ca3
    - review: findings — Sources/AgentViewKit/Model/JSONValue.swift:153, :161, :170 (no_direct_standard_out_logs; the private helper had the name `print`). Fix: rename the helper to `encodedText(of:formatting:)`.
  timestamp: 2026-09-16T14:06:43.377541+00:00
- actor: claude-code
  id: 01m2n8q7f4vfwcn08vttw9eq95
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — renamed the helper `print` to `encodedText(of:formatting:)` in JSONValue.swift
    - test: green — swift test, 165 tests passed, no new warnings
    - commit: 27555ee
    - review: clean — review sha HEAD~1..HEAD, 0 findings; each prior finding is checked. Task moved to done.
  timestamp: 2026-09-16T14:07:51.780550+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: done
position_ordinal: '8780'
title: 'JSONValue: the kit-local JSON enum (plan §3.2, §11#1)'
---
## What
Create `Sources/AgentViewKit/Model/JSONValue.swift`. The core target must not import the ACP wire package, so it needs its own JSON value.

- `public enum JSONValue: Sendable, Hashable, Codable`: `null`, `bool(Bool)`, `number(Double)`, `string(String)`, `array([JSONValue])`, `object([String: JSONValue])`.
- `Codable` through `singleValueContainer`, with object key order not significant for equality.
- Subscripts `value[key]` and `value[index]` that return `JSONValue?`.
- `init(json: String) throws` and `var jsonString: String` (compact) and `prettyPrinted: String` (sorted keys).
- Conversions `Bool?`, `Double?`, `Int?`, `String?` as computed properties.

## Acceptance Criteria
- [x] Round-trip of a nested object through `Codable` is equal.
- [x] `prettyPrinted` output is stable across runs for the same value.
- [x] `JSONValue(json: "{bad")` throws.

## Tests
- [x] `Tests/AgentViewKitTests/Model/JSONValueTests.swift`: round-trip, subscripts, conversions, pretty print, parse error.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 09:04)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 2 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKit/Model/JSONValue.swift:153` `code-hygiene/disallowed-constructs-swift` — no_direct_standard_out_logs: Do not commit print(…), debugPrint(…), dump(…) or _printChanges(), which write to standard out in release. Log to a dedicated logging system, or silence one debug-only line with // swiftlint:disable:next no_direct_standard_out_logs and the reason after it.
- [x] `Sources/AgentViewKit/Model/JSONValue.swift:161` `code-hygiene/disallowed-constructs-swift` — no_direct_standard_out_logs: Do not commit print(…), debugPrint(…), dump(…) or _printChanges(), which write to standard out in release. Log to a dedicated logging system, or silence one debug-only line with // swiftlint:disable:next no_direct_standard_out_logs and the reason after it.
- [x] `Sources/AgentViewKit/Model/JSONValue.swift:170` `code-hygiene/disallowed-constructs-swift` — no_direct_standard_out_logs: Do not commit print(…), debugPrint(…), dump(…) or _printChanges(), which write to standard out in release. Log to a dedicated logging system, or silence one debug-only line with // swiftlint:disable:next no_direct_standard_out_logs and the reason after it.
