defmodule JidoConnectCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_connect,
      version: "0.8.0",
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
      extra_applications: [:logger]
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
      {:jido, "~> 2.3"},
      {:jido_action, "~> 2.3"},
      {:jido_signal, "~> 2.2"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.6"},
      {:plug, "~> 1.20", only: :test},
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
      extras: ["README.md", "CHANGELOG.md", "guides/authoring_connector.md"],
      source_ref: "v0.8.0"
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
