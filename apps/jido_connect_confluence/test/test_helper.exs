ExUnit.start()

defmodule Jido.Connect.Confluence.TestRuntime do
  @moduledoc false

  alias Jido.Connect.{Connection, Context}

  def build(opts \\ []) do
    connection =
      Connection.new!(%{
        id: "confluence_conn_1",
        provider: Keyword.get(opts, :provider, :confluence),
        profile: Keyword.get(opts, :profile, :api_token),
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{id: "confluence-account-1"},
        status: :connected,
        scopes: ["read:space:confluence", "read:page:confluence", "write:page:confluence"],
        metadata: %{site_url: Keyword.get(opts, :site_url, "https://example.atlassian.net/wiki")}
      })

    %{
      provider_client: Keyword.get(opts, :provider_client, Jido.Connect.Confluence.MockClient),
      context:
        Context.new!(%{
          tenant_id: "tenant_1",
          actor: %{id: "user_1", type: :app_user},
          connection: connection
        }),
      credentials: %{
        email: Keyword.get(opts, :email, "user@example.com"),
        api_token: Keyword.get(opts, :api_token, "api-token")
      }
    }
  end
end

defmodule Jido.Connect.Confluence.MockClient do
  @moduledoc false

  alias Jido.Connect.Confluence.Client.Request
  alias Jido.Connect.Confluence.Input.{Pages, Spaces}

  def get_space(input, %Request{} = request) do
    with {:ok, %{key: "OPS"}} <- Spaces.validate_get(input) do
      send(self(), :confluence_get_space)

      {:ok,
       %{
         kind: "confluence_space",
         account: Request.account(request),
         id: "space-1",
         key: "OPS",
         name: "Operations",
         type: "global",
         status: "current",
         homepage_id: "home-1",
         url: "https://example.atlassian.net/wiki/spaces/OPS"
       }}
    end
  end

  def list_pages(input, %Request{} = request) do
    with {:ok, %{space_key: "OPS"} = input} <- Pages.validate_list(input) do
      send(self(), {:confluence_list_pages, limit: input.limit, cursor: input.cursor})

      {:ok,
       %{
         kind: "confluence_pages",
         account: Request.account(request),
         space: %{id: "space-1", key: "OPS"},
         count: 0,
         limit: input.limit,
         next_cursor: nil,
         items: []
       }}
    end
  end

  def get_page(input, %Request{} = request) do
    with {:ok, %{id: "page-1"} = input} <- Pages.validate_get(input) do
      send(self(), {:confluence_get_page, max_characters: input.max_characters})

      {:ok,
       %{
         kind: "confluence_page",
         account: Request.account(request),
         id: "page-1",
         title: "Runbook",
         revision_id: "4",
         version: 4,
         space_id: "space-1",
         text: "text",
         character_count: 4,
         truncated: false
       }}
    end
  end

  def create_page(input, %Request{}) do
    with {:ok, %{title: "Runbook", space_key: "OPS", markdown: "text"} = input} <-
           Pages.validate_create(input) do
      send(self(), {:confluence_create_page, parent_id: input.parent_id})
      {:ok, effect("create", 1)}
    end
  end

  def update_page(input, %Request{}) do
    with {:ok,
          %{id: "page-1", space_key: "OPS", markdown: "text", last_pushed_version: 4} = input} <-
           Pages.validate_update(input) do
      send(
        self(),
        {:confluence_update_page,
         [
           force: input.force,
           title: input.title,
           version_message: input.version_message
         ]}
      )

      {:ok, effect("update", 5)}
    end
  end

  def delete_page(input, %Request{}) do
    with {:ok, %{id: "page-1"}} <- Pages.validate_delete(input) do
      send(self(), :confluence_delete_page)

      {:ok,
       %{
         kind: "confluence_page_effect",
         effect: "delete",
         submitted: true,
         page: %{id: "page-1"}
       }}
    end
  end

  defp effect(effect, version) do
    %{
      kind: "confluence_page_effect",
      effect: effect,
      submitted: true,
      page: %{id: "page-1", title: "Runbook", space_id: "space-1", version: version}
    }
  end
end

unless Process.whereis(Req.Test.Ownership) do
  {:ok, _pid} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
