use Mix.Config

case Mix.env() do
  :test_alternative_map ->
    config :configparser_ex,
      map_implementation: OrderedMap

  _ ->
    config :configparser_ex,
      map_implementation: Map
end
