defmodule Jido.Connect.GitHub.CollectionActionsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.GitHub.Connections

  defmodule Client do
    def get_user("token"), do: {:ok, %{id: 1, login: "octocat"}}

    def list_user_installations(%{page: 1, per_page: 100}, "token") do
      {:ok,
       %{
         installations: [%{id: 42, permissions: %{"metadata" => "read"}}],
         total_count: 1,
         page: %{complete: true}
       }}
    end

    def list_user_installation_repositories(42, %{page: 1, per_page: 100}, "token") do
      {:ok,
       %{
         repositories: [%{id: 2, name: "repo", full_name: "acme/repo"}],
         total_count: 1,
         page: %{complete: true}
       }}
    end

    def get_rate_limit("token"), do: {:ok, %{resources: %{"core" => %{remaining: 100}}}}

    def list_pull_request_reviews(
          %{repo: "acme/repo", pull_number: 7, page: 1, per_page: 100},
          "token"
        ) do
      {:ok, %{reviews: [%{id: 70, state: "APPROVED"}], page: %{complete: true}}}
    end

    def list_pull_request_requested_reviewers("acme/repo", 7, "token") do
      {:ok, %{users: [%{login: "mona"}], teams: [%{slug: "maintainers"}]}}
    end

    def list_check_runs(
          %{repo: "acme/repo", sha: sha, page: 1, per_page: 100},
          "token"
        ) do
      {:ok,
       %{
         check_runs: [%{id: 8, name: "test", status: "completed", conclusion: "success"}],
         total_count: 1,
         page: %{complete: true},
         sha: sha
       }}
    end

    def get_commit("acme/repo", "main", "token") do
      {:ok, %{sha: String.duplicate("a", 40), committed_at: "2026-11-08T10:00:00Z"}}
    end

    def get_tree("acme/repo", sha, true, "token") do
      {:ok, %{sha: sha, entries: [%{path: "mix.exs", type: "blob"}], truncated: false}}
    end

    def get_blob("acme/repo", sha, "token") do
      {:ok, %{sha: sha, encoding: "base64", size: 5, content: Base.encode64("hello")}}
    end
  end

  test "invokes the host collection account actions" do
    assert {:ok, %{user: %{login: "octocat"}}} = invoke("github.user.get", %{})

    assert {:ok, %{installations: [%{id: 42}]}} =
             invoke("github.user_installation.list", %{page: 1, per_page: 100})

    assert {:ok, %{repositories: [%{full_name: "acme/repo"}]}} =
             invoke("github.user_installation_repository.list", %{
               installation_id: 42,
               page: 1,
               per_page: 100
             })

    assert {:ok, %{resources: %{"core" => %{remaining: 100}}}} =
             invoke("github.rate_limit.get", %{})
  end

  test "invokes pull request and check evidence actions" do
    sha = String.duplicate("b", 40)

    assert {:ok, %{reviews: [%{state: "APPROVED"}]}} =
             invoke("github.pull_request_review.list", %{
               repo: "acme/repo",
               pull_number: 7,
               page: 1,
               per_page: 100
             })

    assert {:ok, %{users: [%{login: "mona"}], teams: [%{slug: "maintainers"}]}} =
             invoke("github.pull_request_requested_reviewer.list", %{
               repo: "acme/repo",
               pull_number: 7
             })

    assert {:ok, %{check_runs: [%{conclusion: "success"}]}} =
             invoke("github.check_run.list", %{
               repo: "acme/repo",
               sha: sha,
               page: 1,
               per_page: 100
             })
  end

  test "invokes exact commit, tree, and blob actions" do
    sha = String.duplicate("c", 40)

    assert {:ok, %{commit: %{sha: returned_sha}}} =
             invoke("github.commit.get", %{repo: "acme/repo", ref: "main"})

    assert returned_sha == String.duplicate("a", 40)

    assert {:ok, %{sha: ^sha, entries: [%{path: "mix.exs"}], truncated: false}} =
             invoke("github.git_tree.get", %{repo: "acme/repo", sha: sha, recursive: true})

    assert {:ok, %{sha: ^sha, encoding: "base64", size: 5}} =
             invoke("github.git_blob.get", %{repo: "acme/repo", sha: sha})
  end

  defp invoke(action_id, input) do
    {:ok, connection} =
      Connections.github_app_user_connection(
        %{login: "octocat", id: 1},
        tenant_id: "tenant-1",
        owner_id: "user-1",
        permissions: %{
          "metadata" => "read",
          "contents" => "read",
          "pull_requests" => "read",
          "checks" => "read"
        }
      )

    lease = %{
      connection_id: connection.id,
      provider: :github,
      profile: :user,
      tenant_id: connection.tenant_id,
      owner_type: connection.owner_type,
      owner_id: connection.owner_id,
      scopes: connection.scopes,
      expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
      fields: %{access_token: "token", github_client: Client}
    }

    Connect.invoke(Jido.Connect.GitHub, action_id, input,
      context: %{
        tenant_id: "tenant-1",
        actor: %{id: "user-1"},
        connection: connection
      },
      credential_lease: lease,
      policy: fn _operation, _input, _context, _connection -> :ok end
    )
  end
end
