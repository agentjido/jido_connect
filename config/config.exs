import Config

config :spark, :formatter,
  remove_parens?: true,
  "Jido.Connect": [
    extensions: [Jido.Connect.Dsl.Extension]
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
