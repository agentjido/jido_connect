defmodule JidoConnectGitHub.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_connect_github,
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
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: [
        jido_connect_providers: [Jido.Connect.GitHub]
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      jido_connect_dep(),
      {:jason, "~> 1.4"},
      {:plug, "~> 1.20", only: :test},
      {:req, "~> 0.6"}
    ]
  end

  defp jido_connect_dep do
    if hex_package_task?() do
      {:jido_connect, "~> 0.8"}
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
    "GitHub provider package for Jido Connect, including generated Jido tools, OAuth, GitHub App auth, REST client, and webhook helpers."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/agentjido/jido_connect",
        "Docs" => "https://hexdocs.pm/jido_connect_github"
      },
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v0.8.0"
    ]
  end

  defp test_coverage do
    [
      summary: [threshold: 80],
      ignore_modules: [
        ~r/^Mix\.Tasks\./
      ]
    ]
  end
end
