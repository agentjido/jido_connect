defmodule Jido.Connect.GitHub.Client.CollectionReadsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.GitHub.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_github, :github_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_req_options)
    end)
  end

  test "reads user, installation, repository, and rate pages" do
    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/user" ->
          Req.Test.json(conn, %{id: 1, login: "octocat", type: "User"})

        "/user/installations" ->
          Req.Test.json(conn, %{
            total_count: 1,
            installations: [
              %{
                id: 42,
                account: %{id: 9, login: "acme", type: "Organization"},
                repository_selection: "selected",
                permissions: %{metadata: "read", contents: "write"}
              }
            ]
          })

        "/user/installations/42/repositories" ->
          Req.Test.json(conn, %{
            total_count: 1,
            repositories: [repository_payload()]
          })

        "/rate_limit" ->
          Req.Test.json(conn, %{
            resources: %{core: %{limit: 5_000, remaining: 4_321, reset: 1_800_000_000}}
          })
      end
    end)

    assert {:ok, %{id: 1, login: "octocat"}} = Client.get_user("token")

    assert {:ok, %{total_count: 1, installations: [installation], page: page}} =
             Client.list_user_installations(%{page: 1, per_page: 100}, "token")

    assert installation.id == 42
    assert installation.permissions == %{"contents" => "write", "metadata" => "read"}
    assert page.complete

    assert {:ok, %{total_count: 1, repositories: [repository], page: %{complete: true}}} =
             Client.list_user_installation_repositories(
               42,
               %{page: 1, per_page: 100},
               "token"
             )

    assert repository.full_name == "acme/repo"
    assert repository.visibility == "public"

    assert {:ok, %{resources: %{"core" => %{remaining: 4_321}}}} =
             Client.get_rate_limit("token")
  end

  test "reads pull request reviews, requested reviewers, and exact-SHA checks" do
    sha = String.duplicate("a", 40)
    check_path = "/repos/acme/repo/commits/#{sha}/check-runs"

    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/repos/acme/repo/pulls/7/reviews" ->
          Req.Test.json(conn, [
            %{
              id: 70,
              user: %{id: 2, login: "reviewer"},
              state: "APPROVED",
              submitted_at: "2026-11-08T10:00:00Z",
              commit_id: sha
            }
          ])

        "/repos/acme/repo/pulls/7/requested_reviewers" ->
          Req.Test.json(conn, %{
            users: [%{id: 3, login: "mona"}],
            teams: [%{id: 4, slug: "maintainers", name: "Maintainers"}]
          })

        ^check_path ->
          Req.Test.json(conn, %{
            total_count: 1,
            check_runs: [
              %{
                id: 8,
                name: "test",
                app: %{id: 5, slug: "github-actions"},
                status: "completed",
                conclusion: "success",
                html_url: "https://github.com/acme/repo/runs/8"
              }
            ]
          })
      end
    end)

    assert {:ok, %{reviews: [%{id: 70, state: "APPROVED"}], page: %{complete: true}}} =
             Client.list_pull_request_reviews(
               %{repo: "acme/repo", pull_number: 7, page: 1, per_page: 100},
               "token"
             )

    assert {:ok, %{users: [%{login: "mona"}], teams: [%{slug: "maintainers"}]}} =
             Client.list_pull_request_requested_reviewers("acme/repo", 7, "token")

    assert {:ok, %{check_runs: [%{id: 8, conclusion: "success"}]}} =
             Client.list_check_runs(
               %{repo: "acme/repo", sha: sha, page: 1, per_page: 100},
               "token"
             )
  end

  test "reads exact commit, tree, and blob objects" do
    sha = String.duplicate("b", 40)
    tree_path = "/repos/acme/repo/git/trees/#{sha}"
    blob_path = "/repos/acme/repo/git/blobs/#{sha}"

    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/repos/acme/repo/commits/main" ->
          Req.Test.json(conn, %{
            sha: sha,
            html_url: "https://github.com/acme/repo/commit/#{sha}",
            commit: %{
              message: "Update",
              author: %{date: "2026-11-08T10:00:00Z"},
              committer: %{date: "2026-11-08T10:00:00Z"}
            }
          })

        ^tree_path ->
          Req.Test.json(conn, %{
            sha: sha,
            truncated: false,
            tree: [
              %{
                path: "mix.exs",
                mode: "100644",
                type: "blob",
                sha: String.duplicate("c", 40),
                size: 10
              }
            ]
          })

        ^blob_path ->
          Req.Test.json(conn, %{
            sha: sha,
            encoding: "base64",
            size: 5,
            content: Base.encode64("hello")
          })
      end
    end)

    assert {:ok, %{sha: ^sha, committed_at: "2026-11-08T10:00:00Z"}} =
             Client.get_commit("acme/repo", "main", "token")

    assert {:ok, %{sha: ^sha, truncated: false, entries: [%{path: "mix.exs"}]}} =
             Client.get_tree("acme/repo", sha, true, "token")

    assert {:ok, %{sha: ^sha, encoding: "base64", size: 5}} =
             Client.get_blob("acme/repo", sha, "token")
  end

  test "rejects page values outside the fixed collection limit before transport" do
    assert {:error, %Error.ValidationError{reason: :invalid_pagination}} =
             Client.list_user_installations(%{page: 101, per_page: 100}, "token")
  end

  defp repository_payload do
    %{
      id: 10,
      name: "repo",
      full_name: "acme/repo",
      owner: %{id: 9, login: "acme", type: "Organization"},
      private: false,
      visibility: "public",
      default_branch: "main",
      archived: false,
      fork: false,
      updated_at: "2026-11-08T10:00:00Z",
      html_url: "https://github.com/acme/repo"
    }
  end
end
