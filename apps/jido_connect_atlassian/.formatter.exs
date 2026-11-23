# Used by "mix format"
[
  import_deps: [:jido_connect],
  plugins: [Spark.Formatter],
  inputs: ["{mix,.formatter}.exs", "{config,lib,support,test}/**/*.{ex,exs}"]
]
