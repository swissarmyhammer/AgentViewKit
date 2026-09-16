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
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: doing
position_ordinal: '8180'
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