defmodule JidoConnect.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.9.0",
      start_permanent: Mix.env() == :prod,
      name: "Jido Connect",
      source_url: "https://github.com/agentjido/jido_connect",
      # Cowlib 2.20.0 has two won't-fix encoder advisories.
      # Connect uses the MCP client only and does not call the affected encoders.
      # Accepted 2026-09-19; see docs/v3_status.md and closed issue #79.
      hex: [
        ignore_advisories: [
          "EEF-CVE-2026-43966",
          "EEF-CVE-2026-43969"
        ]
      ],
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
      {:jido,
       git: "https://github.com/agentjido/jido.git",
       ref: "90763478104f1edbf0afcfcf9444621c3f9755e8",
       override: true},
      {:jido_action,
       git: "https://github.com/agentjido/jido_action.git",
       ref: "8e9b3f7b268e175091b0eb3720bab3b8633d3c24",
       override: true},
      {:zoi,
       git: "https://github.com/mikehostetler/zoi.git",
       ref: "2fff2a23e23e7ac0b26f62f49bbc1b12f7818ac9",
       override: true},
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
        "apps/jido_connect/guides/mcp_bridge.md",
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
