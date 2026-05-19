defmodule Jido.Connect.Demo.Integrations do
  @moduledoc false

  alias Jido.Connect.Catalog

  @integrations [
    %{
      id: "github",
      module: Jido.Connect.GitHub,
      status: :available,
      description:
        "Issues actions, GitHub App setup, OAuth callback capture, and webhook intake.",
      paths: %{
        setup: "/integrations/github/setup",
        setup_complete: "/integrations/github/setup/complete",
        oauth_start: "/integrations/github/oauth/start",
        oauth_callback: "/integrations/github/oauth/callback",
        webhook: "/integrations/github/webhook"
      },
      checks: [
        %{label: "App setup callback", method: "GET", path: "/integrations/github/setup"},
        %{
          label: "Manifest conversion callback",
          method: "GET",
          path: "/integrations/github/setup/complete"
        },
        %{
          label: "OAuth authorization start",
          method: "GET",
          path: "/integrations/github/oauth/start"
        },
        %{label: "OAuth callback", method: "GET", path: "/integrations/github/oauth/callback"},
        %{label: "Webhook receiver", method: "POST", path: "/integrations/github/webhook"}
      ]
    },
    %{
      id: "slack",
      module: Jido.Connect.Slack,
      status: :available,
      description:
        "Generated channel listing and message posting actions, plus OAuth and signed request helpers.",
      paths: %{
        console: "/integrations/slack",
        oauth_callback: "/integrations/slack/oauth/callback",
        events: "/integrations/slack/events",
        interactivity: "/integrations/slack/interactivity"
      },
      checks: [
        %{label: "Local Slack console", method: "GET", path: "/integrations/slack"},
        %{label: "OAuth callback", method: "GET", path: "/integrations/slack/oauth/callback"},
        %{label: "Events receiver", method: "POST", path: "/integrations/slack/events"},
        %{
          label: "Interactivity receiver",
          method: "POST",
          path: "/integrations/slack/interactivity"
        }
      ]
    },
    %{
      id: "mcp",
      module: Jido.Connect.MCP,
      status: :available,
      description:
        "Bridge for configured MCP servers with endpoint and tool policy enforced through Jido Connect scopes.",
      paths: %{},
      checks: []
    },
    %{
      id: "google",
      module: Jido.Connect.Google.Sheets,
      status: :available,
      description:
        "Google OAuth user flow and multi-product catalog tools (Sheets, Gmail, Drive, Calendar) for local smoke testing.",
      paths: %{
        console: "/integrations/google",
        oauth_start: "/integrations/google/oauth/start",
        oauth_callback: "/integrations/google/oauth/callback"
      },
      checks: [
        %{label: "Local Google console", method: "GET", path: "/integrations/google"},
        %{
          label: "OAuth authorization start",
          method: "GET",
          path: "/integrations/google/oauth/start"
        },
        %{label: "OAuth callback", method: "GET", path: "/integrations/google/oauth/callback"}
      ]
    }
  ]

  def all(opts \\ []) do
    @integrations
    |> Enum.map(&with_catalog/1)
    |> search(Keyword.get(opts, :query))
  end

  def catalog(opts \\ []) do
    modules =
      integration_modules() ++
        Jido.Connect.Demo.GoogleRuntime.google_modules()

    opts
    |> Keyword.put(:modules, Enum.uniq(modules))
    |> Catalog.discover()
    |> Enum.map(&Catalog.to_map/1)
    |> Enum.uniq_by(& &1.package)
  end

  def api_index do
    Enum.map(all(), fn integration ->
      %{
        id: integration.id,
        name: integration.name,
        package: integration.package,
        status: integration.status,
        auth_modes: integration.auth_modes,
        description: integration.description,
        paths: integration.paths,
        actions: Enum.map(integration.actions, & &1.id),
        triggers: Enum.map(integration.triggers, & &1.id)
      }
    end)
  end

  defp with_catalog(%{module: module} = integration) do
    catalog = Catalog.entry(module, status: integration.status)

    integration
    |> Map.put(:name, catalog.name)
    |> Map.put(:package, to_string(catalog.package))
    |> Map.put(:category, catalog.category)
    |> Map.put(:auth_modes, Enum.map(catalog.auth_profiles, &auth_mode/1))
    |> Map.put(:actions, catalog.actions)
    |> Map.put(:triggers, catalog.triggers)
  end

  defp with_catalog(integration) do
    integration
    |> Map.put_new(:category, nil)
    |> Map.put_new(:actions, [])
    |> Map.put_new(:triggers, [])
  end

  defp integration_modules do
    @integrations
    |> Enum.flat_map(fn
      %{module: module, status: :available} -> [module]
      _other -> []
    end)
  end

  defp search(integrations, query) when query in [nil, ""], do: integrations

  defp search(integrations, query) do
    query = String.downcase(query)

    Enum.filter(integrations, fn integration ->
      integration
      |> searchable_text()
      |> String.contains?(query)
    end)
  end

  defp searchable_text(integration) do
    [
      integration.id,
      integration.name,
      integration.package,
      integration.status,
      integration.description,
      integration.auth_modes,
      Enum.map(integration.actions, & &1.id),
      Enum.map(integration.triggers, & &1.id)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join(" ", &to_string/1)
    |> String.downcase()
  end

  defp auth_mode(%Catalog.AuthProfileSummary{label: label}) when is_binary(label), do: label

  defp auth_mode(%Catalog.AuthProfileSummary{} = profile) do
    profile.kind
    |> to_string()
    |> String.replace("_", " ")
  end
end
