defmodule JidoConnectMCP.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_connect_mcp,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/mikehostetler/jido_connect",
      test_coverage: test_coverage(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: [
        jido_connect_providers: [Jido.Connect.MCP]
      ]
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

  defp deps do
    [
      jido_connect_dep(),
      jido_mcp_dep(),
      {:jason, "~> 1.4"},
      {:plug, "~> 1.19"},
      # Transitive Hex deps of the jido_mcp git dependency – declared
      # explicitly so the umbrella can resolve them from the local Hex
      # cache without network access.
      {:anubis_mcp, "~> 1.1"},
      {:peri, "~> 0.8.5", override: true},
      {:jido, "~> 2.2"},
      {:jido_action, "~> 2.2"},
      {:jido_signal, "~> 2.1"},
      {:zoi, "~> 0.18"}
    ]
  end

  defp jido_connect_dep do
    if hex_package_task?() do
      {:jido_connect, "~> 0.1"}
    else
      {:jido_connect, in_umbrella: true}
    end
  end

  defp jido_mcp_dep do
    if hex_package_task?() do
      {:jido_mcp, "~> 0.1"}
    else
      {:jido_mcp, github: "agentjido/jido_mcp", branch: "main", override: true}
    end
  end

  defp hex_package_task? do
    Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))
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
    "MCP bridge package for Jido Connect, exposing allowlisted MCP endpoints and tools through generated Jido actions."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/mikehostetler/jido_connect",
        "Docs" => "https://hexdocs.pm/jido_connect_mcp"
      },
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v0.1.0"
    ]
  end

  defp test_coverage do
    [
      summary: [threshold: 80]
    ]
  end
end
