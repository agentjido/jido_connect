[
  import_deps: [:jido_connect, :spark],
  plugins: [Spark.Formatter],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  spark_locals_without_parens: [Jido.Connect]
]
