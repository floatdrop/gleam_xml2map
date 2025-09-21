# xml2map

[![Package Version](https://img.shields.io/hexpm/v/xml2map)](https://hex.pm/packages/xml2map)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/xml2map/)

```sh
gleam add xml2map@1
```

```gleam
import gleam/dynamic/decode
import gleam/list
import gleam/result.{try}
import xml2map

pub type Node {
  Node(children: List(Child))
}

pub fn node_decoder() -> decode.Decoder(Node) {
  // Decode one child or multiple child to List
  use children <- decode.field(
    "child",
    decode.one_of(decode.list(child_decoder()), or: [
      child_decoder() |> decode.map(list.wrap),
    ]),
  )

  decode.success(Node(children:))
}

pub type Child {
  Child(name: String, text: String)
}

pub fn child_decoder() -> decode.Decoder(Child) {
  use name <- decode.field("@name", decode.string)
  use text <- decode.field("#text", decode.string)

  decode.success(Child(name:, text:))
}

pub fn main() -> Nil {
  use node <- try(xml2map.parse("<node><child name=\"A\">text1</child><child name=\"B\">text2</child></node>", using: node_decoder()))
}
```

Further documentation can be found at <https://hexdocs.pm/xml2map>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
