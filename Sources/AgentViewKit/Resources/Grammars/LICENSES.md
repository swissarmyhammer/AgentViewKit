# Grammar licenses

The files in this folder are TextMate grammars in JSON. `GrammarBundle`
loads them. Each file is an unchanged copy from the npm package
`tm-grammars` 1.32.20 (https://github.com/shikijs/textmate-grammars-themes,
MIT license). That package converts each upstream
grammar to JSON. The table gives the upstream source, the commit, and the
license of each grammar.

GrammarBundleTests makes sure that the table has one row for each grammar
file in this folder, and no other row.

| File | Language | Upstream source | Commit | License |
|---|---|---|---|---|
| `css.json` | CSS | https://github.com/microsoft/vscode/blob/af600487b1e94374d9f48f57cbf2cad24656b07f/extensions/css/syntaxes/css.tmLanguage.json | af600487b1e94374d9f48f57cbf2cad24656b07f | MIT |
| `go.json` | Go | https://github.com/microsoft/vscode/blob/091ef378baaa141c8bc4bbe9775d4cb3bd655a80/extensions/go/syntaxes/go.tmLanguage.json | 091ef378baaa141c8bc4bbe9775d4cb3bd655a80 | MIT |
| `html.json` | HTML | https://github.com/microsoft/vscode/blob/45324363153075dab0482312ae24d8c068d81e4f/extensions/html/syntaxes/html.tmLanguage.json | 45324363153075dab0482312ae24d8c068d81e4f | MIT |
| `javascript.json` | JavaScript | https://github.com/microsoft/vscode/blob/210541906e5a96ab39f9c753f921b1bd35f4138b/extensions/javascript/syntaxes/JavaScript.tmLanguage.json | 210541906e5a96ab39f9c753f921b1bd35f4138b | MIT |
| `python.json` | Python | https://github.com/microsoft/vscode/blob/cf4c9e469d521fa5f33353737e8157eb0789ad02/extensions/python/syntaxes/MagicPython.tmLanguage.json | cf4c9e469d521fa5f33353737e8157eb0789ad02 | MIT |
| `rust.json` | Rust | https://github.com/microsoft/vscode/blob/af600487b1e94374d9f48f57cbf2cad24656b07f/extensions/rust/syntaxes/rust.tmLanguage.json | af600487b1e94374d9f48f57cbf2cad24656b07f | MIT |
| `shell.json` | Shell | https://github.com/microsoft/vscode/blob/9473445f7d3dcb5c579f42ece8b6c18c43c63ed3/extensions/shellscript/syntaxes/shell-unix-bash.tmLanguage.json | 9473445f7d3dcb5c579f42ece8b6c18c43c63ed3 | MIT |
| `sql.json` | SQL | https://github.com/microsoft/vscode/blob/af600487b1e94374d9f48f57cbf2cad24656b07f/extensions/sql/syntaxes/sql.tmLanguage.json | af600487b1e94374d9f48f57cbf2cad24656b07f | MIT |
| `swift.json` | Swift | https://github.com/jtbandes/swift-tmlanguage/blob/2be007b6bc88e54a0edfd3c313ff31276edc923d/Swift.tmLanguage.yaml | 2be007b6bc88e54a0edfd3c313ff31276edc923d | MIT |
| `toml.json` | TOML | https://github.com/textmate/toml.tmbundle/blob/e82b64c1e86396220786846201e9aa3f0a2d9ca2/Syntaxes/TOML.tmLanguage | e82b64c1e86396220786846201e9aa3f0a2d9ca2 | TextMate bundle license (see below) |
| `typescript.json` | TypeScript | https://github.com/microsoft/vscode/blob/210541906e5a96ab39f9c753f921b1bd35f4138b/extensions/typescript-basics/syntaxes/TypeScript.tmLanguage.json | 210541906e5a96ab39f9c753f921b1bd35f4138b | MIT |
| `yaml.json` | YAML | https://github.com/textmate/yaml.tmbundle/blob/e54ceae3b719506dba7e481a77cea4a8b576ae46/Syntaxes/YAML.tmLanguage | e54ceae3b719506dba7e481a77cea4a8b576ae46 | TextMate bundle license (see below) |

## License texts

### MIT

These copyright notices apply to the grammars with the MIT license:

- microsoft/vscode: Copyright (c) 2015 - present Microsoft Corporation
- jtbandes/swift-tmlanguage: Copyright 2023 Jacob Bandes-Storch
- shikijs/textmate-grammars-themes (the JSON conversion): Copyright (c) 2021
  Pine Wu, Copyright (c) 2023 Anthony Fu

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to
> deal in the Software without restriction, including without limitation the
> rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
> sell copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
> FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
> IN THE SOFTWARE.

### TextMate bundle license

The TextMate bundle license, from the README of textmate/toml.tmbundle and
textmate/yaml.tmbundle:

> Permission to copy, use, modify, sell and distribute this software is
> granted. This software is provided "as is" without express or implied
> warranty, and with no claim as to its suitability for any purpose.
