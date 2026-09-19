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
      # Cowlib 2.20.0 still has the three recorded encoder advisories.
      # Connect uses the MCP client only. Keep the focused import/header tests.
      # Reviewed 2026-09-13; see docs/v3_status.md. Issue #79 remains open.
      hex: [
        ignore_advisories: [
          "EEF-CVE-2026-43966",
          "EEF-CVE-2026-43969",
          "EEF-CVE-2026-43971"
        ]
      ],
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
      {:jido, "== 3.0.0-beta.1"},
      {:jido_action, "== 3.0.0-beta.11"},
      {:jido_signal, "== 3.0.0-beta.4"},
      {:ex_mcp, "~> 1.4"},
      {:ex_doc, "~> 0.40", only: :docs, runtime: false},
      {:jason, "~> 1.4"},
      {:req, "~> 0.6"},
      {:sourceror, "~> 1.12", only: [:dev, :test], runtime: false},
      {:splode, "~> 0.3.0"},
      {:spark, "~> 2.7"},
      {:telemetry, "~> 1.3"},
      {:zoi, "~> 0.18"}
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
