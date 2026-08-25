defmodule JidoConnect.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.8.0",
      start_permanent: Mix.env() == :prod,
      name: "Jido Connect",
      source_url: "https://github.com/agentjido/jido_connect",
      docs: docs(),
      deps: deps(),
      aliases: aliases()
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

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:ex_doc, "~> 0.40", only: :docs, runtime: false}
    ]
  end

  defp aliases do
    [
      q: ["quality"],
      quality: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md",
        "LICENSE",
        "usage-rules.md",
        "apps/jido_connect/guides/authoring_connector.md",
        "docs/architecture.md",
        "docs/authoring_integrations.md",
        "docs/generated_jido_modules.md",
        "docs/google_connector_conventions.md",
        "docs/google_extension_patterns.md",
        "docs/google_polling_checkpoints.md",
        "docs/google_scope_audit.md",
        "docs/host_owned_storage.md",
        "docs/jido_connect_ecosystem_migration.md",
        "docs/github_auth.md",
        "docs/github_webhooks.md",
        "docs/github_end_to_end.md",
        "docs/slack_auth.md",
        "docs/release_checklist.md"
      ],
      groups_for_extras: [
        Guides: ~r/docs\/.*/
      ]
    ]
  end
end
