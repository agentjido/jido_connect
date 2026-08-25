defmodule JidoConnectTrello.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_connect_trello,
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
      test_coverage: [summary: [threshold: 80]],
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: [jido_connect_providers: [Jido.Connect.Trello]]
    ]
  end

  def cli, do: [preferred_envs: [q: :test, quality: :test]]

  defp deps do
    [
      jido_connect_dep(),
      jido_connect_mcp_dep(),
      {:ex_mcp, "~> 1.0"},
      {:jason, "~> 1.4"}
    ]
  end

  defp jido_connect_dep do
    if hex_package_task?(),
      do: {:jido_connect, "~> 0.8"},
      else: {:jido_connect, in_umbrella: true}
  end

  defp jido_connect_mcp_dep do
    if hex_package_task?(),
      do: {:jido_connect_mcp, "~> 0.8"},
      else: {:jido_connect_mcp, in_umbrella: true}
  end

  defp hex_package_task?,
    do: Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))

  defp aliases do
    [
      q: ["quality"],
      quality: ["format --check-formatted", "compile --warnings-as-errors", "test --cover"]
    ]
  end

  defp description do
    "Reviewed Trello provider actions over the official hosted Trello MCP endpoint."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/agentjido/jido_connect",
        "Docs" => "https://hexdocs.pm/jido_connect_trello"
      },
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [main: "readme", extras: ["README.md", "CHANGELOG.md"], source_ref: "v0.8.0"]
  end
end
