defmodule JidoConnectCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_connect,
      version: "0.9.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/agentjido/jido_connect",
      test_coverage: test_coverage(),
      test_ignore_filters: [~r/test\/support\//],
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Jido.Connect.Application, []},
      extra_applications: [:logger],
      env: [jido_connect_providers: [Jido.Connect.MCP]]
    ]
  end

  def cli do
    [
      preferred_envs: [
        q: :test,
        quality: :test
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jido,
       git: "https://github.com/mikehostetler/new_jido.git",
       ref: "54fde0cf79aae9dcc2c00636d9846834abd06852",
       override: true},
      {:arbor_mcp, "== 2.0.0-rc.7"},
      {:jsv, "~> 0.26.2", override: true},
      {:ex_doc, "~> 0.40", only: :docs, runtime: false},
      {:jason, "~> 1.4"},
      {:req, "~> 0.6"},
      {:sourceror, "~> 1.12", only: [:dev, :test], runtime: false},
      {:splode, "~> 0.3.0"},
      {:spark, "~> 2.7"},
      {:telemetry, "~> 1.3"},
      {:zoi,
       git: "https://github.com/mikehostetler/zoi.git",
       ref: "2fff2a23e23e7ac0b26f62f49bbc1b12f7818ac9",
       override: true}
    ]
  end

  defp aliases do
    [
      q: ["quality"],
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test --cover"
      ]
    ]
  end

  defp description do
    "Spark DSL and runtime contracts for compiling integration packages into Jido actions, sensors, and plugins."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/agentjido/jido_connect",
        "Docs" => "https://hexdocs.pm/jido_connect"
      },
      files: ~w(lib guides mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "guides/mcp_bridge.md",
        "guides/authoring_connector.md",
        "CHANGELOG.md"
      ],
      source_ref: "release/3.0"
    ]
  end

  defp test_coverage do
    [
      summary: [threshold: 80],
      ignore_modules: [
        ~r/^Jido\.Connect\.Dsl(\.|$)/,
        ~r/^Jido\.Connect\.Dev\./,
        ~r/^Jido\.Connect\.Error\.(Auth|Config|Execution|Internal|Invalid|Provider)$/,
        ~r/^Mix\.Tasks\./
      ]
    ]
  end
end
