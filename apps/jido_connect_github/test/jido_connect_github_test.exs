defmodule Jido.Connect.GitHubTest do
  use ExUnit.Case
  alias Jido.Connect

  defmodule FakeGitHubClient do
    def list_repositories(%{auth_profile: :installation, page: 2, per_page: 10}, "token") do
      {:ok,
       %{
         total_count: 1,
         repositories: [
           %{
             id: 10,
             name: "repo",
             full_name: "org/repo",
             owner: %{login: "org", type: "Organization"},
             private: true,
             default_branch: "main",
             url: "https://github.test/org/repo"
           }
         ]
       }}
    end

    def list_repositories(%{page: 2, per_page: 10}, "token") do
      {:ok,
       %{
         total_count: 1,
         repositories: [
           %{
             id: 10,
             name: "repo",
             full_name: "org/repo",
             owner: %{login: "org", type: "Organization"},
             private: true,
             default_branch: "main",
             url: "https://github.test/org/repo"
           }
         ]
       }}
    end

    def search_repositories(
          %{
            q: "jido org:acme language:elixir topic:agent archived:false fork:false",
            sort: "stars",
            direction: "desc",
            page: 2,
            per_page: 10
          },
          "token"
        ) do
      {:ok,
       %{
         total_count: 1,
         repositories: [
           %{
             id: 10,
             name: "repo",
             full_name: "acme/repo",
             owner: %{login: "acme", type: "Organization"},
             private: false,
             default_branch: "main",
             url: "https://github.test/acme/repo",
             description: "Jido connector",
             language: "Elixir",
             stargazers_count: 42,
             forks_count: 7,
             open_issues_count: 3,
             archived: false,
             fork: false,
             updated_at: "2026-04-29T10:00:00Z"
           }
         ]
       }}
    end

    def get_repository("org", "repo", "token") do
      {:ok,
       %{
         id: 10,
         name: "repo",
         full_name: "org/repo",
         owner: %{login: "org", type: "Organization"},
         private: true,
         default_branch: "main",
         permissions: %{admin: false, push: true, pull: true},
         url: "https://github.test/org/repo"
       }}
    end

    def list_branches(%{repo: "org/repo", page: 2, per_page: 10}, "token") do
      {:ok,
       [
         %{
           name: "main",
           sha: "abc123",
           commit: %{
             sha: "abc123",
             url: "https://api.github.test/repos/org/repo/commits/abc123"
           },
           protected: true,
           protection_url: "https://api.github.test/repos/org/repo/branches/main/protection"
         }
       ]}
    end

    def create_branch(
          "org/repo",
          %{branch: "feature/example", source_ref: "main"},
          "token"
        ) do
      {:ok,
       %{
         ref: "refs/heads/feature/example",
         sha: "abc123",
         url: "https://api.github.test/repos/org/repo/git/refs/heads/feature/example",
         object: %{
           sha: "abc123",
           type: "commit",
           url: "https://api.github.test/repos/org/repo/git/commits/abc123"
         }
       }}
    end

    def list_commits(
          %{repo: "org/repo", ref: "main", path: "lib/example.ex", page: 2, per_page: 10},
          "token"
        ) do
      {:ok,
       [
         %{
           sha: "abc123",
           url: "https://github.test/org/repo/commit/abc123",
           message: "Add example",
           author: %{login: "octocat", name: "Octo Cat"},
           committer: %{login: "mona", name: "Mona"},
           authored_at: "2026-04-29T10:00:00Z",
           committed_at: "2026-04-29T10:05:00Z",
           parents: [%{sha: "def456"}]
         }
       ]}
    end

    def compare_refs(
          %{repo: "org/repo", base: "main", head: "feature/ref", page: 2, per_page: 10},
          "token"
        ) do
      {:ok,
       %{
         status: "ahead",
         ahead_by: 2,
         behind_by: 0,
         total_commits: 2,
         commits: [
           %{
             sha: "abc123",
             url: "https://github.test/org/repo/commit/abc123",
             message: "Add example",
             author: %{login: "octocat", name: "Octo Cat"},
             committer: %{login: "mona", name: "Mona"},
             authored_at: "2026-04-29T10:00:00Z",
             committed_at: "2026-04-29T10:05:00Z",
             parents: [%{sha: "def456"}]
           }
         ],
         files: [
           %{
             filename: "lib/example.ex",
             status: "modified",
             additions: 12,
             deletions: 3,
             changes: 15,
             sha: "abc123"
           }
         ]
       }}
    end

    def list_issues("org/repo", "open", "token") do
      {:ok, [%{number: 1, url: "https://github.test/1", title: "First", state: "open"}]}
    end

    def read_file("org/repo", "README.md", "main", "token") do
      {:ok,
       %{
         path: "README.md",
         name: "README.md",
         sha: "abc123",
         size: 12,
         type: "file",
         encoding: "utf-8",
         binary: false,
         content: "# Project\n",
         url: "https://api.github.test/repos/org/repo/contents/README.md",
         html_url: "https://github.test/org/repo/blob/main/README.md",
         download_url: "https://raw.github.test/org/repo/main/README.md"
       }}
    end

    def update_file(
          "org/repo",
          "README.md",
          %{
            content: "# Project\n",
            message: "Update README",
            branch: "main",
            sha: "abc123",
            committer: %{name: "Octo Cat", email: "octo@example.com"}
          },
          "token"
        ) do
      {:ok,
       %{
         sha: "def456",
         url: "https://api.github.test/repos/org/repo/contents/README.md",
         html_url: "https://github.test/org/repo/blob/main/README.md",
         download_url: "https://raw.github.test/org/repo/main/README.md",
         commit_sha: "commit123",
         commit_message: "Update README"
       }}
    end

    def list_pull_requests(
          %{
            repo: "org/repo",
            state: "open",
            head: "octo:feature",
            base: "main",
            sort: "updated",
            direction: "asc",
            page: 2,
            per_page: 10
          },
          "token"
        ) do
      {:ok,
       [
         %{
           number: 4,
           url: "https://github.test/pull/4",
           title: "Feature",
           state: "open",
           head: %{ref: "feature"},
           base: %{ref: "main"}
         }
       ]}
    end

    def list_pull_request_files(
          %{repo: "org/repo", pull_number: 4, page: 2, per_page: 10},
          "token"
        ) do
      {:ok,
       [
         %{
           filename: "lib/example.ex",
           status: "modified",
           additions: 12,
           deletions: 3,
           changes: 15,
           sha: "abc123",
           previous_filename: nil,
           blob_url: "https://github.test/org/repo/blob/abc123/lib/example.ex",
           raw_url: "https://github.test/org/repo/raw/abc123/lib/example.ex",
           contents_url: "https://api.github.test/repos/org/repo/contents/lib/example.ex",
           patch: "@@ -1 +1 @@"
         }
       ]}
    end

    def search_issues(
          %{
            q: "crash repo:org/repo is:pr state:open author:octocat assignee:mona label:bug",
            sort: "updated",
            direction: "desc",
            page: 2,
            per_page: 10
          },
          "token"
        ) do
      {:ok,
       %{
         total_count: 2,
         results: [
           %{
             type: :issue,
             number: 5,
             url: "https://github.test/issues/5",
             title: "Crash",
             state: "open",
             labels: [%{name: "bug"}],
             comments: 3
           },
           %{
             type: :pull_request,
             number: 6,
             url: "https://github.test/pull/6",
             title: "Fix crash",
             state: "open",
             user: %{login: "octocat"},
             updated_at: "2026-04-29T10:00:00Z"
           }
         ]
       }}
    end

    def get_pull_request("org/repo", 4, "token") do
      {:ok,
       %{
         number: 4,
         url: "https://github.test/pull/4",
         title: "Feature",
         state: "open",
         draft: false,
         merged: false,
         mergeable: true,
         mergeable_state: "clean",
         head: %{ref: "feature"},
         base: %{ref: "main"},
         issue: %{
           number: 4,
           title: "Feature",
           state: "open",
           labels: [%{name: "enhancement"}],
           assignees: [%{login: "octocat"}],
           milestone: %{title: "v1"}
         }
       }}
    end

    def dispatch_workflow(
          "org/repo",
          "ci.yml",
          %{ref: "main", inputs: %{"environment" => "staging", "deploy" => true}},
          "token"
        ) do
      {:ok, %{dispatched: true}}
    end

    def list_workflow_runs(
          %{
            repo: "org/repo",
            workflow: "ci.yml",
            branch: "main",
            status: "completed",
            event: "push",
            page: 2,
            per_page: 10
          },
          "token"
        ) do
      {:ok,
       %{
         total_count: 1,
         workflow_runs: [
           %{
             id: 22,
             name: "CI",
             number: 17,
             status: "completed",
             conclusion: "success",
             event: "push",
             branch: "main",
             sha: "abc123",
             workflow_id: 9001,
             url: "https://github.test/runs/22"
           }
         ]
       }}
    end

    def list_workflow_runs(
          %{repo: "org/repo", page: 1, per_page: 30, checkpoint: "2026-04-29T10:00:00Z"},
          "token"
        ) do
      {:ok,
       %{
         total_count: 2,
         workflow_runs: [
           %{
             id: 31,
             name: "CI",
             number: 18,
             status: "in_progress",
             conclusion: nil,
             event: "push",
             branch: "main",
             sha: "def456",
             workflow_id: 9001,
             url: "https://github.test/runs/31",
             created_at: "2026-04-29T10:00:00Z",
             updated_at: "2026-04-29T10:00:00Z"
           },
           %{
             id: 32,
             name: "CI",
             number: 19,
             status: "completed",
             conclusion: "failure",
             event: "push",
             branch: "main",
             sha: "fed654",
             workflow_id: 9001,
             url: "https://github.test/runs/32",
             created_at: "2026-04-29T10:02:00Z",
             updated_at: "2026-04-29T10:03:00Z"
           }
         ]
       }}
    end

    def list_workflow_runs(%{repo: "org/repo", page: 1, per_page: 30}, "token") do
      {:ok,
       %{
         total_count: 1,
         workflow_runs: [
           %{
             id: 31,
             name: "CI",
             number: 18,
             status: "in_progress",
             conclusion: nil,
             event: "push",
             branch: "main",
             sha: "def456",
             workflow_id: 9001,
             url: "https://github.test/runs/31",
             created_at: "2026-04-29T10:00:00Z",
             updated_at: "2026-04-29T10:00:00Z"
           }
         ]
       }}
    end

    def list_releases(%{repo: "org/repo", page: 2, per_page: 10}, "token") do
      {:ok,
       %{
         releases: [
           %{
             id: 101,
             tag_name: "v1.0.0",
             name: "v1.0.0",
             draft: false,
             prerelease: false,
             target_commitish: "main",
             author: %{login: "octocat"},
             url: "https://github.test/org/repo/releases/tag/v1.0.0",
             created_at: "2026-04-29T10:00:00Z",
             published_at: "2026-04-29T10:05:00Z"
           }
         ],
         tags: [
           %{
             name: "v1.0.0",
             sha: "abc123",
             url: "https://api.github.test/repos/org/repo/git/refs/tags/v1.0.0"
           }
         ]
       }}
    end

    def create_release(
          "org/repo",
          %{
            tag_name: "v1.0.0",
            target_commitish: "main",
            name: "v1.0.0",
            body: "Release notes",
            draft: true,
            prerelease: true,
            generate_release_notes: true,
            make_latest: "false"
          },
          "token"
        ) do
      {:ok,
       %{
         id: 102,
         tag_name: "v1.0.0",
         name: "v1.0.0",
         draft: true,
         prerelease: true,
         target_commitish: "main",
         author: %{login: "octocat"},
         url: "https://github.test/org/repo/releases/tag/v1.0.0",
         upload_url:
           "https://uploads.github.test/repos/org/repo/releases/102/assets{?name,label}",
         created_at: "2026-04-29T10:00:00Z",
         body: "Release notes"
       }}
    end

    def upload_release_asset(
          "https://uploads.github.test/repos/org/repo/releases/102/assets{?name,label}",
          %{
            name: "dist.zip",
            label: "Distribution",
            content_type: "application/zip",
            content_base64: "emlwLWJ5dGVz"
          },
          "token"
        ) do
      {:ok,
       %{
         id: 201,
         node_id: "RA_kwDO",
         name: "dist.zip",
         label: "Distribution",
         state: "uploaded",
         content_type: "application/zip",
         size: 9,
         download_count: 0,
         url: "https://api.github.test/repos/org/repo/releases/assets/201",
         browser_download_url: "https://github.test/org/repo/releases/download/v1.0.0/dist.zip",
         created_at: "2026-04-29T10:10:00Z",
         updated_at: "2026-04-29T10:10:00Z",
         uploader: %{login: "octocat"}
       }}
    end

    def list_workflow_run_jobs(
          %{repo: "org/repo", run_id: 22, filter: "latest", page: 2, per_page: 10},
          "token"
        ) do
      {:ok,
       %{
         total_count: 1,
         ci_status: "failure",
         jobs: [
           %{
             id: 33,
             run_id: 22,
             run_attempt: 1,
             name: "test",
             status: "completed",
             conclusion: "failure",
             ci_status: "failure",
             steps: [
               %{
                 number: 1,
                 name: "checkout",
                 status: "completed",
                 conclusion: "success",
                 ci_status: "success"
               },
               %{
                 number: 2,
                 name: "mix test",
                 status: "completed",
                 conclusion: "failure",
                 ci_status: "failure"
               }
             ],
             url: "https://github.test/runs/22/job/33"
           }
         ]
       }}
    end

    def rerun_workflow_run("org/repo", 22, %{failed_only: true}, "token") do
      {:ok, %{rerun_requested: true}}
    end

    def cancel_workflow_run("org/repo", 22, "token") do
      {:ok, %{cancel_requested: true}}
    end

    def create_issue("org/repo", %{title: "Bug", body: nil, labels: []}, "token") do
      {:ok, %{number: 2, url: "https://github.test/2", title: "Bug", state: "open"}}
    end

    def add_issue_labels("org/repo", 2, ["bug", "triage"], "token") do
      {:ok,
       [
         %{name: "bug", color: "d73a4a", description: "Something is not working"},
         %{name: "triage", color: "ededed"}
       ]}
    end

    def remove_issue_label("org/repo", 2, "bug", "token") do
      {:ok, [%{name: "triage", color: "ededed"}]}
    end

    def assign_issue("org/repo", 2, ["octocat", "mona"], "token") do
      {:ok,
       %{
         number: 2,
         url: "https://github.test/2",
         title: "Bug",
         state: "open",
         assignees: [
           %{login: "octocat", id: 1, type: "User"},
           %{login: "mona", id: 2, type: "User"}
         ]
       }}
    end

    def create_pull_request(
          "org/repo",
          %{
            title: "Feature",
            body: "Implements the feature",
            head: "octo:feature",
            base: "main",
            draft: true,
            maintainer_can_modify: false
          },
          "token"
        ) do
      {:ok,
       %{
         number: 5,
         url: "https://github.test/pull/5",
         title: "Feature",
         state: "open",
         draft: true,
         maintainer_can_modify: false,
         head: %{ref: "feature"},
         base: %{ref: "main"}
       }}
    end

    def update_pull_request(
          "org/repo",
          5,
          %{
            title: "Updated feature",
            body: "Updated body",
            base: "release",
            state: "open",
            maintainer_can_modify: true,
            draft: false
          },
          "token"
        ) do
      {:ok,
       %{
         number: 5,
         url: "https://github.test/pull/5",
         title: "Updated feature",
         state: "open",
         draft: false,
         maintainer_can_modify: true,
         head: %{ref: "feature"},
         base: %{ref: "release"}
       }}
    end

    def request_pull_request_reviewers(
          "org/repo",
          5,
          %{reviewers: ["octocat"], team_reviewers: ["core"]},
          "token"
        ) do
      {:ok,
       %{
         number: 5,
         url: "https://github.test/pull/5",
         title: "Feature",
         state: "open",
         requested_reviewers: [%{login: "octocat", id: 1, type: "User"}],
         requested_teams: [%{slug: "core", name: "Core", id: 2}]
       }}
    end

    def create_pull_request_review_comment(
          "org/repo",
          5,
          %{
            body: "Consider extracting this helper",
            commit_id: "abc123",
            path: "lib/example.ex",
            line: 12,
            side: "RIGHT"
          },
          "token"
        ) do
      {:ok,
       %{
         id: 44,
         url: "https://github.test/pull/5#discussion-diff-44",
         body: "Consider extracting this helper",
         path: "lib/example.ex",
         line: 12,
         side: "RIGHT"
       }}
    end

    def create_pull_request_review_comment(
          "org/repo",
          5,
          %{
            body: "Consider extracting this helper",
            commit_id: "abc123",
            path: "lib/example.ex",
            position: 3
          },
          "token"
        ) do
      {:ok,
       %{
         id: 45,
         url: "https://github.test/pull/5#discussion-diff-45",
         body: "Consider extracting this helper",
         path: "lib/example.ex",
         position: 3
       }}
    end

    def merge_pull_request(
          "org/repo",
          5,
          %{
            merge_method: "squash",
            commit_title: "Merge feature",
            commit_message: "Ship the feature",
            sha: "abc123"
          },
          "token"
        ) do
      {:ok,
       %{
         sha: "def456",
         merged: true,
         message: "Pull Request successfully merged"
       }}
    end

    def update_issue("org/repo", 2, %{title: "Bug", labels: ["bug"], type: "Bug"}, "token") do
      {:ok, %{number: 2, url: "https://github.test/2", title: "Bug", state: "open"}}
    end

    def create_issue_comment("org/repo", 2, "Ship it", "token") do
      {:ok, %{id: 3, url: "https://github.test/comments/3", body: "Ship it"}}
    end

    def list_issue_comments(
          %{
            repo: "org/repo",
            issue_number: 2,
            since: "2026-04-29T10:00:00Z",
            page: 2,
            per_page: 10
          },
          "token"
        ) do
      {:ok,
       [
         %{
           id: 3,
           url: "https://github.test/comments/3",
           body: "Ship it",
           user: %{login: "octocat"},
           author_association: "MEMBER",
           created_at: "2026-04-29T10:01:00Z",
           updated_at: "2026-04-29T10:02:00Z"
         }
       ]}
    end

    def list_new_issues("org/repo", nil, "token") do
      {:ok,
       [
         %{
           number: 3,
           url: "https://github.test/3",
           title: "Third",
           updated_at: "2026-04-24T20:00:00Z"
         }
       ]}
    end

    def list_updated_pull_requests("org/repo", nil, "token") do
      {:ok,
       [
         %{
           number: 7,
           url: "https://github.test/pulls/7",
           title: "Seventh",
           state: "open",
           updated_at: "2026-04-29T10:00:00Z"
         }
       ]}
    end

    def list_updated_pull_requests("org/repo", "2026-04-29T10:00:00Z", "token") do
      {:ok,
       [
         %{
           number: 7,
           url: "https://github.test/pulls/7",
           title: "Seventh duplicate",
           state: "open",
           updated_at: "2026-04-29T10:00:00Z"
         },
         %{
           number: 8,
           url: "https://github.test/pulls/8",
           title: "Eighth",
           state: "open",
           updated_at: "2026-04-29T10:02:00Z"
         }
       ]}
    end
  end

  test "GitHub integration declares first actions and poll trigger" do
    spec = Jido.Connect.GitHub.integration()

    assert spec.id == :github
    assert spec.package == :jido_connect_github
    assert spec.status == :available
    assert :issues in spec.tags
    assert [%{id: :repo_access, decision: :allow_operation}] = spec.policies
    assert {:user, :oauth2} in Enum.map(spec.auth_profiles, &{&1.id, &1.kind})
    assert {:installation, :app_installation} in Enum.map(spec.auth_profiles, &{&1.id, &1.kind})

    assert Enum.find(spec.auth_profiles, &(&1.id == :installation)).setup ==
             :github_app_installation

    assert {:ok,
            %{
              id: "github.repo.list",
              resource: :repository,
              verb: :list,
              mutation?: false,
              auth_profiles: [:user, :installation],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.repo.list")

    assert {:ok,
            %{
              id: "github.installation_repository.list",
              resource: :repository,
              verb: :list,
              mutation?: false,
              auth_profiles: [:installation],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.installation_repository.list")

    assert {:ok,
            %{
              id: "github.repo.get",
              resource: :repository,
              verb: :get,
              mutation?: false,
              auth_profiles: [:user, :installation],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.repo.get")

    assert {:ok,
            %{
              id: "github.branch.list",
              resource: :branch,
              verb: :list,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.branch.list")

    assert {:ok,
            %{
              id: "github.branch.create",
              resource: :branch,
              verb: :create,
              mutation?: true,
              confirmation: :always,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.branch.create")

    assert {:ok,
            %{
              id: "github.ref.compare",
              resource: :ref,
              verb: :get,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.ref.compare")

    assert {:ok,
            %{
              id: "github.file.read",
              resource: :file,
              verb: :read,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.file.read")

    assert {:ok,
            %{
              id: "github.file.update",
              resource: :file,
              verb: :update,
              mutation?: true,
              confirmation: :always,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.file.update")

    assert {:ok,
            %{
              id: "github.issue.list",
              resource: :issue,
              verb: :list,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.issue.list")

    assert {:ok, %{id: "github.issue.create", mutation?: true, confirmation: :required_for_ai}} =
             Connect.action(spec, "github.issue.create")

    assert {:ok,
            %{
              id: "github.issue.label.add",
              resource: :issue,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.issue.label.add")

    assert {:ok,
            %{
              id: "github.issue.label.remove",
              resource: :issue,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.issue.label.remove")

    assert {:ok,
            %{
              id: "github.issue.assign",
              resource: :issue,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.issue.assign")

    assert {:ok,
            %{
              id: "github.pull_request.list",
              resource: :pull_request,
              verb: :list,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.pull_request.list")

    assert {:ok,
            %{
              id: "github.pull_request_file.list",
              resource: :pull_request_file,
              verb: :list,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.pull_request_file.list")

    assert {:ok,
            %{
              id: "github.issue.search",
              resource: :issue,
              verb: :search,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.issue.search")

    assert {:ok,
            %{
              id: "github.workflow_run.list",
              resource: :workflow_run,
              verb: :list,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.workflow_run.list")

    assert {:ok,
            %{
              id: "github.release.list",
              resource: :release,
              verb: :list,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.release.list")

    assert {:ok,
            %{
              id: "github.release.create",
              resource: :release,
              verb: :create,
              mutation?: true,
              confirmation: :always,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.release.create")

    assert {:ok,
            %{
              id: "github.release_asset.upload",
              resource: :release_asset,
              verb: :upload,
              mutation?: true,
              confirmation: :always,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.release_asset.upload")

    assert {:ok,
            %{
              id: "github.workflow_run.job.list",
              resource: :workflow_run_job,
              verb: :list,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.workflow_run.job.list")

    assert {:ok,
            %{
              id: "github.workflow_run.rerun",
              resource: :workflow_run,
              verb: :dispatch,
              mutation?: true,
              confirmation: :always,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.workflow_run.rerun")

    assert {:ok,
            %{
              id: "github.workflow_run.cancel",
              resource: :workflow_run,
              verb: :cancel,
              mutation?: true,
              confirmation: :always,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.workflow_run.cancel")

    assert {:ok,
            %{
              id: "github.workflow.dispatch",
              resource: :workflow,
              verb: :dispatch,
              mutation?: true,
              confirmation: :always,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.workflow.dispatch")

    assert {:ok,
            %{
              id: "github.pull_request.get",
              resource: :pull_request,
              verb: :get,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.pull_request.get")

    assert {:ok,
            %{
              id: "github.pull_request.create",
              resource: :pull_request,
              verb: :create,
              mutation?: true,
              confirmation: :required_for_ai,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.pull_request.create")

    assert {:ok,
            %{
              id: "github.pull_request.update",
              resource: :pull_request,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.pull_request.update")

    assert {:ok,
            %{
              id: "github.pull_request.reviewers.request",
              resource: :pull_request,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.pull_request.reviewers.request")

    assert {:ok,
            %{
              id: "github.pull_request.review_comment.create",
              resource: :pull_request_review_comment,
              verb: :create,
              mutation?: true,
              confirmation: :required_for_ai,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.pull_request.review_comment.create")

    assert {:ok,
            %{
              id: "github.pull_request.merge",
              resource: :pull_request,
              verb: :merge,
              mutation?: true,
              confirmation: :always,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.pull_request.merge")

    assert {:ok,
            %{
              id: "github.issue.update",
              resource: :issue,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.issue.update")

    assert {:ok,
            %{
              id: "github.issue_comment.create",
              resource: :comment,
              verb: :create,
              mutation?: true,
              confirmation: :required_for_ai,
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.issue_comment.create")

    assert {:ok,
            %{
              id: "github.issue_comment.list",
              resource: :comment,
              verb: :list,
              mutation?: false,
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.issue_comment.list")

    assert {:ok,
            %{
              id: "github.issue.new",
              kind: :poll,
              checkpoint: :updated_at,
              auth_profiles: [:user, :installation],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.trigger(spec, "github.issue.new")

    assert {:ok,
            %{
              id: "github.pull_request.updated",
              kind: :poll,
              checkpoint: :updated_at,
              dedupe: %{key: [:repo, :pull_number, :updated_at]},
              auth_profiles: [:user, :installation],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.trigger(spec, "github.pull_request.updated")

    assert {:ok,
            %{
              id: "github.workflow_run.updated",
              kind: :poll,
              checkpoint: :updated_at,
              dedupe: %{key: [:repo, :workflow_run_id, :updated_at]},
              auth_profiles: [:user, :installation],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.trigger(spec, "github.workflow_run.updated")
  end

  test "GitHub catalog entry exposes setup, auth, and runtime capabilities" do
    entry = Connect.Catalog.entry(Jido.Connect.GitHub)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_github
    assert entry.tags == [:source_control, :issues, :developer_tools]
    assert [%{id: :repo_access}] = entry.policies
    assert MapSet.subset?(MapSet.new([:oauth2, :app_installation]), features)
    assert MapSet.member?(features, :generated_jido_actions)
    assert MapSet.member?(features, :polling)
    assert MapSet.member?(features, :github_app_manifest)
    assert MapSet.member?(features, :webhook_verification)
  end

  test "GitHub integration compiles Jido action, sensor, and plugin modules" do
    assert Application.get_env(:jido_connect_github, :jido_connect_providers) == [
             Jido.Connect.GitHub
           ]

    assert Jido.Connect.GitHub.jido_action_modules() == [
             Jido.Connect.GitHub.Actions.ListRepositories,
             Jido.Connect.GitHub.Actions.SearchRepositories,
             Jido.Connect.GitHub.Actions.ListInstallationRepositories,
             Jido.Connect.GitHub.Actions.GetRepository,
             Jido.Connect.GitHub.Actions.ListBranches,
             Jido.Connect.GitHub.Actions.CreateBranch,
             Jido.Connect.GitHub.Actions.ListCommits,
             Jido.Connect.GitHub.Actions.CompareRefs,
             Jido.Connect.GitHub.Actions.ReadFile,
             Jido.Connect.GitHub.Actions.UpdateFile,
             Jido.Connect.GitHub.Actions.ListIssues,
             Jido.Connect.GitHub.Actions.CreateIssue,
             Jido.Connect.GitHub.Actions.AddIssueLabels,
             Jido.Connect.GitHub.Actions.RemoveIssueLabel,
             Jido.Connect.GitHub.Actions.AssignIssue,
             Jido.Connect.GitHub.Actions.ListPullRequests,
             Jido.Connect.GitHub.Actions.SearchIssues,
             Jido.Connect.GitHub.Actions.ListWorkflowRuns,
             Jido.Connect.GitHub.Actions.ListReleases,
             Jido.Connect.GitHub.Actions.CreateRelease,
             Jido.Connect.GitHub.Actions.UploadReleaseAsset,
             Jido.Connect.GitHub.Actions.ListWorkflowRunJobs,
             Jido.Connect.GitHub.Actions.RerunWorkflowRun,
             Jido.Connect.GitHub.Actions.CancelWorkflowRun,
             Jido.Connect.GitHub.Actions.DispatchWorkflow,
             Jido.Connect.GitHub.Actions.GetPullRequest,
             Jido.Connect.GitHub.Actions.ListPullRequestFiles,
             Jido.Connect.GitHub.Actions.CreatePullRequest,
             Jido.Connect.GitHub.Actions.UpdatePullRequest,
             Jido.Connect.GitHub.Actions.RequestPullRequestReviewers,
             Jido.Connect.GitHub.Actions.CreatePullRequestReviewComment,
             Jido.Connect.GitHub.Actions.MergePullRequest,
             Jido.Connect.GitHub.Actions.UpdateIssue,
             Jido.Connect.GitHub.Actions.CreateIssueComment,
             Jido.Connect.GitHub.Actions.ListIssueComments
           ]

    assert Jido.Connect.GitHub.jido_sensor_modules() == [
             Jido.Connect.GitHub.Sensors.NewIssues,
             Jido.Connect.GitHub.Sensors.UpdatedPullRequests,
             Jido.Connect.GitHub.Sensors.WorkflowRunUpdates
           ]

    assert Jido.Connect.GitHub.jido_plugin_module() == Jido.Connect.GitHub.Plugin

    assert %Connect.Catalog.Manifest{
             id: :github,
             package: :jido_connect_github,
             generated_modules: %{
               actions: [
                 Jido.Connect.GitHub.Actions.ListRepositories,
                 Jido.Connect.GitHub.Actions.SearchRepositories,
                 Jido.Connect.GitHub.Actions.ListInstallationRepositories,
                 Jido.Connect.GitHub.Actions.GetRepository,
                 Jido.Connect.GitHub.Actions.ListBranches,
                 Jido.Connect.GitHub.Actions.CreateBranch,
                 Jido.Connect.GitHub.Actions.ListCommits,
                 Jido.Connect.GitHub.Actions.CompareRefs,
                 Jido.Connect.GitHub.Actions.ReadFile,
                 Jido.Connect.GitHub.Actions.UpdateFile,
                 Jido.Connect.GitHub.Actions.ListIssues,
                 Jido.Connect.GitHub.Actions.CreateIssue,
                 Jido.Connect.GitHub.Actions.AddIssueLabels,
                 Jido.Connect.GitHub.Actions.RemoveIssueLabel,
                 Jido.Connect.GitHub.Actions.AssignIssue,
                 Jido.Connect.GitHub.Actions.ListPullRequests,
                 Jido.Connect.GitHub.Actions.SearchIssues,
                 Jido.Connect.GitHub.Actions.ListWorkflowRuns,
                 Jido.Connect.GitHub.Actions.ListReleases,
                 Jido.Connect.GitHub.Actions.CreateRelease,
                 Jido.Connect.GitHub.Actions.UploadReleaseAsset,
                 Jido.Connect.GitHub.Actions.ListWorkflowRunJobs,
                 Jido.Connect.GitHub.Actions.RerunWorkflowRun,
                 Jido.Connect.GitHub.Actions.CancelWorkflowRun,
                 Jido.Connect.GitHub.Actions.DispatchWorkflow,
                 Jido.Connect.GitHub.Actions.GetPullRequest,
                 Jido.Connect.GitHub.Actions.ListPullRequestFiles,
                 Jido.Connect.GitHub.Actions.CreatePullRequest,
                 Jido.Connect.GitHub.Actions.UpdatePullRequest,
                 Jido.Connect.GitHub.Actions.RequestPullRequestReviewers,
                 Jido.Connect.GitHub.Actions.CreatePullRequestReviewComment,
                 Jido.Connect.GitHub.Actions.MergePullRequest,
                 Jido.Connect.GitHub.Actions.UpdateIssue,
                 Jido.Connect.GitHub.Actions.CreateIssueComment,
                 Jido.Connect.GitHub.Actions.ListIssueComments
               ],
               sensors: [
                 Jido.Connect.GitHub.Sensors.NewIssues,
                 Jido.Connect.GitHub.Sensors.UpdatedPullRequests,
                 Jido.Connect.GitHub.Sensors.WorkflowRunUpdates
               ],
               plugin: Jido.Connect.GitHub.Plugin
             }
           } = Jido.Connect.GitHub.jido_connect_manifest()

    assert {:module, Jido.Connect.GitHub.Actions.ListIssues} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListIssues)

    assert {:module, Jido.Connect.GitHub.Actions.ListRepositories} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListRepositories)

    assert {:module, Jido.Connect.GitHub.Actions.SearchRepositories} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.SearchRepositories)

    assert {:module, Jido.Connect.GitHub.Actions.ListInstallationRepositories} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListInstallationRepositories)

    assert {:module, Jido.Connect.GitHub.Actions.GetRepository} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.GetRepository)

    assert {:module, Jido.Connect.GitHub.Actions.ListBranches} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListBranches)

    assert {:module, Jido.Connect.GitHub.Actions.ListCommits} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListCommits)

    assert {:module, Jido.Connect.GitHub.Actions.CompareRefs} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.CompareRefs)

    assert {:module, Jido.Connect.GitHub.Actions.ReadFile} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ReadFile)

    assert {:module, Jido.Connect.GitHub.Actions.UpdateFile} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.UpdateFile)

    assert {:module, Jido.Connect.GitHub.Actions.AddIssueLabels} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.AddIssueLabels)

    assert {:module, Jido.Connect.GitHub.Actions.RemoveIssueLabel} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.RemoveIssueLabel)

    assert {:module, Jido.Connect.GitHub.Actions.AssignIssue} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.AssignIssue)

    assert {:module, Jido.Connect.GitHub.Actions.CreateIssueComment} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.CreateIssueComment)

    assert {:module, Jido.Connect.GitHub.Actions.ListIssueComments} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListIssueComments)

    assert {:module, Jido.Connect.GitHub.Actions.ListPullRequests} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListPullRequests)

    assert {:module, Jido.Connect.GitHub.Actions.SearchIssues} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.SearchIssues)

    assert {:module, Jido.Connect.GitHub.Actions.ListWorkflowRuns} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListWorkflowRuns)

    assert {:module, Jido.Connect.GitHub.Actions.ListReleases} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListReleases)

    assert {:module, Jido.Connect.GitHub.Actions.CreateRelease} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.CreateRelease)

    assert {:module, Jido.Connect.GitHub.Actions.ListWorkflowRunJobs} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListWorkflowRunJobs)

    assert {:module, Jido.Connect.GitHub.Actions.DispatchWorkflow} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.DispatchWorkflow)

    assert {:module, Jido.Connect.GitHub.Actions.GetPullRequest} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.GetPullRequest)

    assert {:module, Jido.Connect.GitHub.Actions.ListPullRequestFiles} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListPullRequestFiles)

    assert {:module, Jido.Connect.GitHub.Actions.CreatePullRequest} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.CreatePullRequest)

    assert {:module, Jido.Connect.GitHub.Actions.UpdatePullRequest} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.UpdatePullRequest)

    assert {:module, Jido.Connect.GitHub.Actions.RequestPullRequestReviewers} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.RequestPullRequestReviewers)

    assert {:module, Jido.Connect.GitHub.Actions.CreatePullRequestReviewComment} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.CreatePullRequestReviewComment)

    assert {:module, Jido.Connect.GitHub.Actions.MergePullRequest} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.MergePullRequest)

    assert {:module, Jido.Connect.GitHub.Actions.UpdateIssue} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.UpdateIssue)

    assert {:module, Jido.Connect.GitHub.Sensors.NewIssues} =
             Code.ensure_loaded(Jido.Connect.GitHub.Sensors.NewIssues)

    assert {:module, Jido.Connect.GitHub.Sensors.UpdatedPullRequests} =
             Code.ensure_loaded(Jido.Connect.GitHub.Sensors.UpdatedPullRequests)

    assert {:module, Jido.Connect.GitHub.Sensors.WorkflowRunUpdates} =
             Code.ensure_loaded(Jido.Connect.GitHub.Sensors.WorkflowRunUpdates)

    assert {:module, Jido.Connect.GitHub.Plugin} =
             Code.ensure_loaded(Jido.Connect.GitHub.Plugin)

    assert function_exported?(Jido.Connect.GitHub.Actions.ListIssues, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListRepositories, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.SearchRepositories, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListInstallationRepositories, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.GetRepository, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListBranches, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListCommits, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.CompareRefs, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ReadFile, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.UpdateFile, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.AddIssueLabels, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.RemoveIssueLabel, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.AssignIssue, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListPullRequests, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.SearchIssues, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListWorkflowRuns, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListReleases, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.CreateRelease, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListWorkflowRunJobs, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.DispatchWorkflow, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.GetPullRequest, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListPullRequestFiles, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.CreatePullRequest, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.UpdatePullRequest, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.RequestPullRequestReviewers, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.CreatePullRequestReviewComment, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.MergePullRequest, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.UpdateIssue, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.CreateIssueComment, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListIssueComments, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Sensors.NewIssues, :init, 2)
    assert function_exported?(Jido.Connect.GitHub.Sensors.UpdatedPullRequests, :init, 2)
    assert function_exported?(Jido.Connect.GitHub.Sensors.WorkflowRunUpdates, :init, 2)
    assert function_exported?(Jido.Connect.GitHub.Plugin, :plugin_spec, 1)
  end

  test "generated action metadata tracks the DSL action" do
    projection = Jido.Connect.GitHub.Actions.CreateIssue.jido_connect_projection()

    assert projection.action_id == "github.issue.create"
    assert projection.label == "Create issue"
    assert Enum.map(projection.input, & &1.name) == [:repo, :title, :body, :labels]
    assert Enum.map(projection.output, & &1.name) == [:number, :url, :title, :state]
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :issue
    assert projection.verb == :create
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.CreateIssue.name() == "github_issue_create"

    assert Jido.Connect.GitHub.Actions.CreateIssue.description() ==
             "Create a GitHub issue."
  end

  test "generated add issue labels action metadata tracks required label fields" do
    projection = Jido.Connect.GitHub.Actions.AddIssueLabels.jido_connect_projection()

    assert projection.action_id == "github.issue.label.add"
    assert projection.label == "Add labels to issue"
    assert Enum.map(projection.input, & &1.name) == [:repo, :issue_number, :labels]
    assert Enum.map(projection.output, & &1.name) == [:labels]
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :issue
    assert projection.verb == :update
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.AddIssueLabels.name() == "github_issue_label_add"
  end

  test "generated remove issue label action metadata tracks required label fields" do
    projection = Jido.Connect.GitHub.Actions.RemoveIssueLabel.jido_connect_projection()

    assert projection.action_id == "github.issue.label.remove"
    assert projection.label == "Remove label from issue"
    assert Enum.map(projection.input, & &1.name) == [:repo, :issue_number, :label]
    assert Enum.map(projection.output, & &1.name) == [:labels]
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :issue
    assert projection.verb == :update
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.RemoveIssueLabel.name() == "github_issue_label_remove"
  end

  test "generated assign issue action metadata tracks required assignee fields" do
    projection = Jido.Connect.GitHub.Actions.AssignIssue.jido_connect_projection()

    assert projection.action_id == "github.issue.assign"
    assert projection.label == "Assign issue"
    assert Enum.map(projection.input, & &1.name) == [:repo, :issue_number, :assignees]
    assert Enum.map(projection.output, & &1.name) == [:number, :url, :title, :state, :assignees]
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :issue
    assert projection.verb == :update
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.AssignIssue.name() == "github_issue_assign"
  end

  test "generated issue comment action metadata tracks high-risk DSL fields" do
    projection = Jido.Connect.GitHub.Actions.CreateIssueComment.jido_connect_projection()

    assert projection.action_id == "github.issue_comment.create"
    assert projection.label == "Create issue comment"
    assert Enum.map(projection.input, & &1.name) == [:repo, :issue_number, :body]
    assert Enum.map(projection.output, & &1.name) == [:id, :url, :body]
    assert projection.data_classification == :message_content
    assert projection.risk == :external_write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :comment
    assert projection.verb == :create
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.CreateIssueComment.name() == "github_issue_comment_create"
  end

  test "generated issue comment list action metadata tracks pagination fields" do
    projection = Jido.Connect.GitHub.Actions.ListIssueComments.jido_connect_projection()

    assert projection.action_id == "github.issue_comment.list"
    assert projection.label == "List issue comments"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :issue_number,
             :since,
             :page,
             :per_page
           ]

    assert Enum.map(projection.output, & &1.name) == [:comments]
    assert projection.data_classification == :message_content
    assert projection.risk == :read
    assert projection.resource == :comment
    assert projection.verb == :list
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.ListIssueComments.name() == "github_issue_comment_list"
  end

  test "generated update issue action metadata tracks editable fields" do
    projection = Jido.Connect.GitHub.Actions.UpdateIssue.jido_connect_projection()

    assert projection.action_id == "github.issue.update"
    assert projection.label == "Update issue"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :issue_number,
             :title,
             :body,
             :state,
             :labels,
             :milestone,
             :assignees,
             :type
           ]

    assert Enum.map(projection.output, & &1.name) == [:number, :url, :title, :state]
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :issue
    assert projection.verb == :update
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.UpdateIssue.name() == "github_issue_update"
  end

  test "generated pull request list action metadata tracks filter fields" do
    projection = Jido.Connect.GitHub.Actions.ListPullRequests.jido_connect_projection()

    assert projection.action_id == "github.pull_request.list"
    assert projection.label == "List pull requests"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :state,
             :head,
             :base,
             :sort,
             :direction,
             :page,
             :per_page
           ]

    assert Enum.map(projection.output, & &1.name) == [:pull_requests]
    assert projection.risk == :read
    assert projection.resource == :pull_request
    assert projection.verb == :list
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.ListPullRequests.name() == "github_pull_request_list"
  end

  test "generated branch list action metadata tracks pagination fields" do
    projection = Jido.Connect.GitHub.Actions.ListBranches.jido_connect_projection()

    assert projection.action_id == "github.branch.list"
    assert projection.label == "List branches"
    assert Enum.map(projection.input, & &1.name) == [:repo, :page, :per_page]
    assert Enum.map(projection.output, & &1.name) == [:branches]
    assert projection.risk == :read
    assert projection.resource == :branch
    assert projection.verb == :list
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.ListBranches.name() == "github_branch_list"
  end

  test "generated branch create action metadata tracks source fields" do
    projection = Jido.Connect.GitHub.Actions.CreateBranch.jido_connect_projection()

    assert projection.action_id == "github.branch.create"
    assert projection.label == "Create branch"
    assert Enum.map(projection.input, & &1.name) == [:repo, :branch, :source_ref, :source_sha]
    assert Enum.map(projection.output, & &1.name) == [:repo, :branch, :ref, :sha, :url, :object]
    assert projection.risk == :write
    assert projection.confirmation == :always
    assert projection.resource == :branch
    assert projection.verb == :create
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.CreateBranch.name() == "github_branch_create"
  end

  test "generated commit list action metadata tracks ref, path, and pagination fields" do
    projection = Jido.Connect.GitHub.Actions.ListCommits.jido_connect_projection()

    assert projection.action_id == "github.commit.list"
    assert projection.label == "List commits"
    assert Enum.map(projection.input, & &1.name) == [:repo, :ref, :path, :page, :per_page]
    assert Enum.map(projection.output, & &1.name) == [:commits]
    assert projection.risk == :read
    assert projection.resource == :commit
    assert projection.verb == :list
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.ListCommits.name() == "github_commit_list"
  end

  test "generated compare refs action metadata tracks refs and stable output fields" do
    projection = Jido.Connect.GitHub.Actions.CompareRefs.jido_connect_projection()

    assert projection.action_id == "github.ref.compare"
    assert projection.label == "Compare refs"
    assert Enum.map(projection.input, & &1.name) == [:repo, :base, :head, :page, :per_page]

    assert Enum.map(projection.output, & &1.name) == [
             :status,
             :ahead_by,
             :behind_by,
             :total_commits,
             :commits,
             :files
           ]

    assert projection.risk == :read
    assert projection.resource == :ref
    assert projection.verb == :get
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.CompareRefs.name() == "github_ref_compare"
  end

  test "generated file read action metadata tracks path, ref, and content metadata fields" do
    projection = Jido.Connect.GitHub.Actions.ReadFile.jido_connect_projection()

    assert projection.action_id == "github.file.read"
    assert projection.label == "Read file contents"
    assert Enum.map(projection.input, & &1.name) == [:repo, :path, :ref]

    assert Enum.map(projection.output, & &1.name) == [
             :repo,
             :path,
             :name,
             :sha,
             :size,
             :type,
             :encoding,
             :binary,
             :content,
             :content_base64,
             :url,
             :html_url,
             :download_url
           ]

    assert projection.risk == :read
    assert projection.resource == :file
    assert projection.verb == :read
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.ReadFile.name() == "github_file_read"
  end

  test "generated file update action metadata tracks branch, message, sha, and committer fields" do
    projection = Jido.Connect.GitHub.Actions.UpdateFile.jido_connect_projection()

    assert projection.action_id == "github.file.update"
    assert projection.label == "Create or update file contents"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :path,
             :content,
             :message,
             :branch,
             :sha,
             :committer
           ]

    assert Enum.map(projection.output, & &1.name) == [
             :repo,
             :path,
             :sha,
             :url,
             :html_url,
             :download_url,
             :commit_sha,
             :commit_message
           ]

    assert projection.risk == :write
    assert projection.confirmation == :always
    assert projection.resource == :file
    assert projection.verb == :update
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.UpdateFile.name() == "github_file_update"
  end

  test "generated repository search action metadata tracks query helpers and pagination fields" do
    projection = Jido.Connect.GitHub.Actions.SearchRepositories.jido_connect_projection()

    assert projection.action_id == "github.repo.search"
    assert projection.label == "Search repositories"

    assert Enum.map(projection.input, & &1.name) == [
             :query,
             :user,
             :org,
             :language,
             :topic,
             :visibility,
             :archived,
             :fork,
             :sort,
             :direction,
             :page,
             :per_page
           ]

    assert Enum.map(projection.output, & &1.name) == [:repositories, :total_count]
    assert projection.risk == :read
    assert projection.resource == :repository
    assert projection.verb == :search
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.SearchRepositories.name() == "github_repo_search"
  end

  test "generated issue search action metadata tracks query helper and pagination fields" do
    projection = Jido.Connect.GitHub.Actions.SearchIssues.jido_connect_projection()

    assert projection.action_id == "github.issue.search"
    assert projection.label == "Search issues and pull requests"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :query,
             :type,
             :state,
             :author,
             :assignee,
             :label,
             :sort,
             :direction,
             :page,
             :per_page
           ]

    assert Enum.map(projection.output, & &1.name) == [:results, :total_count]
    assert projection.risk == :read
    assert projection.resource == :issue
    assert projection.verb == :search
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.SearchIssues.name() == "github_issue_search"
  end

  test "generated workflow run list action metadata tracks filter fields" do
    projection = Jido.Connect.GitHub.Actions.ListWorkflowRuns.jido_connect_projection()

    assert projection.action_id == "github.workflow_run.list"
    assert projection.label == "List workflow runs"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :workflow,
             :branch,
             :status,
             :event,
             :page,
             :per_page
           ]

    assert Enum.map(projection.output, & &1.name) == [:workflow_runs, :total_count]
    assert projection.risk == :read
    assert projection.resource == :workflow_run
    assert projection.verb == :list
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.ListWorkflowRuns.name() == "github_workflow_run_list"
  end

  test "generated workflow run job list action metadata tracks run and pagination fields" do
    projection = Jido.Connect.GitHub.Actions.ListWorkflowRunJobs.jido_connect_projection()

    assert projection.action_id == "github.workflow_run.job.list"
    assert projection.label == "List workflow run jobs"
    assert Enum.map(projection.input, & &1.name) == [:repo, :run_id, :filter, :page, :per_page]
    assert Enum.map(projection.output, & &1.name) == [:jobs, :total_count, :ci_status]
    assert projection.risk == :read
    assert projection.resource == :workflow_run_job
    assert projection.verb == :list
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver

    assert Jido.Connect.GitHub.Actions.ListWorkflowRunJobs.name() ==
             "github_workflow_run_job_list"
  end

  test "generated release list action metadata tracks pagination fields" do
    projection = Jido.Connect.GitHub.Actions.ListReleases.jido_connect_projection()

    assert projection.action_id == "github.release.list"
    assert projection.label == "List releases"
    assert Enum.map(projection.input, & &1.name) == [:repo, :page, :per_page]
    assert Enum.map(projection.output, & &1.name) == [:releases, :tags]
    assert projection.risk == :read
    assert projection.resource == :release
    assert projection.verb == :list
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.ListReleases.name() == "github_release_list"
  end

  test "generated release create action metadata tracks publication settings" do
    projection = Jido.Connect.GitHub.Actions.CreateRelease.jido_connect_projection()

    assert projection.action_id == "github.release.create"
    assert projection.label == "Create release"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :tag_name,
             :target_commitish,
             :name,
             :body,
             :draft,
             :prerelease,
             :generate_release_notes,
             :make_latest
           ]

    assert Enum.map(projection.output, & &1.name) == [
             :id,
             :tag_name,
             :name,
             :draft,
             :prerelease,
             :target_commitish,
             :author,
             :url,
             :upload_url,
             :tarball_url,
             :zipball_url,
             :created_at,
             :published_at,
             :body
           ]

    assert projection.risk == :write
    assert projection.confirmation == :always
    assert projection.resource == :release
    assert projection.verb == :create
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.CreateRelease.name() == "github_release_create"
  end

  test "generated release asset upload action metadata tracks safe content fields" do
    projection = Jido.Connect.GitHub.Actions.UploadReleaseAsset.jido_connect_projection()

    assert projection.action_id == "github.release_asset.upload"
    assert projection.label == "Upload release asset"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :upload_url,
             :name,
             :label,
             :content_type,
             :content_base64
           ]

    assert Enum.map(projection.output, & &1.name) == [
             :id,
             :node_id,
             :name,
             :label,
             :state,
             :content_type,
             :size,
             :download_count,
             :url,
             :browser_download_url,
             :created_at,
             :updated_at,
             :uploader
           ]

    assert projection.risk == :write
    assert projection.confirmation == :always
    assert projection.resource == :release_asset
    assert projection.verb == :upload
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.UploadReleaseAsset.name() == "github_release_asset_upload"
  end

  test "generated workflow run rerun action metadata tracks confirmation" do
    projection = Jido.Connect.GitHub.Actions.RerunWorkflowRun.jido_connect_projection()

    assert projection.action_id == "github.workflow_run.rerun"
    assert projection.label == "Rerun workflow run"
    assert Enum.map(projection.input, & &1.name) == [:repo, :run_id, :failed_only]

    assert Enum.map(projection.output, & &1.name) == [
             :rerun_requested,
             :repo,
             :run_id,
             :failed_only
           ]

    assert projection.risk == :write
    assert projection.confirmation == :always
    assert projection.resource == :workflow_run
    assert projection.verb == :dispatch
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver

    assert Jido.Connect.GitHub.Actions.RerunWorkflowRun.name() ==
             "github_workflow_run_rerun"
  end

  test "generated workflow run cancel action metadata tracks confirmation" do
    projection = Jido.Connect.GitHub.Actions.CancelWorkflowRun.jido_connect_projection()

    assert projection.action_id == "github.workflow_run.cancel"
    assert projection.label == "Cancel workflow run"
    assert Enum.map(projection.input, & &1.name) == [:repo, :run_id]

    assert Enum.map(projection.output, & &1.name) == [
             :cancel_requested,
             :repo,
             :run_id
           ]

    assert projection.risk == :write
    assert projection.confirmation == :always
    assert projection.resource == :workflow_run
    assert projection.verb == :cancel
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver

    assert Jido.Connect.GitHub.Actions.CancelWorkflowRun.name() ==
             "github_workflow_run_cancel"
  end

  test "generated workflow dispatch action metadata tracks ref and typed inputs" do
    projection = Jido.Connect.GitHub.Actions.DispatchWorkflow.jido_connect_projection()

    assert projection.action_id == "github.workflow.dispatch"
    assert projection.label == "Dispatch workflow"
    assert Enum.map(projection.input, & &1.name) == [:repo, :workflow, :ref, :inputs]
    assert Enum.map(projection.output, & &1.name) == [:dispatched, :repo, :workflow, :ref]
    assert projection.risk == :write
    assert projection.confirmation == :always
    assert projection.resource == :workflow
    assert projection.verb == :dispatch
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.DispatchWorkflow.name() == "github_workflow_dispatch"
  end

  test "generated get pull request action metadata tracks detail fields" do
    projection = Jido.Connect.GitHub.Actions.GetPullRequest.jido_connect_projection()

    assert projection.action_id == "github.pull_request.get"
    assert projection.label == "Get pull request"
    assert Enum.map(projection.input, & &1.name) == [:repo, :pull_number]
    assert Enum.map(projection.output, & &1.name) == [:pull_request]
    assert projection.risk == :read
    assert projection.resource == :pull_request
    assert projection.verb == :get
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.GetPullRequest.name() == "github_pull_request_get"
  end

  test "generated pull request file list action metadata tracks pagination fields" do
    projection = Jido.Connect.GitHub.Actions.ListPullRequestFiles.jido_connect_projection()

    assert projection.action_id == "github.pull_request_file.list"
    assert projection.label == "List pull request files"
    assert Enum.map(projection.input, & &1.name) == [:repo, :pull_number, :page, :per_page]
    assert Enum.map(projection.output, & &1.name) == [:files]
    assert projection.risk == :read
    assert projection.resource == :pull_request_file
    assert projection.verb == :list
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver

    assert Jido.Connect.GitHub.Actions.ListPullRequestFiles.name() ==
             "github_pull_request_file_list"
  end

  test "generated create pull request action metadata tracks creation fields" do
    projection = Jido.Connect.GitHub.Actions.CreatePullRequest.jido_connect_projection()

    assert projection.action_id == "github.pull_request.create"
    assert projection.label == "Create pull request"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :title,
             :body,
             :head,
             :base,
             :draft,
             :maintainer_can_modify,
             :risk,
             :confirmation
           ]

    assert Enum.map(projection.output, & &1.name) == [:number, :url, :title, :state]
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :pull_request
    assert projection.verb == :create
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.CreatePullRequest.name() == "github_pull_request_create"
  end

  test "generated update pull request action metadata tracks editable fields" do
    projection = Jido.Connect.GitHub.Actions.UpdatePullRequest.jido_connect_projection()

    assert projection.action_id == "github.pull_request.update"
    assert projection.label == "Update pull request"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :pull_number,
             :title,
             :body,
             :base,
             :state,
             :maintainer_can_modify,
             :draft
           ]

    assert Enum.map(projection.output, & &1.name) == [:number, :url, :title, :state]
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :pull_request
    assert projection.verb == :update
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.UpdatePullRequest.name() == "github_pull_request_update"
  end

  test "generated request pull request reviewers action metadata tracks reviewer fields" do
    projection = Jido.Connect.GitHub.Actions.RequestPullRequestReviewers.jido_connect_projection()

    assert projection.action_id == "github.pull_request.reviewers.request"
    assert projection.label == "Request pull request reviewers"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :pull_number,
             :reviewers,
             :team_reviewers
           ]

    assert Enum.map(projection.output, & &1.name) == [
             :number,
             :url,
             :title,
             :state,
             :requested_reviewers,
             :requested_teams
           ]

    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :pull_request
    assert projection.verb == :update
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver

    assert Jido.Connect.GitHub.Actions.RequestPullRequestReviewers.name() ==
             "github_pull_request_reviewers_request"
  end

  test "generated create pull request review comment action metadata tracks diff fields" do
    projection =
      Jido.Connect.GitHub.Actions.CreatePullRequestReviewComment.jido_connect_projection()

    assert projection.action_id == "github.pull_request.review_comment.create"
    assert projection.label == "Create pull request review comment"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :pull_number,
             :body,
             :commit_id,
             :path,
             :position,
             :line,
             :side,
             :start_line,
             :start_side
           ]

    assert Enum.map(projection.output, & &1.name) == [
             :id,
             :url,
             :body,
             :path,
             :position,
             :line,
             :side,
             :start_line,
             :start_side
           ]

    assert projection.data_classification == :message_content
    assert projection.risk == :external_write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :pull_request_review_comment
    assert projection.verb == :create
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver

    assert Jido.Connect.GitHub.Actions.CreatePullRequestReviewComment.name() ==
             "github_pull_request_review_comment_create"
  end

  test "generated merge pull request action metadata tracks merge guard fields" do
    projection = Jido.Connect.GitHub.Actions.MergePullRequest.jido_connect_projection()

    assert projection.action_id == "github.pull_request.merge"
    assert projection.label == "Merge pull request"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :pull_number,
             :merge_method,
             :commit_title,
             :commit_message,
             :sha
           ]

    assert Enum.map(projection.output, & &1.name) == [:sha, :merged, :message]
    assert projection.risk == :write
    assert projection.confirmation == :always
    assert projection.resource == :pull_request
    assert projection.verb == :merge
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.MergePullRequest.name() == "github_pull_request_merge"
  end

  test "invokes GitHub list issue action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{issues: [%{number: 1, title: "First"}]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.list",
               %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub read file action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              repo: "org/repo",
              path: "README.md",
              name: "README.md",
              encoding: "utf-8",
              binary: false,
              content: "# Project\n"
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.file.read",
               %{repo: "org/repo", path: "README.md", ref: "main"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub file update action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              repo: "org/repo",
              path: "README.md",
              sha: "def456",
              commit_sha: "commit123",
              commit_message: "Update README"
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.file.update",
               %{
                 repo: "org/repo",
                 path: "README.md",
                 content: "# Project\n",
                 message: "Update README",
                 branch: "main",
                 sha: "abc123",
                 committer: %{name: "Octo Cat", email: "octo@example.com"}
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub list repositories action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              total_count: 1,
              repositories: [%{id: 10, full_name: "org/repo", owner: %{login: "org"}}]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.repo.list",
               %{page: 2, per_page: 10},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub installation repository action through injected client and lease" do
    {context, lease} =
      context_and_lease(
        profile: :installation,
        lease_metadata: %{permissions: %{"metadata" => "read", "issues" => "write"}}
      )

    assert {:ok,
            %{
              total_count: 1,
              permissions: %{"metadata" => "read", "issues" => "write"},
              repositories: [%{id: 10, full_name: "org/repo", owner: %{login: "org"}}]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.installation_repository.list",
               %{page: 2, per_page: 10},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub get repository action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              id: 10,
              name: "repo",
              full_name: "org/repo",
              permissions: %{pull: true}
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.repo.get",
               %{owner: "org", name: "repo"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub list branches action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              branches: [
                %{
                  name: "main",
                  sha: "abc123",
                  protected: true,
                  protection_url:
                    "https://api.github.test/repos/org/repo/branches/main/protection"
                }
              ]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.branch.list",
               %{repo: "org/repo", page: 2, per_page: 10},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub create branch action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              repo: "org/repo",
              branch: "feature/example",
              ref: "refs/heads/feature/example",
              sha: "abc123"
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.branch.create",
               %{repo: "org/repo", branch: "feature/example", source_ref: "main"},
               context: context,
               credential_lease: lease
             )
  end

  test "validates GitHub create branch source inputs before client calls" do
    credentials = %{access_token: "token", github_client: FakeGitHubClient}
    handler = Jido.Connect.GitHub.Handlers.Actions.CreateBranch

    assert {:error, %Connect.Error.ValidationError{reason: :missing_source, subject: :source}} =
             handler.run(%{repo: "org/repo", branch: "feature/example"}, %{
               credentials: credentials
             })

    assert {:error, %Connect.Error.ValidationError{reason: :missing_source, subject: :source}} =
             handler.run(%{repo: "org/repo", branch: "feature/example", source_ref: ""}, %{
               credentials: credentials
             })

    assert {:error, %Connect.Error.ValidationError{reason: :ambiguous_source, subject: :source}} =
             handler.run(
               %{
                 repo: "org/repo",
                 branch: "feature/example",
                 source_ref: "main",
                 source_sha: "abc123"
               },
               %{credentials: credentials}
             )

    assert {:error, %Connect.Error.ConfigError{key: :github_client}} =
             handler.run(
               %{repo: "org/repo", branch: "feature/example", source_sha: "abc123"},
               %{credentials: %{access_token: "token"}}
             )
  end

  test "invokes GitHub update issue action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{number: 2, title: "Bug", state: "open"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.update",
               %{repo: "org/repo", issue_number: 2, title: "Bug", labels: ["bug"], type: "Bug"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub list pull requests action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              pull_requests: [
                %{number: 4, title: "Feature", head: %{ref: "feature"}, base: %{ref: "main"}}
              ]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.list",
               %{
                 repo: "org/repo",
                 state: "open",
                 head: "octo:feature",
                 base: "main",
                 sort: "updated",
                 direction: "asc",
                 page: 2,
                 per_page: 10
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub get pull request action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              pull_request: %{
                number: 4,
                title: "Feature",
                mergeable: true,
                mergeable_state: "clean",
                head: %{ref: "feature"},
                base: %{ref: "main"},
                issue: %{
                  labels: [%{name: "enhancement"}],
                  assignees: [%{login: "octocat"}],
                  milestone: %{title: "v1"}
                }
              }
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.get",
               %{repo: "org/repo", pull_number: 4},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub list pull request files action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              files: [
                %{
                  filename: "lib/example.ex",
                  status: "modified",
                  additions: 12,
                  deletions: 3,
                  changes: 15,
                  sha: "abc123"
                }
              ]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request_file.list",
               %{repo: "org/repo", pull_number: 4, page: 2, per_page: 10},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub create pull request action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{number: 5, title: "Feature", state: "open"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.create",
               %{
                 repo: "org/repo",
                 title: "Feature",
                 body: "Implements the feature",
                 head: "octo:feature",
                 base: "main",
                 draft: true,
                 maintainer_can_modify: false,
                 risk: "low",
                 confirmation: "approved"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub update pull request action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{number: 5, title: "Updated feature", state: "open"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.update",
               %{
                 repo: "org/repo",
                 pull_number: 5,
                 title: "Updated feature",
                 body: "Updated body",
                 base: "release",
                 state: "open",
                 maintainer_can_modify: true,
                 draft: false
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub merge pull request action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{sha: "def456", merged: true, message: "Pull Request successfully merged"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.merge",
               %{
                 repo: "org/repo",
                 pull_number: 5,
                 merge_method: "squash",
                 commit_title: "Merge feature",
                 commit_message: "Ship the feature",
                 sha: "abc123"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub request pull request reviewers action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              number: 5,
              title: "Feature",
              state: "open",
              requested_reviewers: [%{login: "octocat"}],
              requested_teams: [%{slug: "core"}]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.reviewers.request",
               %{
                 repo: "org/repo",
                 pull_number: 5,
                 reviewers: ["octocat"],
                 team_reviewers: ["core"]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub create pull request review comment action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              id: 44,
              body: "Consider extracting this helper",
              path: "lib/example.ex",
              line: 12,
              side: "RIGHT"
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.review_comment.create",
               %{
                 repo: "org/repo",
                 pull_number: 5,
                 body: "Consider extracting this helper",
                 commit_id: "abc123",
                 path: "lib/example.ex",
                 line: 12,
                 side: "RIGHT"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "rejects ambiguous pull request review comment locations" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{reason: :ambiguous_location, subject: :position}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.review_comment.create",
               %{
                 repo: "org/repo",
                 pull_number: 5,
                 body: "Consider extracting this helper",
                 commit_id: "abc123",
                 path: "lib/example.ex",
                 position: 3,
                 line: 12,
                 side: "RIGHT"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "validates pull request review comment location shapes" do
    credentials = %{access_token: "token", github_client: FakeGitHubClient}

    base = %{
      repo: "org/repo",
      pull_number: 5,
      body: "Consider extracting this helper",
      commit_id: "abc123",
      path: "lib/example.ex"
    }

    handler = Jido.Connect.GitHub.Handlers.Actions.CreatePullRequestReviewComment

    assert {:ok, %{id: 45, position: 3}} =
             handler.run(Map.put(base, :position, 3), %{credentials: credentials})

    assert {:error, %Connect.Error.ValidationError{reason: :missing_location, subject: :position}} =
             handler.run(base, %{credentials: credentials})

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_location, subject: :line}} =
             handler.run(Map.merge(base, %{line: 0, side: "RIGHT"}), %{credentials: credentials})

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_side, subject: :side}} =
             handler.run(Map.merge(base, %{line: 12, side: "CENTER"}), %{credentials: credentials})

    assert {:error,
            %Connect.Error.ValidationError{reason: :missing_start_side, subject: :start_side}} =
             handler.run(Map.merge(base, %{line: 12, side: "RIGHT", start_line: 10}), %{
               credentials: credentials
             })

    assert {:error,
            %Connect.Error.ValidationError{reason: :missing_start_line, subject: :start_line}} =
             handler.run(Map.merge(base, %{line: 12, side: "RIGHT", start_side: "RIGHT"}), %{
               credentials: credentials
             })

    assert {:error,
            %Connect.Error.ValidationError{reason: :invalid_line_range, subject: :start_line}} =
             handler.run(
               Map.merge(base, %{line: 12, side: "RIGHT", start_line: 13, start_side: "RIGHT"}),
               %{credentials: credentials}
             )

    assert {:error,
            %Connect.Error.ValidationError{reason: :ambiguous_location, subject: :position}} =
             handler.run(Map.merge(base, %{position: 3, side: "RIGHT"}), %{
               credentials: credentials
             })
  end

  test "rejects empty reviewer lists before requesting pull request reviewers" do
    {context, lease} = context_and_lease()

    assert {:error, %Connect.Error.ValidationError{reason: :empty_reviewers, subject: :reviewers}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.reviewers.request",
               %{repo: "org/repo", pull_number: 5, reviewers: [], team_reviewers: []},
               context: context,
               credential_lease: lease
             )
  end

  test "GitHub App installation connections use installation-specific scopes" do
    {context, lease} =
      context_and_lease(profile: :installation, scopes: ["metadata:read", "issues:read"])

    assert {:ok, %{issues: [%{number: 1, title: "First"}]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.list",
               %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    read_context = %{
      context
      | connection: %{context.connection | scopes: ["metadata:read", "contents:read"]}
    }

    assert {:ok, %{path: "README.md", content: "# Project\n"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.file.read",
               %{repo: "org/repo", path: "README.md", ref: "main"},
               context: read_context,
               credential_lease: lease
             )

    assert {:ok, %{full_name: "org/repo"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.repo.get",
               %{owner: "org", name: "repo"},
               context: context,
               credential_lease: lease
             )

    missing_write = %{context | connection: %{context.connection | scopes: ["metadata:read"]}}

    assert {:error,
            %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["contents:read"]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.file.read",
               %{repo: "org/repo", path: "README.md", ref: "main"},
               context: missing_write,
               credential_lease: lease
             )

    write_context = %{
      context
      | connection: %{context.connection | scopes: ["metadata:read", "contents:write"]}
    }

    assert {:ok, %{sha: "def456", commit_sha: "commit123"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.file.update",
               %{
                 repo: "org/repo",
                 path: "README.md",
                 content: "# Project\n",
                 message: "Update README",
                 branch: "main",
                 sha: "abc123",
                 committer: %{name: "Octo Cat", email: "octo@example.com"}
               },
               context: write_context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["contents:write"]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.file.update",
               %{
                 repo: "org/repo",
                 path: "README.md",
                 content: "# Project\n",
                 message: "Update README"
               },
               context: missing_write,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["issues:write"]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.create",
               %{repo: "org/repo", title: "Bug"},
               context: missing_write,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["issues:write"]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.label.add",
               %{repo: "org/repo", issue_number: 2, labels: ["bug"]},
               context: missing_write,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["issues:write"]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.label.remove",
               %{repo: "org/repo", issue_number: 2, label: "bug"},
               context: missing_write,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["issues:write"]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.assign",
               %{repo: "org/repo", issue_number: 2, assignees: ["octocat"]},
               context: missing_write,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["pull_requests:write"]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.create",
               %{repo: "org/repo", title: "Feature", head: "octo:feature", base: "main"},
               context: missing_write,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["pull_requests:write"]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.update",
               %{repo: "org/repo", pull_number: 5, title: "Updated feature"},
               context: missing_write,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["pull_requests:write"]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.reviewers.request",
               %{repo: "org/repo", pull_number: 5, reviewers: ["octocat"]},
               context: missing_write,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["pull_requests:write"]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.review_comment.create",
               %{
                 repo: "org/repo",
                 pull_number: 5,
                 body: "Consider extracting this helper",
                 commit_id: "abc123",
                 path: "lib/example.ex",
                 line: 12,
                 side: "RIGHT"
               },
               context: missing_write,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["pull_requests:write", "contents:write"]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.merge",
               %{repo: "org/repo", pull_number: 5, merge_method: "merge"},
               context: missing_write,
               credential_lease: lease
             )
  end

  test "invokes GitHub create issue action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{number: 2, title: "Bug", state: "open"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.create",
               %{repo: "org/repo", title: "Bug"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub add issue labels action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              labels: [
                %{name: "bug", color: "d73a4a", description: "Something is not working"},
                %{name: "triage", color: "ededed"}
              ]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.label.add",
               %{repo: "org/repo", issue_number: 2, labels: ["bug", "triage"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub remove issue label action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{labels: [%{name: "triage", color: "ededed"}]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.label.remove",
               %{repo: "org/repo", issue_number: 2, label: "bug"},
               context: context,
               credential_lease: lease
             )
  end

  test "rejects empty label list before adding issue labels" do
    {context, lease} = context_and_lease()

    assert {:error, %Connect.Error.ValidationError{reason: :empty_labels, subject: :labels}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.label.add",
               %{repo: "org/repo", issue_number: 2, labels: []},
               context: context,
               credential_lease: lease
             )
  end

  test "rejects blank label before removing an issue label" do
    {context, lease} = context_and_lease()

    assert {:error, %Connect.Error.ValidationError{reason: :empty_label, subject: :label}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.label.remove",
               %{repo: "org/repo", issue_number: 2, label: ""},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub assign issue action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              number: 2,
              title: "Bug",
              state: "open",
              assignees: [%{login: "octocat"}, %{login: "mona"}]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.assign",
               %{repo: "org/repo", issue_number: 2, assignees: ["octocat", "mona"]},
               context: context,
               credential_lease: lease
             )
  end

  test "rejects empty assignee list before assigning issue" do
    {context, lease} = context_and_lease()

    assert {:error, %Connect.Error.ValidationError{reason: :empty_assignees, subject: :assignees}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.assign",
               %{repo: "org/repo", issue_number: 2, assignees: []},
               context: context,
               credential_lease: lease
             )
  end

  test "rejects blank assignee logins before assigning issue" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{reason: :invalid_assignees, subject: :assignees}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.assign",
               %{repo: "org/repo", issue_number: 2, assignees: ["octocat", " "]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub create issue comment action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{id: 3, body: "Ship it"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue_comment.create",
               %{repo: "org/repo", issue_number: 2, body: "Ship it"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub list issue comments action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              comments: [
                %{
                  id: 3,
                  body: "Ship it",
                  user: %{login: "octocat"},
                  author_association: "MEMBER",
                  created_at: "2026-04-29T10:01:00Z",
                  updated_at: "2026-04-29T10:02:00Z"
                }
              ]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue_comment.list",
               %{
                 repo: "org/repo",
                 issue_number: 2,
                 since: "2026-04-29T10:00:00Z",
                 page: 2,
                 per_page: 10
               },
               context: context,
               credential_lease: lease
             )
  end

  test "generated action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{issues: [%{number: 1, title: "First"}]}} =
             Jido.Connect.GitHub.Actions.ListIssues.run(%{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })
  end

  test "generated add issue labels action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              labels: [
                %{name: "bug", color: "d73a4a", description: "Something is not working"},
                %{name: "triage", color: "ededed"}
              ]
            }} =
             Jido.Connect.GitHub.Actions.AddIssueLabels.run(
               %{repo: "org/repo", issue_number: 2, labels: ["bug", "triage"]},
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated remove issue label action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{labels: [%{name: "triage", color: "ededed"}]}} =
             Jido.Connect.GitHub.Actions.RemoveIssueLabel.run(
               %{repo: "org/repo", issue_number: 2, label: "bug"},
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated repository action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              total_count: 1,
              repositories: [%{id: 10, full_name: "org/repo", owner: %{login: "org"}}]
            }} =
             Jido.Connect.GitHub.Actions.ListRepositories.run(%{page: 2, per_page: 10}, %{
               integration_context: context,
               credential_lease: lease
             })
  end

  test "generated repository search action delegates with query helpers and pagination" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              total_count: 1,
              repositories: [
                %{
                  id: 10,
                  full_name: "acme/repo",
                  owner: %{login: "acme"},
                  stargazers_count: 42
                }
              ]
            }} =
             Jido.Connect.GitHub.Actions.SearchRepositories.run(
               %{
                 query: "jido",
                 org: "acme",
                 language: "elixir",
                 topic: "agent",
                 archived: false,
                 fork: false,
                 sort: "stars",
                 page: 2,
                 per_page: 10
               },
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated get repository action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              id: 10,
              full_name: "org/repo",
              owner: %{login: "org"},
              permissions: %{pull: true}
            }} =
             Jido.Connect.GitHub.Actions.GetRepository.run(%{owner: "org", name: "repo"}, %{
               integration_context: context,
               credential_lease: lease
             })
  end

  test "generated branch list action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{branches: [%{name: "main", sha: "abc123", protected: true}]}} =
             Jido.Connect.GitHub.Actions.ListBranches.run(
               %{repo: "org/repo", page: 2, per_page: 10},
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated branch create action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              repo: "org/repo",
              branch: "feature/example",
              ref: "refs/heads/feature/example",
              sha: "abc123"
            }} =
             Jido.Connect.GitHub.Actions.CreateBranch.run(
               %{repo: "org/repo", branch: "feature/example", source_ref: "main"},
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated commit list action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              commits: [
                %{
                  sha: "abc123",
                  message: "Add example",
                  author: %{login: "octocat"},
                  committer: %{login: "mona"},
                  parents: [%{sha: "def456"}]
                }
              ]
            }} =
             Jido.Connect.GitHub.Actions.ListCommits.run(
               %{repo: "org/repo", ref: "main", path: "lib/example.ex", page: 2, per_page: 10},
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated compare refs action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              status: "ahead",
              ahead_by: 2,
              behind_by: 0,
              total_commits: 2,
              commits: [%{sha: "abc123", message: "Add example"}],
              files: [%{filename: "lib/example.ex", status: "modified", changes: 15}]
            }} =
             Jido.Connect.GitHub.Actions.CompareRefs.run(
               %{repo: "org/repo", base: "main", head: "feature/ref", page: 2, per_page: 10},
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated installation repository action delegates to integration invoke runtime" do
    {context, lease} =
      context_and_lease(
        profile: :installation,
        lease_metadata: %{permissions: %{"metadata" => "read", "issues" => "write"}}
      )

    assert {:ok,
            %{
              total_count: 1,
              permissions: %{"metadata" => "read", "issues" => "write"},
              repositories: [%{id: 10, full_name: "org/repo", owner: %{login: "org"}}]
            }} =
             Jido.Connect.GitHub.Actions.ListInstallationRepositories.run(
               %{page: 2, per_page: 10},
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated workflow run action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              total_count: 1,
              workflow_runs: [%{id: 22, name: "CI", status: "completed"}]
            }} =
             Jido.Connect.GitHub.Actions.ListWorkflowRuns.run(
               %{
                 repo: "org/repo",
                 workflow: "ci.yml",
                 branch: "main",
                 status: "completed",
                 event: "push",
                 page: 2,
                 per_page: 10
               },
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated release action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              releases: [
                %{
                  id: 101,
                  tag_name: "v1.0.0",
                  draft: false,
                  prerelease: false,
                  author: %{login: "octocat"}
                }
              ],
              tags: [%{name: "v1.0.0", sha: "abc123"}]
            }} =
             Jido.Connect.GitHub.Actions.ListReleases.run(
               %{repo: "org/repo", page: 2, per_page: 10},
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated release create action delegates with publication settings" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              id: 102,
              tag_name: "v1.0.0",
              draft: true,
              prerelease: true,
              author: %{login: "octocat"}
            }} =
             Jido.Connect.GitHub.Actions.CreateRelease.run(
               %{
                 repo: "org/repo",
                 tag_name: "v1.0.0",
                 target_commitish: "main",
                 name: "v1.0.0",
                 body: "Release notes",
                 draft: true,
                 prerelease: true,
                 generate_release_notes: true,
                 make_latest: "false"
               },
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated release asset upload action delegates with base64 content" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              id: 201,
              name: "dist.zip",
              label: "Distribution",
              state: "uploaded",
              content_type: "application/zip",
              size: 9,
              download_count: 0,
              uploader: %{login: "octocat"}
            } = asset} =
             Jido.Connect.GitHub.Actions.UploadReleaseAsset.run(
               %{
                 repo: "org/repo",
                 upload_url:
                   "https://uploads.github.test/repos/org/repo/releases/102/assets{?name,label}",
                 name: "dist.zip",
                 label: "Distribution",
                 content_type: "application/zip",
                 content_base64: "emlwLWJ5dGVz"
               },
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )

    refute Map.has_key?(asset, :content)
    refute Map.has_key?(asset, :content_base64)
  end

  test "generated workflow run job action delegates with normalized CI status" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              total_count: 1,
              ci_status: "failure",
              jobs: [
                %{
                  id: 33,
                  name: "test",
                  ci_status: "failure",
                  steps: [
                    %{number: 1, name: "checkout", ci_status: "success"},
                    %{number: 2, name: "mix test", ci_status: "failure"}
                  ]
                }
              ]
            }} =
             Jido.Connect.GitHub.Actions.ListWorkflowRunJobs.run(
               %{repo: "org/repo", run_id: 22, filter: "latest", page: 2, per_page: 10},
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated workflow run rerun action delegates with confirmation metadata" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              rerun_requested: true,
              repo: "org/repo",
              run_id: 22,
              failed_only: true
            }} =
             Jido.Connect.GitHub.Actions.RerunWorkflowRun.run(
               %{repo: "org/repo", run_id: 22, failed_only: true},
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated workflow run cancel action delegates with confirmation metadata" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              cancel_requested: true,
              repo: "org/repo",
              run_id: 22
            }} =
             Jido.Connect.GitHub.Actions.CancelWorkflowRun.run(
               %{repo: "org/repo", run_id: 22},
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated issue search action delegates with query helpers and pagination" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              total_count: 2,
              results: [
                %{type: :issue, number: 5, title: "Crash", labels: [%{name: "bug"}]},
                %{type: :pull_request, number: 6, title: "Fix crash", user: %{login: "octocat"}}
              ]
            }} =
             Jido.Connect.GitHub.Actions.SearchIssues.run(
               %{
                 repo: "org/repo",
                 query: "crash",
                 type: "pull_request",
                 state: "open",
                 author: "octocat",
                 assignee: "mona",
                 label: "bug",
                 page: 2,
                 per_page: 10
               },
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated workflow dispatch action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              dispatched: true,
              repo: "org/repo",
              workflow: "ci.yml",
              ref: "main"
            }} =
             Jido.Connect.GitHub.Actions.DispatchWorkflow.run(
               %{
                 repo: "org/repo",
                 workflow: "ci.yml",
                 ref: "main",
                 inputs: %{"environment" => "staging", "deploy" => true}
               },
               %{
                 integration_context: context,
                 credential_lease: lease
               }
             )
  end

  test "generated action rejects missing runtime context before provider execution" do
    assert {:error, %Connect.Error.AuthError{reason: :context_required}} =
             Jido.Connect.GitHub.Actions.ListIssues.run(%{repo: "org/repo"}, %{})
  end

  test "generated poll sensor initializes and emits Jido signals on tick" do
    {context, lease} = context_and_lease()

    assert {:ok, state, [{:schedule, 300_000}]} =
             Jido.Connect.GitHub.Sensors.NewIssues.init(%{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })

    assert {:ok, _state, [{:emit, signal}, {:schedule, 300_000}]} =
             Jido.Connect.GitHub.Sensors.NewIssues.handle_event(:tick, state)

    assert %Jido.Signal{} = signal
    assert signal.type == "github.issue.new"
    assert signal.source == "/jido/connect/github"
    assert signal.data.issue_number == 3
  end

  test "pull request update poll advances checkpoint and skips checkpoint duplicates" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              signals: [
                %{
                  repo: "org/repo",
                  pull_number: 8,
                  title: "Eighth",
                  state: "open",
                  updated_at: "2026-04-29T10:02:00Z"
                }
              ],
              checkpoint: "2026-04-29T10:02:00Z"
            }} =
             Connect.poll(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.updated",
               %{repo: "org/repo"},
               %{
                 context: context,
                 credential_lease: lease,
                 checkpoint: "2026-04-29T10:00:00Z"
               }
             )
  end

  test "generated pull request update sensor continues checkpoint between ticks" do
    {context, lease} = context_and_lease()

    assert {:ok, state, [{:schedule, 300_000}]} =
             Jido.Connect.GitHub.Sensors.UpdatedPullRequests.init(%{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })

    assert {:ok, state, [{:emit, signal}, {:schedule, 300_000}]} =
             Jido.Connect.GitHub.Sensors.UpdatedPullRequests.handle_event(:tick, state)

    assert signal.type == "github.pull_request.updated"
    assert signal.data.pull_number == 7
    assert state.checkpoint == "2026-04-29T10:00:00Z"

    assert {:ok, state, [{:emit, next_signal}, {:schedule, 300_000}]} =
             Jido.Connect.GitHub.Sensors.UpdatedPullRequests.handle_event(:tick, state)

    assert next_signal.data.pull_number == 8
    assert state.checkpoint == "2026-04-29T10:02:00Z"
  end

  test "workflow run update poll emits updates and completions since checkpoint" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              signals: [
                %{
                  repo: "org/repo",
                  workflow_run_id: 32,
                  workflow_run_number: 19,
                  workflow_name: "CI",
                  action: "completed",
                  status: "completed",
                  conclusion: "failure",
                  ci_status: "failure",
                  failure: true,
                  branch: "main",
                  updated_at: "2026-04-29T10:03:00Z"
                }
              ],
              checkpoint: "2026-04-29T10:03:00Z"
            }} =
             Connect.poll(
               Jido.Connect.GitHub.integration(),
               "github.workflow_run.updated",
               %{repo: "org/repo"},
               %{
                 context: context,
                 credential_lease: lease,
                 checkpoint: "2026-04-29T10:00:00Z"
               }
             )
  end

  test "generated workflow run update sensor continues checkpoint between ticks" do
    {context, lease} = context_and_lease()

    assert {:ok, state, [{:schedule, 300_000}]} =
             Jido.Connect.GitHub.Sensors.WorkflowRunUpdates.init(%{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })

    assert {:ok, state, [{:emit, signal}, {:schedule, 300_000}]} =
             Jido.Connect.GitHub.Sensors.WorkflowRunUpdates.handle_event(:tick, state)

    assert signal.type == "github.workflow_run.updated"
    assert signal.data.workflow_run_id == 31
    assert signal.data.action == "updated"
    assert signal.data.ci_status == "in_progress"
    assert state.checkpoint == "2026-04-29T10:00:00Z"

    assert {:ok, state, [{:emit, next_signal}, {:schedule, 300_000}]} =
             Jido.Connect.GitHub.Sensors.WorkflowRunUpdates.handle_event(:tick, state)

    assert next_signal.data.workflow_run_id == 32
    assert next_signal.data.action == "completed"
    assert next_signal.data.failure == true
    assert state.checkpoint == "2026-04-29T10:03:00Z"
  end

  test "generated plugin lists and filters generated actions" do
    spec = Jido.Connect.GitHub.Plugin.plugin_spec(%{})

    assert spec.actions == [
             Jido.Connect.GitHub.Actions.ListRepositories,
             Jido.Connect.GitHub.Actions.SearchRepositories,
             Jido.Connect.GitHub.Actions.ListInstallationRepositories,
             Jido.Connect.GitHub.Actions.GetRepository,
             Jido.Connect.GitHub.Actions.ListBranches,
             Jido.Connect.GitHub.Actions.CreateBranch,
             Jido.Connect.GitHub.Actions.ListCommits,
             Jido.Connect.GitHub.Actions.CompareRefs,
             Jido.Connect.GitHub.Actions.ReadFile,
             Jido.Connect.GitHub.Actions.UpdateFile,
             Jido.Connect.GitHub.Actions.ListIssues,
             Jido.Connect.GitHub.Actions.CreateIssue,
             Jido.Connect.GitHub.Actions.AddIssueLabels,
             Jido.Connect.GitHub.Actions.RemoveIssueLabel,
             Jido.Connect.GitHub.Actions.AssignIssue,
             Jido.Connect.GitHub.Actions.ListPullRequests,
             Jido.Connect.GitHub.Actions.SearchIssues,
             Jido.Connect.GitHub.Actions.ListWorkflowRuns,
             Jido.Connect.GitHub.Actions.ListReleases,
             Jido.Connect.GitHub.Actions.CreateRelease,
             Jido.Connect.GitHub.Actions.UploadReleaseAsset,
             Jido.Connect.GitHub.Actions.ListWorkflowRunJobs,
             Jido.Connect.GitHub.Actions.RerunWorkflowRun,
             Jido.Connect.GitHub.Actions.CancelWorkflowRun,
             Jido.Connect.GitHub.Actions.DispatchWorkflow,
             Jido.Connect.GitHub.Actions.GetPullRequest,
             Jido.Connect.GitHub.Actions.ListPullRequestFiles,
             Jido.Connect.GitHub.Actions.CreatePullRequest,
             Jido.Connect.GitHub.Actions.UpdatePullRequest,
             Jido.Connect.GitHub.Actions.RequestPullRequestReviewers,
             Jido.Connect.GitHub.Actions.CreatePullRequestReviewComment,
             Jido.Connect.GitHub.Actions.MergePullRequest,
             Jido.Connect.GitHub.Actions.UpdateIssue,
             Jido.Connect.GitHub.Actions.CreateIssueComment,
             Jido.Connect.GitHub.Actions.ListIssueComments
           ]

    filtered =
      Jido.Connect.GitHub.Plugin.plugin_spec(%{
        allowed_actions: ["github.issue.list"]
      })

    assert filtered.actions == [Jido.Connect.GitHub.Actions.ListIssues]
  end

  test "generated plugin reports basic tool availability" do
    available_tools =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        connection: elem(context_and_lease(), 0).connection
      })

    list_available = availability_for(available_tools, "github.repo.list")
    assert list_available.state == :available

    missing_scope_tools =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        connection: %{elem(context_and_lease(), 0).connection | scopes: []}
      })

    missing_scopes = availability_for(missing_scope_tools, "github.issue.list")
    assert missing_scopes.state == :missing_scopes
    assert missing_scopes.missing_scopes == ["repo"]

    installation_tools =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        connection:
          elem(
            context_and_lease(profile: :installation, scopes: ["metadata:read"]),
            0
          ).connection
      })

    installation_missing_scopes = availability_for(installation_tools, "github.issue.list")
    assert installation_missing_scopes.state == :missing_scopes
    assert installation_missing_scopes.missing_scopes == ["issues:read"]

    workflow_installation_missing_scopes =
      availability_for(installation_tools, "github.workflow_run.list")

    assert workflow_installation_missing_scopes.state == :missing_scopes
    assert workflow_installation_missing_scopes.missing_scopes == ["actions:read"]

    workflow_job_installation_missing_scopes =
      availability_for(installation_tools, "github.workflow_run.job.list")

    assert workflow_job_installation_missing_scopes.state == :missing_scopes
    assert workflow_job_installation_missing_scopes.missing_scopes == ["actions:read"]

    release_installation_missing_scopes =
      availability_for(installation_tools, "github.release.list")

    assert release_installation_missing_scopes.state == :missing_scopes
    assert release_installation_missing_scopes.missing_scopes == ["contents:read"]

    create_release_installation_missing_scopes =
      availability_for(installation_tools, "github.release.create")

    assert create_release_installation_missing_scopes.state == :missing_scopes
    assert create_release_installation_missing_scopes.missing_scopes == ["contents:write"]

    upload_release_asset_installation_missing_scopes =
      availability_for(installation_tools, "github.release_asset.upload")

    assert upload_release_asset_installation_missing_scopes.state == :missing_scopes
    assert upload_release_asset_installation_missing_scopes.missing_scopes == ["contents:write"]

    workflow_rerun_installation_missing_scopes =
      availability_for(installation_tools, "github.workflow_run.rerun")

    assert workflow_rerun_installation_missing_scopes.state == :missing_scopes
    assert workflow_rerun_installation_missing_scopes.missing_scopes == ["actions:write"]

    workflow_cancel_installation_missing_scopes =
      availability_for(installation_tools, "github.workflow_run.cancel")

    assert workflow_cancel_installation_missing_scopes.state == :missing_scopes
    assert workflow_cancel_installation_missing_scopes.missing_scopes == ["actions:write"]

    workflow_dispatch_installation_missing_scopes =
      availability_for(installation_tools, "github.workflow.dispatch")

    assert workflow_dispatch_installation_missing_scopes.state == :missing_scopes
    assert workflow_dispatch_installation_missing_scopes.missing_scopes == ["actions:write"]

    [disabled | _] =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        allowed_actions: []
      })

    assert disabled.state == :disabled_by_policy

    [required | _] = Jido.Connect.GitHub.Plugin.tool_availability(%{})
    assert required.state == :connection_required
  end

  test "validates required action input fields" do
    assert {:error, %Connect.Error.ValidationError{reason: :input, details: details}} =
             Connect.invoke(Jido.Connect.GitHub.integration(), "github.issue.list", %{},
               context: %{tenant_id: "tenant_1", actor: %{id: "user_1", type: :user}},
               credential_lease: %{
                 connection_id: "conn_1",
                 expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
                 fields: %{github_client: FakeGitHubClient}
               }
             )

    assert [%Zoi.Error{code: :required, path: [:repo]}] = details.errors
  end

  defp context_and_lease(opts \\ []) do
    profile = Keyword.get(opts, :profile, :user)
    scopes = Keyword.get(opts, :scopes, default_scopes(profile))
    lease_metadata = Keyword.get(opts, :lease_metadata, %{})

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :github,
        profile: profile,
        tenant_id: "tenant_1",
        owner_type: owner_type(profile),
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", github_client: FakeGitHubClient},
        metadata: lease_metadata,
        profile: profile
      })

    {context, lease}
  end

  defp default_scopes(:installation),
    do: [
      "actions:read",
      "actions:write",
      "metadata:read",
      "issues:read",
      "issues:write",
      "pull_requests:read",
      "contents:write"
    ]

  defp default_scopes(_profile), do: ["repo"]

  defp owner_type(:installation), do: :installation
  defp owner_type(_profile), do: :user

  defp availability_for(availability, tool) do
    Enum.find(availability, &(&1.tool == tool)) || flunk("missing availability for #{tool}")
  end
end
