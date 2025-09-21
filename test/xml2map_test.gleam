import gleam/dynamic/decode
import gleam/list
import gleeunit
import gleeunit/should
import xml2map

pub fn main() -> Nil {
  gleeunit.main()
}

pub type RSS {
  RSS(channel: Channel)
}

pub type Channel {
  Channel(title: String, items: List(Item))
}

pub type Item {
  Item(title: String)
}

pub fn item_decoder() -> decode.Decoder(Item) {
  use title <- decode.subfield(["title", "#text"], decode.string)

  decode.success(Item(title:))
}

pub fn channel_decoder() -> decode.Decoder(Channel) {
  use title <- decode.subfield(["title", "#text"], decode.string)

  use items <- decode.field(
    "item",
    decode.one_of(decode.list(item_decoder()), or: [
      item_decoder() |> decode.map(list.wrap),
    ]),
  )

  decode.success(Channel(title:, items:))
}

pub fn rss_decoder() -> decode.Decoder(RSS) {
  use channel <- decode.subfield(["rss", "channel"], channel_decoder())
  decode.success(RSS(channel:))
}

pub fn parse_rss_feed_test() {
  xml2map.parse(
    from: "<?xml version=\"1.0\"?><rss version=\"2.0\"><channel><title>NASA Space Station News</title><item><title>Louisiana Students to Hear from NASA Astronauts Aboard Space Station</title></item></channel></rss>",
    using: rss_decoder(),
  )
  |> should.equal(
    Ok(
      RSS(
        Channel("NASA Space Station News", [
          Item(
            "Louisiana Students to Hear from NASA Astronauts Aboard Space Station",
          ),
        ]),
      ),
    ),
  )
}
