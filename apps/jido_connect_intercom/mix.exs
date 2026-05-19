defmodule JidoConnectIntercom.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_connect_intercom,
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
        jido_connect_providers: [Jido.Connect.Intercom]
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
      {:jason, "~> 1.4"},
      {:plug, "~> 1.19", only: :test},
      {:req, "~> 0.5"}
    ]
  end

  defp jido_connect_dep do
    if hex_package_task?() do
      {:jido_connect, "~> 0.1"}
    else
      {:jido_connect, in_umbrella: true}
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
    "Intercom provider package for Jido Connect, including generated Jido tools, OAuth, access token auth, and Intercom REST client helpers."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/mikehostetler/jido_connect",
        "Docs" => "https://hexdocs.pm/jido_connect_intercom"
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
