import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result

pub type Xml

pub type DecodeError {
  UnableToDecode(List(decode.DecodeError))
}

pub fn parse(
  from json: String,
  using decoder: decode.Decoder(t),
) -> Result(t, DecodeError) {
  do_parse(from: json, using: decoder)
}

@target(erlang)
fn do_parse(
  from json: String,
  using decoder: decode.Decoder(t),
) -> Result(t, DecodeError) {
  let bits = bit_array.from_string(json)
  parse_bits(bits, decoder)
}

pub fn parse_bits(
  from json: BitArray,
  using decoder: decode.Decoder(t),
) -> Result(t, DecodeError) {
  use dynamic_value <- result.try(decode_to_dynamic(json))
  decode.run(dynamic_value, decoder)
  |> result.map_error(UnableToDecode)
}

@external(erlang, "xml2map_ffi", "decode")
fn decode_to_dynamic(json: BitArray) -> Result(Dynamic, DecodeError)
