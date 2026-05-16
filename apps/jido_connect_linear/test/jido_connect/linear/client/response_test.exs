defmodule Jido.Connect.Linear.Client.ResponseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Client.Response

  describe "handle_issue_response/1" do
    test "normalizes a successful issue get response" do
      body = %{
        "data" => %{
          "issue" => %{
            "id" => "uuid-001",
            "identifier" => "LIN-123",
            "title" => "Test issue",
            "description" => "A test issue",
            "state" => %{"id" => "s-1", "name" => "In Progress", "type" => "started"},
            "priority" => 3,
            "priorityLabel" => "Medium",
            "team" => %{"id" => "team-1", "key" => "LIN", "name" => "Linear Team"},
            "assignee" => %{"id" => "user-1", "name" => "Test User"},
            "labels" => %{
              "nodes" => [%{"id" => "l-1", "name" => "bug", "color" => "#E5484D"}]
            },
            "createdAt" => "2026-05-15T10:00:00.000Z",
            "updatedAt" => "2026-05-15T12:00:00.000Z"
          }
        }
      }

      assert {:ok, issue} = Response.handle_issue_response({:ok, %{status: 200, body: body}})
      assert issue.identifier == "LIN-123"
      assert issue.title == "Test issue"
      assert issue.status.name == "In Progress"
      assert issue.priority.label == "Medium"
      assert issue.team.key == "LIN"
      assert issue.assignee.name == "Test User"
      assert length(issue.labels) == 1
      assert hd(issue.labels).name == "bug"
    end

    test "returns error for GraphQL errors" do
      body = %{
        "errors" => [%{"message" => "Issue not found"}]
      }

      assert {:error, _} = Response.handle_issue_response({:ok, %{status: 200, body: body}})
    end

    test "returns error for missing data" do
      body = %{"data" => %{}}

      assert {:error, _} = Response.handle_issue_response({:ok, %{status: 200, body: body}})
    end

    test "returns error for HTTP error" do
      assert {:error, _} =
               Response.handle_issue_response(
                 {:ok, %{status: 404, body: %{"errors" => [%{"message" => "Not found"}]}}}
               )
    end
  end

  describe "handle_issue_search_response/1" do
    test "normalizes a successful issue search response" do
      body = %{
        "data" => %{
          "issues" => %{
            "nodes" => [
              %{
                "id" => "uuid-001",
                "identifier" => "LIN-123",
                "title" => "Test issue",
                "state" => %{"id" => "s-1", "name" => "In Progress"},
                "team" => %{"id" => "team-1", "key" => "LIN"},
                "labels" => %{"nodes" => []},
                "createdAt" => "2026-05-15T10:00:00.000Z",
                "updatedAt" => "2026-05-15T12:00:00.000Z"
              }
            ],
            "pageInfo" => %{
              "hasNextPage" => false,
              "endCursor" => "cursor-1"
            },
            "totalCount" => 1
          }
        }
      }

      assert {:ok, result} =
               Response.handle_issue_search_response({:ok, %{status: 200, body: body}})

      assert length(result.issues) == 1
      assert hd(result.issues).identifier == "LIN-123"
      assert result.has_next_page == false
      assert result.end_cursor == "cursor-1"
      assert result.total_count == 1
    end

    test "returns error when issues data is missing" do
      body = %{"data" => %{}}

      assert {:error, _} =
               Response.handle_issue_search_response({:ok, %{status: 200, body: body}})
    end
  end

  describe "handle_issue_create_response/1" do
    test "normalizes a successful issue create response" do
      body = %{
        "data" => %{
          "issueCreate" => %{
            "success" => true,
            "issue" => %{
              "id" => "uuid-002",
              "identifier" => "LIN-124",
              "title" => "New issue"
            }
          }
        }
      }

      assert {:ok, issue} =
               Response.handle_issue_create_response({:ok, %{status: 200, body: body}})

      assert issue.identifier == "LIN-124"
      assert issue.title == "New issue"
    end

    test "returns error when issue create fails" do
      body = %{
        "data" => %{
          "issueCreate" => %{
            "success" => false
          }
        }
      }

      assert {:error, _} =
               Response.handle_issue_create_response({:ok, %{status: 200, body: body}})
    end
  end

  describe "handle_issue_update_response/1" do
    test "normalizes a successful issue update response" do
      body = %{
        "data" => %{
          "issueUpdate" => %{
            "success" => true
          }
        }
      }

      assert {:ok, result} =
               Response.handle_issue_update_response({:ok, %{status: 200, body: body}})

      assert result.updated == true
    end

    test "returns error when update fails" do
      body = %{
        "data" => %{
          "issueUpdate" => %{
            "success" => false
          }
        }
      }

      assert {:error, _} =
               Response.handle_issue_update_response({:ok, %{status: 200, body: body}})
    end
  end

  describe "handle_team_list_response/1" do
    test "normalizes a successful team list response" do
      body = %{
        "data" => %{
          "teams" => %{
            "nodes" => [
              %{
                "id" => "team-1",
                "key" => "LIN",
                "name" => "Linear Team",
                "icon" => "🚀",
                "color" => "#5B5DEF"
              },
              %{
                "id" => "team-2",
                "key" => "ENG",
                "name" => "Engineering",
                "icon" => "⚙️",
                "color" => "#F2C94C"
              }
            ],
            "pageInfo" => %{
              "hasNextPage" => false,
              "endCursor" => nil
            }
          }
        }
      }

      assert {:ok, result} =
               Response.handle_team_list_response({:ok, %{status: 200, body: body}})

      assert length(result.teams) == 2
      assert hd(result.teams).key == "LIN"
      assert hd(result.teams).name == "Linear Team"
      assert result.has_next_page == false
    end
  end

  describe "handle_comment_response/1" do
    test "normalizes a successful comment create response" do
      body = %{
        "data" => %{
          "commentCreate" => %{
            "success" => true,
            "comment" => %{
              "id" => "comment-1",
              "body" => "Test comment",
              "createdAt" => "2026-05-15T14:00:00.000Z"
            }
          }
        }
      }

      assert {:ok, comment} =
               Response.handle_comment_response({:ok, %{status: 200, body: body}})

      assert comment.id == "comment-1"
      assert comment.body == "Test comment"
      assert comment.created_at == "2026-05-15T14:00:00.000Z"
    end
  end
end
