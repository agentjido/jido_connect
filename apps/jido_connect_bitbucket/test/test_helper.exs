ExUnit.start()

defmodule Jido.Connect.Bitbucket.TestRuntime do
  @moduledoc false

  alias Jido.Connect.{Connection, Context}

  def build(opts \\ []) do
    connection =
      Connection.new!(%{
        id: Keyword.get(opts, :connection_id, "bitbucket_conn_1"),
        provider: Keyword.get(opts, :provider, :bitbucket),
        profile: Keyword.get(opts, :profile, :api_token),
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{id: Keyword.get(opts, :account, "bitbucket-account-1")},
        status: :connected,
        scopes: ["read:pullrequest:bitbucket"],
        metadata: endpoint_metadata(opts)
      })

    %{
      provider_client: Keyword.get(opts, :provider_client, Jido.Connect.Bitbucket.MockClient),
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

  defp endpoint_metadata(opts) do
    case Keyword.fetch(opts, :endpoint) do
      {:ok, endpoint} -> %{api_endpoint: endpoint}
      :error -> %{}
    end
  end
end

defmodule Jido.Connect.Bitbucket.MockClient do
  @moduledoc false

  alias Jido.Connect.Bitbucket.Client.Request

  def list_pull_requests("acme", "widgets", %Request{} = request, opts) do
    send(self(), {:bitbucket_list_pull_requests, opts})

    {:ok,
     %{
       kind: "pull_requests",
       account: Request.account(request),
       workspace: "acme",
       repository: "widgets",
       state: Keyword.fetch!(opts, :state),
       count: 1,
       page: Keyword.fetch!(opts, :page),
       page_length: Keyword.fetch!(opts, :limit),
       total: 2,
       next_page: "https://api.bitbucket.org/2.0/repositories/acme/widgets/pullrequests?page=2",
       items: [
         %{
           id: 42,
           title: "Add reviewed action",
           state: "open",
           source_branch: "feature/reader",
           destination_branch: "main",
           author: %{id: "{author-1}", display_name: "Ada Lovelace"},
           draft: false,
           created_at: "2026-08-18T10:00:00Z",
           updated_at: "2026-08-19T10:00:00Z",
           url: "https://bitbucket.org/acme/widgets/pull-requests/42"
         }
       ]
     }}
  end
end

unless Process.whereis(Req.Test.Ownership) do
  {:ok, _pid} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
