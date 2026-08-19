defmodule JidoConnectMicrosoftSharepoint.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_connect_microsoft_sharepoint,
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
      env: [jido_connect_providers: [Jido.Connect.MicrosoftSharepoint]]
    ]
  end

  def cli do
    [preferred_envs: [q: :test, quality: :test]]
  end

  defp deps do
    [
      jido_connect_dep(),
      jido_connect_microsoft_dep(),
      jido_connect_microsoft_onedrive_dep(),
      {:jason, "~> 1.4"},
      {:req, "~> 0.6"}
    ]
  end

  defp jido_connect_dep do
    if hex_package_task?(),
      do: {:jido_connect, "~> 0.8"},
      else: {:jido_connect, in_umbrella: true}
  end

  defp jido_connect_microsoft_dep do
    if hex_package_task?(),
      do: {:jido_connect_microsoft, "~> 0.8"},
      else: {:jido_connect_microsoft, in_umbrella: true}
  end

  defp jido_connect_microsoft_onedrive_dep do
    if hex_package_task?(),
      do: {:jido_connect_microsoft_onedrive, "~> 0.8"},
      else: {:jido_connect_microsoft_onedrive, in_umbrella: true}
  end

  defp hex_package_task? do
    Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))
  end

  defp aliases do
    [
      q: ["quality"],
      quality: ["format --check-formatted", "compile --warnings-as-errors", "test --cover"]
    ]
  end

  defp description, do: "Microsoft SharePoint Online connector package for Jido Connect."

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/agentjido/jido_connect",
        "Docs" => "https://hexdocs.pm/jido_connect_microsoft_sharepoint"
      },
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [main: "readme", extras: ["README.md", "CHANGELOG.md"], source_ref: "v0.8.0"]
  end
end
