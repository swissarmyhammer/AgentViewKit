---
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: todo
position_ordinal: ae80
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
- [ ] Round-trip of a nested object through `Codable` is equal.
- [ ] `prettyPrinted` output is stable across runs for the same value.
- [ ] `JSONValue(json: "{bad")` throws.

## Tests
- [ ] `Tests/AgentViewKitTests/Model/JSONValueTests.swift`: round-trip, subscripts, conversions, pretty print, parse error.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.